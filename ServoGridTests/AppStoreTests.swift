import Foundation
import XCTest
@testable import ServoGrid

@MainActor
final class AppStoreTests: XCTestCase {
    func testSuccessfulDemoLoadPublishesExplicitTrustAndMonitorState() async throws {
        let snapshot = try makeSnapshot(price: 179.9, coverage: .demo)
        let adapter = StoreStubAdapter(snapshot: snapshot)
        let cache = SnapshotCache(fileURL: temporaryFileURL())
        let notifications = NotificationSpy()
        let store = AppStore(
            sourceMode: .demo,
            adapter: adapter,
            cache: cache,
            notifications: notifications,
            now: { snapshot.checkedAt }
        )

        await store.load()

        XCTAssertEqual(store.loadState, .loaded)
        XCTAssertEqual(store.stations.map(\.id), ["station-0"])
        XCTAssertTrue(store.isDemo)
        XCTAssertEqual(store.trustLabel, "Demo data")
        XCTAssertEqual(store.sourceHealth?.recordCount, 1)
        let authorizationRequests = await notifications.authorizationRequestCount
        XCTAssertEqual(authorizationRequests, 0)
    }

    func testFailedRefreshUsesMatchingCacheWithoutSwitchingToFixtures() async throws {
        let cached = try makeSnapshot(price: 177.7, coverage: .live)
        let fileURL = temporaryFileURL()
        let cache = SnapshotCache(fileURL: fileURL)
        try await cache.save(CacheEnvelope(version: 1, snapshots: [cached]))
        let adapter = StoreStubAdapter(
            source: cached.source,
            result: .failure(SourceFailure.httpStatus(503))
        )
        let store = AppStore(
            sourceMode: .fuelWatch,
            adapter: adapter,
            cache: cache,
            notifications: NotificationSpy(),
            now: { cached.checkedAt }
        )

        await store.load()

        XCTAssertEqual(store.stations.first?.observations.first?.priceCentsPerLitre, 177.7)
        guard case .offlineCached = store.loadState else {
            return XCTFail("A matching cache should remain visible with an offline label")
        }
        XCTAssertFalse(store.isDemo)
        XCTAssertEqual(store.activeSnapshot?.source.id, cached.source.id)
    }

    func testFailedRefreshWithNoCacheFailsClosedAndShowsNoStations() async throws {
        let source = makeSource(coverage: .live)
        let store = AppStore(
            sourceMode: .fuelWatch,
            adapter: StoreStubAdapter(source: source, result: .failure(SourceFailure.httpStatus(503))),
            cache: SnapshotCache(fileURL: temporaryFileURL()),
            notifications: NotificationSpy(),
            now: Date.init
        )

        await store.load()

        XCTAssertTrue(store.stations.isEmpty)
        guard case .failed = store.loadState else {
            return XCTFail("A source failure must not silently load national demo fixtures")
        }
    }

    func testRefreshKeepsComparablePreviousSnapshotForMovement() async throws {
        let previous = try makeSnapshot(price: 185, coverage: .live)
        let current = try makeSnapshot(price: 178, coverage: .live, checkedAt: previous.checkedAt.addingTimeInterval(600))
        let adapter = SequenceStoreAdapter(source: current.source, snapshots: [previous, current])
        let store = AppStore(
            sourceMode: .fuelWatch,
            adapter: adapter,
            cache: SnapshotCache(fileURL: temporaryFileURL()),
            notifications: NotificationSpy(),
            now: { current.checkedAt }
        )

        await store.load()
        await store.refresh()

        XCTAssertEqual(store.movement(for: "station-0"), .down(delta: -7))
    }

    private func makeSnapshot(
        price: Double,
        coverage: CoverageMode,
        checkedAt: Date = ISO8601DateFormatter().date(from: "2026-08-30T08:00:00Z")!
    ) throws -> FuelSnapshot {
        let source = makeSource(coverage: coverage)
        let observation = try FuelPriceObservation(
            id: "station-0-u91-\(price)",
            stationID: "station-0",
            fuelGrade: .unleaded91,
            priceCentsPerLitre: price,
            availability: .available,
            validity: .today,
            sourceEventAt: checkedAt.addingTimeInterval(-60),
            sourceDatasetAt: checkedAt.addingTimeInterval(-30),
            observedAt: checkedAt,
            checkedAt: checkedAt,
            restrictions: nil
        )
        let station = try FuelStation(
            id: "station-0",
            sourceStationID: "station-0",
            name: "Store Test Servo",
            brand: nil,
            address: "1 Test Road",
            suburb: "Perth",
            state: "WA",
            postcode: "6000",
            latitude: -31.95,
            longitude: 115.86,
            observations: [observation]
        )
        return FuelSnapshot(schemaVersion: 1, source: source, stations: [station], checkedAt: checkedAt)
    }

    private func makeSource(coverage: CoverageMode) -> SourceDescriptor {
        SourceDescriptor(
            id: coverage == .demo ? "fixture-national" : "wa-fuelwatch",
            name: coverage == .demo ? "Demo" : "FuelWatch",
            jurisdiction: coverage == .demo ? .national : .westernAustralia,
            coverage: coverage,
            sourceURL: URL(string: "https://example.test/source")!,
            attribution: "Test source",
            licenceName: "Test"
        )
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ServoGridStoreTests-\(UUID().uuidString).json")
    }
}

struct StoreStubAdapter: FuelSourceAdapter {
    let source: SourceDescriptor
    let capabilities = SourceCapabilities(
        supportedGrades: [.unleaded91], supportsToday: true, supportsTomorrow: false,
        supportsHistory: false, requiresCredentials: false
    )
    let result: Result<FuelSnapshot, Error>

    init(snapshot: FuelSnapshot) {
        source = snapshot.source
        result = .success(snapshot)
    }

    init(source: SourceDescriptor, result: Result<FuelSnapshot, Error>) {
        self.source = source
        self.result = result
    }

    func fetch(grade: FuelGrade, day: PriceValidity) async throws -> FuelSnapshot {
        try result.get()
    }
}

actor SequenceStoreAdapter: FuelSourceAdapter {
    nonisolated let source: SourceDescriptor
    nonisolated let capabilities = SourceCapabilities(
        supportedGrades: [.unleaded91], supportsToday: true, supportsTomorrow: false,
        supportsHistory: true, requiresCredentials: false
    )
    private var snapshots: [FuelSnapshot]

    init(source: SourceDescriptor, snapshots: [FuelSnapshot]) {
        self.source = source
        self.snapshots = snapshots
    }

    func fetch(grade: FuelGrade, day: PriceValidity) async throws -> FuelSnapshot {
        guard !snapshots.isEmpty else { throw SourceFailure.invalidResponse("No more test snapshots") }
        return snapshots.removeFirst()
    }
}
