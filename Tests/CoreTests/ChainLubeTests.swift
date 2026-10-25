import XCTest
@testable import Core

// Chain-lube quick action (bikes): schema v2 migration, data, reminders, setting and backup versioning.

final class SchemaMigrationTests: CoreTestCase {
    /// A database exactly as version 1 of the app left it, with data in every table.
    private func versionOneDatabase() throws -> Database {
        let db = try Database(path: ":memory:")
        try Migrations.migrate(db, upTo: 1)
        XCTAssertEqual(db.userVersion, 1)
        try db.run("INSERT INTO vehicle (type, name, make, model, reg_no, created_at) VALUES ('bike', 'Duke', '', '', '', '2026-01-01T00:00:00.000Z')")
        try db.run("INSERT INTO service (vehicle_id, date, title, notes, labour_cost, total_cost, next_due_date, created_at) VALUES (1, '2026-05-01', 'General', '', 300, 940, '2026-11-01', 'x')")
        try db.run("INSERT INTO service_part (service_id, name, price, qty) VALUES (1, 'Oil', 400, 1)")
        try db.run("INSERT INTO quick_log (vehicle_id, kind, date, cost, litres, note) VALUES (1, 'petrol', '2026-10-01', 500, 5.2, 'full')")
        try db.run("INSERT INTO quick_log (vehicle_id, kind, date, cost, litres, note) VALUES (1, 'tyre_air', '2026-10-02', NULL, NULL, '')")
        try db.run("INSERT INTO reminder (vehicle_id, service_id, kind, notification_id, fire_at, label, active) VALUES (1, 1, 'service', 'abc', '2026-10-29T03:30:00.000Z', 'due', 1)")
        try db.run("INSERT INTO settings (key, value) VALUES ('tyreIntervalDays', '21')")
        return db
    }

    func testVersionOneRejectsLubeBecauseOfItsCheckConstraint() throws {
        let db = try versionOneDatabase()
        XCTAssertThrowsError(try db.run("INSERT INTO quick_log (vehicle_id, kind, date, note) VALUES (1, 'lube', '2026-10-03', '')"),
                             "this proves the old schema really blocked the new kind, so the test below is meaningful")
    }

    func testUpgradeKeepsEveryRowAndAllowsLube() throws {
        let db = try versionOneDatabase()
        try Migrations.migrate(db)
        XCTAssertEqual(db.userVersion, 2)

        let store = try DataStore(db: db)
        XCTAssertEqual(try store.vehicles().map(\.name), ["Duke"])
        XCTAssertEqual(try store.services().first?.totalCost, 940)
        XCTAssertEqual(try store.parts(serviceId: 1).count, 1)
        let logs = try store.quickLogs()
        XCTAssertEqual(Set(logs.map(\.kind)), [.petrol, .tyreAir])
        XCTAssertEqual(logs.first { $0.kind == .petrol }?.litres, 5.2)
        XCTAssertEqual(logs.first { $0.kind == .petrol }?.note, "full")
        let reminder = try XCTUnwrap(try store.allReminders().first)
        XCTAssertEqual(reminder.notificationId, "abc")
        XCTAssertEqual(reminder.serviceId, 1)
        XCTAssertEqual(try store.loadSettings().tyreIntervalDays, 21)

        // new kind now works, and new ids continue after the old ones
        let id = try store.addQuickLog(QuickLogInput(vehicleId: 1, kind: .lube, date: "2026-10-03", cost: 120, litres: nil, note: ""))
        XCTAssertGreaterThan(id, 2)
        XCTAssertEqual(try store.lastQuickLog(vehicleId: 1, kind: .lube)?.cost, 120)
    }

    func testUpgradeKeepsRelationsAndIndexes() throws {
        let db = try versionOneDatabase()
        try Migrations.migrate(db)
        // cascade still works from the rebuilt tables
        try db.run("DELETE FROM vehicle WHERE id = 1")
        XCTAssertEqual(try db.first("SELECT COUNT(*) AS n FROM quick_log")?.int("n"), 0)
        XCTAssertEqual(try db.first("SELECT COUNT(*) AS n FROM reminder")?.int("n"), 0)
        let indexes = try db.all("SELECT name FROM sqlite_master WHERE type = 'index'").map { $0.string("name") }
        XCTAssertTrue(indexes.contains("idx_quick_vehicle_date"))
        XCTAssertTrue(indexes.contains("idx_service_vehicle_date"))
    }

