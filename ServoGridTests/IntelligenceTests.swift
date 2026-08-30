import XCTest
@testable import ServoGrid

final class IntelligenceTests: XCTestCase {
    private let policy = FreshnessPolicy(freshFor: 60 * 60, staleAfter: 6 * 60 * 60)
    private let now = ISO8601DateFormatter().date(from: "2026-08-30T12:00:00Z")!

    func testFreshnessUsesSourceOwnedTimeAndNeverCheckedAt() throws {
        XCTAssertEqual(
            FreshnessEvaluator.evaluate(try observation(price: 180, eventOffset: -30 * 60), at: now, policy: policy),
            .fresh
        )
        XCTAssertEqual(
            FreshnessEvaluator.evaluate(try observation(price: 180, eventOffset: -3 * 60 * 60), at: now, policy: policy),
            .ageing
        )
        XCTAssertEqual(
            FreshnessEvaluator.evaluate(try observation(price: 180, eventOffset: -8 * 60 * 60), at: now, policy: policy),
            .stale
        )

        let missingSourceTime = try observation(price: 180, eventOffset: nil, datasetOffset: nil)
        XCTAssertEqual(missingSourceTime.checkedAt, now)
        XCTAssertEqual(FreshnessEvaluator.evaluate(missingSourceTime, at: now, policy: policy), .unknown)
    }

    func testMovementRequiresComparableStationGradeAndDay() throws {
        let previous = try observation(price: 181.9, eventOffset: -600)
        let lower = try observation(price: 178.4, eventOffset: -60)

        XCTAssertEqual(PriceMovementCalculator.compare(current: lower, previous: previous), .down(delta: -3.5))
        XCTAssertEqual(
            PriceMovementCalculator.compare(
                current: try observation(price: 181.92, eventOffset: -60),
                previous: previous
            ),
            .steady
        )
        XCTAssertEqual(
            PriceMovementCalculator.compare(
                current: try observation(price: 185, grade: .diesel, eventOffset: -60),
                previous: previous
            ),
            .unavailable
        )
    }

    func testRelativeBandUsesLocalCohortAndReportsInsufficientEvidence() {
        let cohort = [160.0, 170.0, 180.0, 190.0, 200.0]
        XCTAssertEqual(RelativePriceClassifier.classify(price: 160, localPrices: cohort), .low)
        XCTAssertEqual(RelativePriceClassifier.classify(price: 180, localPrices: cohort), .typical)
        XCTAssertEqual(RelativePriceClassifier.classify(price: 200, localPrices: cohort), .high)
        XCTAssertEqual(RelativePriceClassifier.classify(price: 180, localPrices: [170, 180]), .insufficientData)
    }

    func testMonitorDetectsSchemaEmptyMissingTimeFutureTimeAndImpossiblePrice() throws {
        let source = liveSource()
        let future = try station(id: "future", price: 180, eventOffset: 600)
        let impossible = try station(id: "impossible", price: 650, eventOffset: -60)
        let missing = try station(id: "missing", price: 180, eventOffset: nil)
        let snapshot = FuelSnapshot(
            schemaVersion: 2,
            source: source,
            stations: [future, impossible, missing],
            checkedAt: now
        )

        let codes = Set(GridMonitor.evaluate(snapshot: snapshot, now: now, policy: policy).map(\.code))
        XCTAssertTrue(codes.contains(.schemaDrift))
        XCTAssertTrue(codes.contains(.futureTimestamp))
        XCTAssertTrue(codes.contains(.impossiblePrice))
        XCTAssertTrue(codes.contains(.missingTimestamp))

        let empty = FuelSnapshot(schemaVersion: 1, source: source, stations: [], checkedAt: now)
        XCTAssertTrue(GridMonitor.evaluate(snapshot: empty, now: now, policy: policy).contains { $0.code == .emptyFeed })
    }

    func testMonitorDetectsNearbyDuplicateStations() throws {
        let first = try station(id: "a", sourceID: "one", latitude: -37.81360, longitude: 144.96310)
        let second = try station(id: "b", sourceID: "two", latitude: -37.81361, longitude: 144.96311)
        let snapshot = FuelSnapshot(schemaVersion: 1, source: liveSource(), stations: [first, second], checkedAt: now)

        let issues = GridMonitor.evaluate(snapshot: snapshot, now: now, policy: policy)
        XCTAssertEqual(issues.filter { $0.code == .duplicateStation }.count, 1)
    }

