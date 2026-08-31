import BackgroundTasks
import Foundation

enum BackgroundRefreshService {
    static let identifier = "com.sidkrishnan.ServoGrid.refresh"
    static let limitation = "Best effort only: iOS decides when ServoGrid may refresh in the background. Open the app for an immediate check."

    @MainActor
    static func register(handler: @escaping @MainActor @Sendable () async -> Bool) {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            let work = Task { @MainActor in
                let success = await handler()
                refreshTask.setTaskCompleted(success: success)
            }
            refreshTask.expirationHandler = { work.cancel() }
        }
    }

    static func schedule(after interval: TimeInterval = 60 * 60) throws {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = Date().addingTimeInterval(interval)
        try BGTaskScheduler.shared.submit(request)
    }
}
