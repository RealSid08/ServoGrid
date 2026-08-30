import Foundation

@MainActor
struct AppEnvironment {
    let store: AppStore
    let location: LocationService

    static func production(bundle: Bundle = .main) -> AppEnvironment {
        let cache = SnapshotCache()
        let notifications = UserNotificationService()
        let store = AppStore(
            sourceMode: .demo,
            adapter: FixtureAdapter(bundle: bundle),
            cache: cache,
            notifications: notifications,
            seedSnapshot: try? FixtureAdapter.loadSnapshot(
                resourceName: "demo-national-previous",
                bundle: bundle
            )
        )
        return AppEnvironment(store: store, location: LocationService())
    }

    static func adapter(for mode: SourceMode, bundle: Bundle = .main) -> any FuelSourceAdapter {
        switch mode {
        case .demo: FixtureAdapter(bundle: bundle)
        case .fuelWatch: FuelWatchAdapter()
        }
    }
}