    func testBriefRequiresThreeComparableEvidencePoints() throws {
        let previous = try snapshot(prices: [170, 172, 174], eventOffset: -3_600)
        let current = try snapshot(prices: [175, 178, 179], eventOffset: -60)

        let brief = GridBriefEngine.generate(
            region: "western Melbourne",
            fuelGrade: .unleaded91,
            current: current,
            previous: previous,
            now: now
        )

        XCTAssertNotNil(brief)
        XCTAssertTrue(brief?.text.contains("U91 rose") == true)
        XCTAssertTrue(brief?.text.contains("western Melbourne") == true)
        XCTAssertEqual(brief?.sampleSize, 3)
        XCTAssertEqual(brief?.evidenceObservationIDs.count, 6)

        let tooSmall = try snapshot(prices: [175, 178], eventOffset: -60)
        XCTAssertNil(GridBriefEngine.generate(
            region: "western Melbourne",
            fuelGrade: .unleaded91,
            current: tooSmall,
            previous: previous,
            now: now
        ))
    }

    func testAlertEngineEmitsThresholdDropOnce() throws {
        let previous = try snapshot(prices: [185], eventOffset: -600)
        let current = try snapshot(prices: [178], eventOffset: -60)
        let preference = AlertPreference(
            id: "u91-drop",
            areaName: "Melbourne",
            stationID: nil,
            fuelGrade: .unleaded91,
            dropThreshold: 5,
            spikeThreshold: 10,
            tomorrowPublished: true,
            sourceOutage: true
        )

        let events = AlertEngine.evaluate(
            previous: previous,
            current: current,
            preferences: [preference],
            deliveredEventIDs: []
        )
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .priceDrop)
        XCTAssertTrue(events.first?.message.contains("7.0c/L") == true)

        XCTAssertTrue(AlertEngine.evaluate(
            previous: previous,
            current: current,
            preferences: [preference],
            deliveredEventIDs: Set(events.map(\.id))
        ).isEmpty)
    }

    private func snapshot(prices: [Double], eventOffset: TimeInterval?) throws -> FuelSnapshot {
        let stations = try prices.enumerated().map { index, price in
            try station(id: "station-\(index)", sourceID: "station-\(index)", price: price, eventOffset: eventOffset)
        }
        return FuelSnapshot(schemaVersion: 1, source: liveSource(), stations: stations, checkedAt: now)
    }

    private func station(
        id: String,
        sourceID: String? = nil,
        price: Double = 180,
        eventOffset: TimeInterval? = -60,
        latitude: Double = -37.8136,
        longitude: Double = 144.9631
    ) throws -> FuelStation {
        try FuelStation(
            id: id,
            sourceStationID: sourceID ?? id,
            name: "Grid Servo \(id)",
            brand: "Independent",
            address: "\(id) Test Street",
            suburb: "Melbourne",
            state: "VIC",
            postcode: "3000",
            latitude: latitude,
            longitude: longitude,
            observations: [try observation(id: id, price: price, eventOffset: eventOffset)]
        )
    }

    private func observation(
        id: String = "station-0",
        price: Double,
        grade: FuelGrade = .unleaded91,
        eventOffset: TimeInterval?,
        datasetOffset: TimeInterval? = nil
    ) throws -> FuelPriceObservation {
        try FuelPriceObservation(
            id: "\(id)-\(grade.rawValue)-today-\(price)",
            stationID: id,
            fuelGrade: grade,
            priceCentsPerLitre: price,
            availability: .available,
            validity: .today,
            sourceEventAt: eventOffset.map { now.addingTimeInterval($0) },
            sourceDatasetAt: datasetOffset.map { now.addingTimeInterval($0) },
            observedAt: now.addingTimeInterval(-30),
            checkedAt: now,
            restrictions: nil
        )
    }

    private func liveSource() -> SourceDescriptor {
        SourceDescriptor(
            id: "test-live",
            name: "Test Live Source",
            jurisdiction: .victoria,
            coverage: .live,
            sourceURL: URL(string: "https://example.test/live")!,
            attribution: "Test source",
            licenceName: "Test licence"
        )
    }
}