    func testFreshDatabaseStartsAtVersionTwoAndMigrationIsIdempotent() throws {
        let store = try makeStore()
        XCTAssertEqual(store.db.userVersion, Migrations.databaseVersion)
        XCTAssertEqual(Migrations.databaseVersion, 2)
        try Migrations.migrate(store.db) // running again changes nothing
        XCTAssertEqual(store.db.userVersion, 2)
    }
}

final class ChainLubeDataTests: CoreTestCase {
    func testQuickLogRoundTripAndLastLube() throws {
        let store = try makeStore()
        let bike = try store.createVehicle(VehicleInput(type: .bike, name: "B"))
        try store.addQuickLog(QuickLogInput(vehicleId: bike, kind: .lube, date: "2026-09-01", cost: nil, litres: nil, note: "dry"))
        try store.addQuickLog(QuickLogInput(vehicleId: bike, kind: .lube, date: "2026-10-01", cost: 90, litres: nil, note: ""))
        XCTAssertEqual(try store.lastQuickLog(vehicleId: bike, kind: .lube)?.date, "2026-10-01")
        XCTAssertNil(try store.lastQuickLog(vehicleId: bike, kind: .petrol), "kinds stay separate")
        XCTAssertEqual(try store.quickLogs().filter { $0.kind == .lube }.count, 2)
    }

    func testKindsMapToTheRightReminderAndText() {
        XCTAssertEqual(QuickKind.lube.reminderKind, .lube)
        XCTAssertEqual(QuickKind.tyreAir.reminderKind, .tyreAir)
        XCTAssertEqual(QuickKind.petrol.reminderKind, .petrol)
        XCTAssertEqual(ReminderService.title(for: .lube), "Lube your chain")
        XCTAssertEqual(QuickKind.lube.reminderBody(vehicleName: "Duke"), "Time to clean and lube the chain on Duke.")
        TestLocalization.use("ar")
        XCTAssertEqual(ReminderService.title(for: .lube), "حان وقت تشحيم السلسلة")
    }

    func testSecondLubeReminderReplacesTheFirst() async throws {
        let store = try makeStore()
        let scheduler = FakeScheduler()
        let service = ReminderService(store: store, scheduler: scheduler)
        let bike = try store.createVehicle(VehicleInput(type: .bike, name: "B"))
        let soon = Date().addingTimeInterval(30 * 86_400)
        _ = try await service.setReminder(vehicleId: bike, kind: .lube, fireAt: soon, body: "first")
        _ = try await service.setReminder(vehicleId: bike, kind: .lube, fireAt: soon, body: "second")
        XCTAssertEqual(scheduler.cancelled, ["n1"])
        let rows = try store.allReminders()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].kind, .lube)
        XCTAssertEqual(rows[0].label, "second")
        XCTAssertEqual(scheduler.scheduled.last?.title, "Lube your chain")
    }

    func testLubeReminderIsIndependentOfTyreAndPetrol() async throws {
        let store = try makeStore()
        let service = ReminderService(store: store, scheduler: FakeScheduler())
        let bike = try store.createVehicle(VehicleInput(type: .bike, name: "B"))
        let soon = Date().addingTimeInterval(86_400)
        _ = try await service.setReminder(vehicleId: bike, kind: .tyreAir, fireAt: soon, body: "t")
        _ = try await service.setReminder(vehicleId: bike, kind: .petrol, fireAt: soon, body: "p")
        _ = try await service.setReminder(vehicleId: bike, kind: .lube, fireAt: soon, body: "l")
        XCTAssertEqual(Set(try store.allReminders().map(\.kind)), [.tyreAir, .petrol, .lube])
    }

    func testLubeIntervalSetting() throws {
        XCTAssertEqual(AppSettings.defaults.lubeIntervalDays, 30)
        XCTAssertEqual(AppSettings.parse([:]).lubeIntervalDays, 30)
        XCTAssertEqual(AppSettings.parse(["lubeIntervalDays": "45"]).lubeIntervalDays, 45)
        XCTAssertEqual(AppSettings.parse(["lubeIntervalDays": "0"]).lubeIntervalDays, 30, "out of range falls back")
        XCTAssertEqual(AppSettings.parse(["lubeIntervalDays": "400"]).lubeIntervalDays, 30)
        XCTAssertEqual(AppSettings.parse(["lubeIntervalDays": "soon"]).lubeIntervalDays, 30)
        XCTAssertTrue(AppSettings.backupKeys.contains("lubeIntervalDays"))
        let store = try makeStore()
        var settings = try store.loadSettings()
        settings.lubeIntervalDays = 21
        for (key, value) in settings.asStored { try store.saveSetting(key: key, value: value) }
        XCTAssertEqual(try store.loadSettings().lubeIntervalDays, 21)
    }
}

