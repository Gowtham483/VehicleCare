import Foundation

enum NotificationPermission { case granted, denied, notDetermined }

/// The slice of the system notification centre this app needs. The app supplies a
/// `UNUserNotificationCenter` implementation; tests supply a fake.
protocol NotificationScheduler {
    func permission() async -> NotificationPermission
    func requestPermission() async -> Bool
    func schedule(title: String, body: String, at date: Date) async throws -> String
    func cancel(id: String) async
    func cancelAll() async
    func pendingIdentifiers() async -> Set<String>
}

extension QuickKind {
    /// The kind of reminder a quick log of this kind schedules.
    var reminderKind: ReminderKind {
        switch self {
        case .tyreAir: return .tyreAir
        case .petrol: return .petrol
        case .lube: return .lube
        }
    }

    func reminderBody(vehicleName: String) -> String {
        switch self {
        case .tyreAir: return L10n.Reminder.tyreBody(vehicleName)
        case .petrol: return L10n.Reminder.petrolBody(vehicleName)
        case .lube: return L10n.Reminder.lubeBody(vehicleName)
        }
    }
}

/// Keeps the `reminder` table and the OS-scheduled notifications in step.
struct ReminderService {
    let store: DataStore
    let scheduler: NotificationScheduler

    static func title(for kind: ReminderKind) -> String {
        switch kind {
        case .tyreAir: return L10n.Reminder.tyreTitle
        case .petrol: return L10n.Reminder.petrolTitle
        case .service: return L10n.Reminder.serviceTitle
        case .lube: return L10n.Reminder.lubeTitle
        }
    }

    /// Asks for permission the first time a reminder is set. Returns false if the user declined.
    func ensurePermission() async -> Bool {
        switch await scheduler.permission() {
        case .granted: return true
        case .denied: return false
        case .notDetermined: return await scheduler.requestPermission()
        }
    }

    /// Replaces any reminder of the same kind (per vehicle / service) with a new one.
    /// Returns false when permission is denied. The row is still saved and `sync` schedules it later.
    func setReminder(vehicleId: Int, kind: ReminderKind, serviceId: Int? = nil, fireAt: Date, body: String) async throws -> Bool {
        try await clear(store.findReminders(vehicleId: vehicleId, kind: kind, serviceId: serviceId))
        let allowed = await ensurePermission()
        let notificationId = allowed ? try await scheduler.schedule(title: Self.title(for: kind), body: body, at: fireAt) : nil
        try store.insertReminder(vehicleId: vehicleId, serviceId: serviceId, kind: kind, notificationId: notificationId,
                                 fireAt: DateUtil.iso(fireAt), label: body)
        return allowed
    }

    func clear(_ reminders: [Reminder]) async throws {
        for r in reminders {
            if let id = r.notificationId { await scheduler.cancel(id: id) }
            try store.deleteReminder(id: r.id)
        }
    }

    /// Call before deleting a vehicle: cancels its pending notifications.
    func cancelVehicleNotifications(vehicleId: Int) async throws {
        for r in try store.reminders(vehicleId: vehicleId) {
            if let id = r.notificationId { await scheduler.cancel(id: id) }
        }
    }

    /// Call before deleting a service: cancels and removes its service reminder.
    func clearServiceReminder(vehicleId: Int, serviceId: Int) async throws {
        try await clear(store.findReminders(vehicleId: vehicleId, kind: .service, serviceId: serviceId))
    }

    func cancelAll() async { await scheduler.cancelAll() }

    /// Expired reminders are deactivated; active future reminders with no live notification (after an
    /// import, reinstall, or earlier denied permission) are scheduled again. Runs on launch and after imports.
    func sync(now: Date = Date()) async throws {
        let active = try store.activeReminders()
        guard !active.isEmpty else { return }
        let allowed = await scheduler.permission() == .granted
        let live = await scheduler.pendingIdentifiers()

        for r in active {
            guard let fireDate = DateUtil.parseISO(r.fireAt), fireDate > now else {
                try store.deactivateReminder(id: r.id)
                continue
            }
            if !allowed || (r.notificationId.map(live.contains) ?? false) { continue }
            let id = try await scheduler.schedule(title: Self.title(for: r.kind), body: r.label, at: fireDate)
            try store.setNotificationId(reminderId: r.id, id)
        }
    }

    /// Fires a notification a few seconds from now so users can confirm reminders work on their device.
    func sendTest() async -> Bool {
        guard await ensurePermission() else { return false }
        return (try? await scheduler.schedule(title: AppInfo.name, body: L10n.Reminder.testBody, at: Date().addingTimeInterval(5))) != nil
    }
}
