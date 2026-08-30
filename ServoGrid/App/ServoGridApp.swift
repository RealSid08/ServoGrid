import SwiftUI
import UIKit

@MainActor
final class AppSession {
    let environment: AppEnvironment
    private var didLoad = false
    private var lastActiveRefresh: Date?
    private static var didRegisterBackground = false

    init(environment: AppEnvironment = .production()) {
        self.environment = environment
        registerBackgroundRefresh()
    }

    func startIfNeeded() async {
        guard !didLoad else { return }
        didLoad = true
        await environment.store.load()
        lastActiveRefresh = Date()
        scheduleBackgroundRefresh()
    }

    func handleScenePhase(_ phase: ScenePhase) async {
        guard phase == .active else { return }
        await startIfNeeded()
        let store = environment.store
        switch store.loadState {
        case .loading, .idle:
            return
        case .failed, .offlineCached:
            await store.refresh()
            lastActiveRefresh = Date()
        case .loaded:
            guard let lastActiveRefresh else { return }
            guard Date().timeIntervalSince(lastActiveRefresh) >= 15 * 60 else { return }
            await store.refresh()
            self.lastActiveRefresh = Date()
        }
    }

    private func registerBackgroundRefresh() {
        guard !Self.didRegisterBackground else { return }
        Self.didRegisterBackground = true
        let store = environment.store
        BackgroundRefreshService.register {
            await store.refresh()
            try? BackgroundRefreshService.schedule()
            if case .failed = store.loadState { return false }
            return true
        }
        scheduleBackgroundRefresh()
    }

    private func scheduleBackgroundRefresh() {
        try? BackgroundRefreshService.schedule()
    }
}

@main
struct ServoGridApp: App {
    @State private var session = AppSession()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(session.environment.store)
                .environment(session.environment.location)
                .task {
                    await session.startIfNeeded()
                }
                .onChange(of: scenePhase) { _, phase in
                    Task { await session.handleScenePhase(phase) }
                }
        }
    }
}
