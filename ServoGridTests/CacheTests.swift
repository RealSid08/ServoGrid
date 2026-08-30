import Foundation
import XCTest
@testable import ServoGrid

final class CacheTests: XCTestCase {
    func testCacheRoundTripPreservesSourceTimesAndHistory() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ServoGridCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = SnapshotCache(fileURL: directory.appendingPathComponent("snapshots.json"))
        let snapshot = try makeSnapshot()
        try await cache.save(CacheEnvelope(version: 1, snapshots: [snapshot]))

        let restored = try await cache.load()
        XCTAssertEqual(restored?.version, 1)
        XCTAssertEqual(restored?.snapshots, [snapshot])
        XCTAssertEqual(
            restored?.snapshots.first?.stations.first?.observations.first?.sourceEventAt,
            snapshot.stations.first?.observations.first?.sourceEventAt
        )
    }

    func testCacheRejectsUnsupportedEnvelopeVersion() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ServoGridCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("snapshots.json")
        try Data("{\"version\":99,\"snapshots\":[]}".utf8).write(to: fileURL)

        let cache = SnapshotCache(fileURL: fileURL)
        do {
            _ = try await cache.load()
            XCTFail("Unknown cache schemas must fail closed")
        } catch let error as CacheFailure {
            XCTAssertEqual(error, .unsupportedVersion(99))
        }
    }

    private func makeSnapshot() throws -> FuelSnapshot {
        let sourceTime = ISO8601DateFormatter().date(from: "2026-08-30T01:00:00Z")!
        let checkedAt = ISO8601DateFormatter().date(from: "2026-08-30T01:05:00Z")!
        let observation = try FuelPriceObservation(
            id: "cache-u91",
            stationID: "cache-station",
            fuelGrade: .unleaded91,
            priceCentsPerLitre: 177.7,
            availability: .available,
            validity: .today,
            sourceEventAt: sourceTime,
            sourceDatasetAt: sourceTime,
            observedAt: checkedAt,
            checkedAt: checkedAt,
            restrictions: nil
        )
        let station = try FuelStation(
            id: "cache-station",
            sourceStationID: "cache-station",
            name: "Cache Servo",
            brand: nil,
            address: "1 Cache Road",
            suburb: "Perth",
            state: "WA",
            postcode: "6000",
            latitude: -31.95,
            longitude: 115.86,
            observations: [observation]
        )
        return FuelSnapshot(
            schemaVersion: 1,
            source: SourceDescriptor(
                id: "cache-source",
                name: "Cache Source",
                jurisdiction: .westernAustralia,
                coverage: .live,
                sourceURL: URL(string: "https://example.test/cache")!,
                attribution: "Cache source",
                licenceName: "Test"
            ),
            stations: [station],
            checkedAt: checkedAt
        )
    }
}
