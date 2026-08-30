import CoreLocation
import XCTest
@testable import ServoGrid

final class DomainTests: XCTestCase {
    func testFuelGradeNormalizesProviderNamesWithoutInventingUnsupportedGrades() {
        XCTAssertEqual(FuelGrade(sourceName: "U91"), .unleaded91)
        XCTAssertEqual(FuelGrade(sourceName: "ULP"), .unleaded91)
        XCTAssertEqual(FuelGrade(sourceName: "E10"), .e10)
        XCTAssertEqual(FuelGrade(sourceName: "P95"), .unleaded95)
        XCTAssertEqual(FuelGrade(sourceName: "98 RON"), .unleaded98)
        XCTAssertEqual(FuelGrade(sourceName: "PDSL"), .premiumDiesel)
        XCTAssertEqual(FuelGrade(sourceName: "LAF"), .lowAromatic)
        XCTAssertNil(FuelGrade(sourceName: "hydrogen"))
    }

    func testObservationPreservesEveryClockIndependently() throws {
        let sourceEventAt = date("2026-08-30T01:00:00Z")
        let sourceDatasetAt = date("2026-08-30T01:05:00Z")
        let observedAt = date("2026-08-30T01:06:00Z")
        let checkedAt = date("2026-08-30T01:10:00Z")

        let observation = try FuelPriceObservation(
            id: "wa-1-u91-today",
            stationID: "wa-1",
            fuelGrade: .unleaded91,
            priceCentsPerLitre: 178.9,
            availability: .available,
            validity: .today,
            sourceEventAt: sourceEventAt,
            sourceDatasetAt: sourceDatasetAt,
            observedAt: observedAt,
            checkedAt: checkedAt,
            restrictions: "Standard retail price"
        )

        XCTAssertEqual(observation.sourceEventAt, sourceEventAt)
        XCTAssertEqual(observation.sourceDatasetAt, sourceDatasetAt)
        XCTAssertEqual(observation.observedAt, observedAt)
        XCTAssertEqual(observation.checkedAt, checkedAt)
    }

    func testObservationRejectsNonPositiveAndNonFinitePrices() {
        XCTAssertThrowsError(try makeObservation(price: 0))
        XCTAssertThrowsError(try makeObservation(price: -1))
        XCTAssertThrowsError(try makeObservation(price: .infinity))
    }

    func testStationRejectsImpossibleCoordinates() {
        XCTAssertThrowsError(try makeStation(latitude: -91, longitude: 151))
        XCTAssertThrowsError(try makeStation(latitude: -37.8, longitude: 181))
    }

    func testDemoSnapshotCannotBeMistakenForLiveCoverage() throws {
        let source = SourceDescriptor(
            id: "fixture-national",
            name: "ServoGrid evaluation fixtures",
            jurisdiction: .national,
            coverage: .demo,
            sourceURL: URL(string: "https://example.invalid/servogrid-fixture")!,
            attribution: "Synthetic demo evidence",
            licenceName: "Project fixture"
        )
        let snapshot = FuelSnapshot(
            schemaVersion: 1,
            source: source,
            stations: [try makeStation()],
            checkedAt: date("2026-08-30T01:10:00Z")
        )

        XCTAssertTrue(snapshot.isDemo)
        XCTAssertEqual(snapshot.trustLabel, "Demo data")
    }

    private func makeObservation(price: Double) throws -> FuelPriceObservation {
        try FuelPriceObservation(
            id: "wa-1-u91-today",
            stationID: "wa-1",
            fuelGrade: .unleaded91,
            priceCentsPerLitre: price,
            availability: .available,
            validity: .today,
            sourceEventAt: date("2026-08-30T01:00:00Z"),
            sourceDatasetAt: nil,
            observedAt: date("2026-08-30T01:06:00Z"),
            checkedAt: date("2026-08-30T01:10:00Z"),
            restrictions: nil
        )
    }

    private func makeStation(
        latitude: CLLocationDegrees = -37.8136,
        longitude: CLLocationDegrees = 144.9631
    ) throws -> FuelStation {
        try FuelStation(
            id: "fixture-melbourne-1",
            sourceStationID: "melbourne-1",
            name: "Grid Test Servo",
            brand: "Independent",
            address: "1 Test Street",
            suburb: "Melbourne",
            state: "VIC",
            postcode: "3000",
            latitude: latitude,
            longitude: longitude,
            observations: [try makeObservation(price: 178.9)]
        )
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
