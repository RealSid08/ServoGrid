import Foundation
import UserNotifications

protocol NotificationScheduling: Sendable {
    func requestAuthorization() async -> Bool
    func schedule(_ events: [AlertEvent]) async throws
}

struct UserNotificationService: NotificationScheduling {
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    func schedule(_ events: [AlertEvent]) async throws {
        for event in events {
            let content = UNMutableNotificationContent()
            content.title = event.title
            content.body = event.message
            content.sound = .default
            content.userInfo = ["servogridEventID": event.id]
            let request = UNNotificationRequest(identifier: event.id, content: content, trigger: nil)
            try await UNUserNotificationCenter.current().add(request)
        }
    }
}

