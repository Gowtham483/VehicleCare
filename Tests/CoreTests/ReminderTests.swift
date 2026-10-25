import XCTest
@testable import Core

final class ReminderTests: CoreTestCase {
    private func setup() throws -> (DataStore, FakeScheduler, ReminderService, Int) {
        let store = try makeStore()
        let scheduler = FakeScheduler()
        let vehicle = try store.createVehicle(VehicleInput(type: .bike, name: "B"))
        return (store, scheduler, ReminderService(store: store, scheduler: scheduler), vehicle)
    }
    private func future(_ days: Double) -> Date { Date().addingTimeInterval(days * 86_400) }

    func testReplacesEarlierReminderOfSameKind() async throws {
        let (store, scheduler, service, v) = try setup()
        _ = try await service.setReminder(vehicleId: v, kind: .tyreAir, fireAt: future(14), body: "first")
        _ = try await service.setReminder(vehicleId: v, kind: .tyreAir, fireAt: future(7), body: "second")

        XCTAssertEqual(scheduler.cancelled, ["n1"])
        let rows = try store.allReminders()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].label, "second")
        XCTAssertEqual(rows[0].notificationId, "n2")
    }

    func testTyreAndPetrolAreIndependent() async throws {
        let (store, _, service, v) = try setup()
        _ = try await service.setReminder(vehicleId: v, kind: .tyreAir, fireAt: future(14), body: "a")
        _ = try await service.setReminder(vehicleId: v, kind: .petrol, fireAt: future(7), body: "b")
        XCTAssertEqual(try store.allReminders().count, 2)
    }

    func testDeniedPermissionSavesRowButDoesNotSchedule() async throws {
        let (store, scheduler, service, v) = try setup()
        scheduler.state = .denied
        let scheduled = try await service.setReminder(vehicleId: v, kind: .petrol, fireAt: future(3), body: "x")
        XCTAssertFalse(scheduled)
        XCTAssertTrue(scheduler.scheduled.isEmpty)
        XCTAssertNil(try store.allReminders()[0].notificationId)
    }

    func testAsksForPermissionOnFirstUse() async throws {
        let (_, scheduler, service, v) = try setup()
        scheduler.state = .notDetermined
        let scheduled = try await service.setReminder(vehicleId: v, kind: .petrol, fireAt: future(3), body: "x")
        XCTAssertTrue(scheduled)
        XCTAssertEqual(scheduler.scheduled.count, 1)
    }

    func testClearCancelsAndRemoves() async throws {
        let (store, scheduler, service, v) = try setup()
        _ = try await service.setReminder(vehicleId: v, kind: .petrol, fireAt: future(3), body: "x")
        try await service.clear(try store.allReminders())
        XCTAssertEqual(scheduler.cancelled, ["n1"])
        XCTAssertTrue(try store.allReminders().isEmpty)
    }

    func testSyncDeactivatesExpiredAndReschedulesMissing() async throws {
        let (store, scheduler, service, v) = try setup()
        try store.insertReminder(vehicleId: v, serviceId: nil, kind: .tyreAir, notificationId: nil, fireAt: DateUtil.iso(future(-1)), label: "past")
        try store.insertReminder(vehicleId: v, serviceId: nil, kind: .petrol, notificationId: nil, fireAt: DateUtil.iso(future(2)), label: "imported")
        try store.insertReminder(vehicleId: v, serviceId: nil, kind: .service, notificationId: "live", fireAt: DateUtil.iso(future(5)), label: "ok")
        scheduler.live = ["live"]

        try await service.sync()

        let rows = try store.allReminders()
        let past = try XCTUnwrap(rows.first { $0.label == "past" })
        XCTAssertFalse(past.active)
        XCTAssertNil(past.notificationId)
        XCTAssertEqual(rows.first { $0.label == "imported" }?.notificationId, "n1")
        XCTAssertEqual(rows.first { $0.label == "ok" }?.notificationId, "live")
        XCTAssertEqual(scheduler.scheduled.count, 1)
    }

    func testSyncDoesNothingWithoutPermission() async throws {
        let (store, scheduler, service, v) = try setup()
        scheduler.state = .denied
        try store.insertReminder(vehicleId: v, serviceId: nil, kind: .petrol, notificationId: nil, fireAt: DateUtil.iso(future(2)), label: "x")
        try await service.sync()
        XCTAssertTrue(scheduler.scheduled.isEmpty)
    }

    func testBackupImportThenSyncRecreatesNotifications() async throws {
        let src = try makeStore()
        let v = try src.createVehicle(VehicleInput(type: .bike, name: "B"))
        try src.insertReminder(vehicleId: v, serviceId: nil, kind: .petrol, notificationId: "old-device-id", fireAt: DateUtil.iso(future(4)), label: "fuel")
        let backup = try Backup.build(from: src)

        let dst = try makeStore()
        let scheduler = FakeScheduler()
        try Backup.importBackup(backup, into: dst, mode: .replace)
        try await ReminderService(store: dst, scheduler: scheduler).sync()

        XCTAssertEqual(scheduler.scheduled.count, 1)
        XCTAssertEqual(try dst.allReminders()[0].notificationId, "n1")
    }
}
