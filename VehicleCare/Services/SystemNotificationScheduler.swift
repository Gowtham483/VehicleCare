import Foundation
import UserNotifications

/// `NotificationScheduler` backed by the system notification centre (local notifications only).
final class SystemNotificationScheduler: NSObject, NotificationScheduler, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self // needed so reminders also show while the app is open
    }

    func permission() async -> NotificationPermission {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: return .granted
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .denied
        }
    }

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func schedule(title: String, body: String, at date: Date) async throws -> String {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)
        let id = UUID().uuidString
        try await center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        return id
    }

    func cancel(id: String) async { center.removePendingNotificationRequests(withIdentifiers: [id]) }
    func cancelAll() async { center.removeAllPendingNotificationRequests() }

    func pendingIdentifiers() async -> Set<String> {
        Set(await center.pendingNotificationRequests().map(\.identifier))
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