final class ChainLubeBackupTests: CoreTestCase {
    private func version(of backup: BackupFile) throws -> Int {
        let object = try JSONSerialization.jsonObject(with: Backup.encode(backup)) as! [String: Any]
        return object["schemaVersion"] as! Int
    }

    func testBackupWithoutLubeStaysVersionOneForOlderApps() throws {
        let store = try makeStore()
        try seed(store)
        XCTAssertEqual(try version(of: Backup.build(from: store)), 1)
    }

    func testBackupWithLubeIsVersionTwoAndRoundTrips() throws {
        let store = try makeStore()
        let (bike, _, _) = try seed(store)
        try store.addQuickLog(QuickLogInput(vehicleId: bike, kind: .lube, date: "2026-10-05", cost: 80, litres: nil, note: "spray"))
        let backup = try Backup.build(from: store)
        XCTAssertEqual(try version(of: backup), 2)

        let data = try Backup.encode(backup)
        guard case .success(let parsed) = Backup.validate(data) else { return XCTFail("a version 2 file must validate") }
        let dst = try makeStore()
        try Backup.importBackup(parsed, into: dst, mode: .replace)
        let lube = try XCTUnwrap(try dst.quickLogs().first { $0.kind == .lube })
        XCTAssertEqual(lube.cost, 80)
        XCTAssertEqual(lube.note, "spray")
        XCTAssertEqual(try dst.quickLogs().count, 3)
    }

    func testLubeReminderAlsoMakesTheFileVersionTwo() throws {
        let store = try makeStore()
        let bike = try store.createVehicle(VehicleInput(type: .bike, name: "B"))
        try store.insertReminder(vehicleId: bike, serviceId: nil, kind: .lube, notificationId: nil, fireAt: "2026-12-01T03:30:00.000Z", label: "x")
        let backup = try Backup.build(from: store)
        XCTAssertEqual(try version(of: backup), 2)
        guard case .success(let parsed) = Backup.validate(try Backup.encode(backup)) else { return XCTFail() }
        let dst = try makeStore()
        try Backup.importBackup(parsed, into: dst, mode: .replace)
        XCTAssertEqual(try dst.allReminders().first?.kind, .lube)
    }

    func testOldVersionOneFilesStillImport() throws {
        let json = """
        {"app":"vehicle-care","schemaVersion":1,"exportedAt":"2026-10-24T10:00:00.000Z",
         "vehicles":[{"id":1,"type":"bike","name":"Duke","make":"","model":"","reg_no":"","created_at":"x"}],
         "services":[],"serviceParts":[],
         "quickLogs":[{"id":1,"vehicle_id":1,"kind":"petrol","date":"2026-10-01","cost":500,"litres":5,"note":""}],
         "reminders":[],"settings":{}}
        """
        guard case .success(let backup) = Backup.validate(Data(json.utf8)) else { return XCTFail() }
        let store = try makeStore()
        try Backup.importBackup(backup, into: store, mode: .replace)
        XCTAssertEqual(try store.quickLogs().first?.kind, .petrol)
    }

    func testStillRefusesNewerVersionsAndUnknownKinds() throws {
        let store = try makeStore()
        try seed(store)
        var object = try JSONSerialization.jsonObject(with: Backup.encode(Backup.build(from: store))) as! [String: Any]
        object["schemaVersion"] = 3
        XCTAssertThrowsError(try { if case .failure(let e) = Backup.validate(try JSONSerialization.data(withJSONObject: object)) { throw e } }())

        object["schemaVersion"] = 2
        var logs = object["quickLogs"] as! [[String: Any]]
        logs[0]["kind"] = "oil"
        object["quickLogs"] = logs
        guard case .failure(let error) = Backup.validate(try JSONSerialization.data(withJSONObject: object)) else { return XCTFail("an unknown kind must be rejected") }
        XCTAssertEqual(error.message, "Invalid \"kind\" in \"quickLogs\" (entry 1).")
    }

    func testCsvExportKeepsLubeKind() throws {
        let store = try makeStore()
        let bike = try store.createVehicle(VehicleInput(type: .bike, name: "B"))
        try store.addQuickLog(QuickLogInput(vehicleId: bike, kind: .lube, date: "2026-10-05", cost: nil, litres: nil, note: ""))
        let csv = try XCTUnwrap(Backup.csvFiles(try Backup.build(from: store)).first { $0.name == "quick-logs.csv" }).content
        XCTAssertTrue(csv.contains("B,lube,2026-10-05"), csv)
    }
}
