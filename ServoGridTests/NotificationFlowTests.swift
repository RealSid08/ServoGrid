import Foundation
import XCTest
@testable import ServoGrid

@MainActor
final class NotificationFlowTests: XCTestCase {
    func testPermissionIsRequestedOnlyWhenUserEnablesAnAlert() async throws {
        let notifications = NotificationSpy(authorizationGranted: true)
        let snapshot = try makeSnapshot(price: 180)
        let store = AppStore(
            sourceMode: .demo,
            adapter: StoreStubAdapter(snapshot: snapshot),
            cache: SnapshotCache(fileURL: temporaryFileURL()),
            notifications: notifications,
            now: { snapshot.checkedAt }
        )

        await store.load()
        let requestsBeforeEnabling = await notifications.authorizationRequestCount
        XCTAssertEqual(requestsBeforeEnabling, 0)

        let preference = AlertPreference(
            id: "melbourne-u91",
            areaName: "Melbourne",
            stationID: nil,
            fuelGrade: .unleaded91,
            dropThreshold: 5,
            spikeThreshold: 10,
            tomorrowPublished: true,
            sourceOutage: true
        )
        let enabled = await store.enableAlert(preference)

        XCTAssertTrue(enabled)
        XCTAssertEqual(store.alertPreferences, [preference])
        let requestsAfterEnabling = await notifications.authorizationRequestCount
        XCTAssertEqual(requestsAfterEnabling, 1)
    }

    func testRefreshSchedulesDeterministicAlertEvents() async throws {
        let notifications = NotificationSpy(authorizationGranted: true)
        let previous = try makeSnapshot(price: 185)
        let current = try makeSnapshot(price: 177)
        let adapter = SequenceStoreAdapter(source: current.source, snapshots: [previous, current])
        let store = AppStore(
            sourceMode: .demo,
            adapter: adapter,
            cache: SnapshotCache(fileURL: temporaryFileURL()),
            notifications: notifications,
            now: { current.checkedAt }
        )
        _ = await store.enableAlert(AlertPreference(
            id: "drop", areaName: "Melbourne", stationID: nil, fuelGrade: .unleaded91,
            dropThreshold: 5, spikeThreshold: 10, tomorrowPublished: false, sourceOutage: false
        ))

        await store.load()
        await store.refresh()

        let events = await notifications.scheduledEvents
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.kind, .priceDrop)
    }

    private func makeSnapshot(price: Double) throws -> FuelSnapshot {
        let checkedAt = ISO8601DateFormatter().date(from: "2026-08-30T08:00:00Z")!
        let observation = try FuelPriceObservation(
            id: "notification-u91-\(price)", stationID: "notification-station", fuelGrade: .unleaded91,
            priceCentsPerLitre: price, availability: .available, validity: .today,
            sourceEventAt: checkedAt.addingTimeInterval(-60), sourceDatasetAt: nil,
            observedAt: checkedAt, checkedAt: checkedAt, restrictions: nil
        )
        let station = try FuelStation(
            id: "notification-station", sourceStationID: "notification-station", name: "Alert Servo",
            brand: nil, address: "1 Alert Road", suburb: "Melbourne", state: "VIC", postcode: "3000",
            latitude: -37.81, longitude: 144.96, observations: [observation]
        )
        return FuelSnapshot(
            schemaVersion: 1,
            source: SourceDescriptor(
                id: "fixture-national", name: "Demo", jurisdiction: .national, coverage: .demo,
                sourceURL: URL(string: "https://example.invalid/demo")!, attribution: "Demo", licenceName: "Fixture"
            ),
            stations: [station], checkedAt: checkedAt
        )
    }

    private func temporaryFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ServoGridNotificationTests-\(UUID().uuidString).json")
    }
}

actor NotificationSpy: NotificationScheduling {
    private(set) var authorizationRequestCount = 0
    private(set) var scheduledEvents: [AlertEvent] = []
    let authorizationGranted: Bool

    init(authorizationGranted: Bool = false) {
        self.authorizationGranted = authorizationGranted
    }

    func requestAuthorization() async -> Bool {
        authorizationRequestCount += 1
        return authorizationGranted
    }

    func schedule(_ events: [AlertEvent]) async throws {
        scheduledEvents.append(contentsOf: events)
    }
}
