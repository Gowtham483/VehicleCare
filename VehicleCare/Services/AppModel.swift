import Foundation
import Observation

/// Owns the database and services, and publishes changes to SwiftUI.
/// Views read `revision` (directly or via the helpers) so they refresh after any write.
@MainActor
@Observable
final class AppModel {
    let store: DataStore
    let reminders: ReminderService
    private(set) var settings: AppSettings
    private(set) var revision = 0

    /// Shown in an alert by the root view.
    var errorMessage: String?
    var notice: String?
    /// Set when the first-run tour finishes with "Add my first vehicle".
    var pendingAddVehicle = false

    init(store: DataStore, scheduler: NotificationScheduler) throws {
        self.store = store
        self.reminders = ReminderService(store: store, scheduler: scheduler)
        self.settings = try store.loadSettings()
    }

    static func live() throws -> AppModel {
        if ProcessInfo.processInfo.arguments.contains("-uitest-reset") { // UI tests start from a clean, throwaway database
            return try AppModel(store: DataStore.inMemory(), scheduler: SystemNotificationScheduler())
        }
        let dir = URL.applicationSupportDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let store = try DataStore(db: Database(path: dir.appendingPathComponent("vehicle-care.db").path))
        return try AppModel(store: store, scheduler: SystemNotificationScheduler())
    }

    func bump() { revision += 1 }

    /// Runs `work`, surfacing any error in the root alert.
    func attempt(_ work: @escaping () async throws -> Void) {
        Task {
            do { try await work() } catch { errorMessage = error.localizedDescription }
            bump()
        }
    }

    // MARK: Startup

    func boot() async {
        do {
            try store.purgeOldRecords(months: settings.retentionMonths)
            try await reminders.sync() // permission/platform issues must not block startup
        } catch {}
        bump()
    }

    // MARK: Settings

    func update(_ change: (inout AppSettings) -> Void) {
        var next = settings
        change(&next)
        let old = settings.asStored
        for (key, value) in next.asStored where old[key] != value {
            do { try store.saveSetting(key: key, value: value) } catch { errorMessage = error.localizedDescription }
        }
        settings = next
        bump()
    }

    func finishOnboarding(addVehicle: Bool) {
        pendingAddVehicle = addVehicle
        update { $0.onboardingDone = true }
    }

    // MARK: Vehicles

    func saveVehicle(id: Int?, _ input: VehicleInput) throws {
        if let id { try store.updateVehicle(id: id, input) } else { try store.createVehicle(input) }
        bump()
    }

    func deleteVehicle(id: Int) async throws {
        try await reminders.cancelVehicleNotifications(vehicleId: id)
        try store.deleteVehicle(id: id)
        bump()
    }

    // MARK: Services

    /// Saves the service and (re)schedules or clears its next-service reminder.
    /// Returns a message to show the user when something about the reminder needs their attention.
    func saveService(_ input: ServiceInput, id: Int?, vehicleName: String) async throws -> String? {
        let serviceId = try store.saveService(input, id: id)
        defer { bump() }
        guard let due = input.nextDueDate, let dueDate = DateUtil.parse(due) else {
            try await reminders.clearServiceReminder(vehicleId: input.vehicleId, serviceId: serviceId)
            return nil
        }
        guard let fireAt = Schedule.serviceFireAt(now: Date(), dueDate: dueDate, leadDays: settings.serviceLeadDays, hour: settings.notifyHour) else {
            try await reminders.clearServiceReminder(vehicleId: input.vehicleId, serviceId: serviceId)
            return L10n.Notice.servicePassed
        }
        let scheduled = try await reminders.setReminder(
            vehicleId: input.vehicleId, kind: .service, serviceId: serviceId, fireAt: fireAt,
            body: L10n.Reminder.serviceBody(vehicleName, input.title, DateUtil.pretty(due)))
        return scheduled ? nil : L10n.Notice.serviceNoNotifications
    }

    func deleteService(_ service: Service) async throws {
        try await reminders.clearServiceReminder(vehicleId: service.vehicleId, serviceId: service.id)
        try store.deleteService(id: service.id)
        bump()
    }

    // MARK: Quick logs

    /// Saves the log and, when `remindAfterDays` is set, replaces the reminder for that kind.
    func logQuick(_ input: QuickLogInput, remindAfterDays: Int?, vehicleName: String) async throws -> String? {
        try store.addQuickLog(input)
        defer { bump() }
        guard let days = remindAfterDays else { return nil }
        let scheduled = try await reminders.setReminder(
            vehicleId: input.vehicleId, kind: input.kind.reminderKind,
            fireAt: Schedule.fireAt(now: Date(), days: days, hour: settings.notifyHour),
            body: input.kind.reminderBody(vehicleName: vehicleName))
        return scheduled ? nil : L10n.Notice.quickNoNotifications
    }

    // MARK: Backup / reset

    func importBackup(_ backup: BackupFile, mode: ImportMode) async throws -> BackupSummary {
        if mode == .replace { await reminders.cancelAll() }
        let added = try Backup.importBackup(backup, into: store, mode: mode)
        settings = try store.loadSettings()
        try store.purgeOldRecords(months: settings.retentionMonths)
        try await reminders.sync()
        bump()
        return added
    }

    func resetAll() async throws {
        await reminders.cancelAll()
        try store.resetAll()
        settings = try store.loadSettings() // onboardingDone resets, so the tour shows again
        bump()
    }
}
