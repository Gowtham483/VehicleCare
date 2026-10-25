import XCTest
@testable import Core

final class BackupTests: CoreTestCase {
    private func exported() throws -> (BackupFile, Data) {
        let store = try makeStore()
        try seed(store)
        let backup = try Backup.build(from: store)
        return (backup, try Backup.encode(backup))
    }

    private func validated(_ data: Data) throws -> BackupFile {
        switch Backup.validate(data) {
        case .success(let b): return b
        case .failure(let e): throw e
        }
    }

    private func mutate(_ data: Data, _ change: (inout [String: Any]) -> Void) throws -> Data {
        var obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        change(&obj)
        return try JSONSerialization.data(withJSONObject: obj)
    }

    func testRoundTripReplaceIntoEmptyDatabase() throws {
        let (_, data) = try exported()
        let backup = try validated(data)
        let dst = try makeStore()
        try Backup.importBackup(backup, into: dst, mode: .replace)

        XCTAssertEqual(try dst.vehicles().map(\.name), ["Duke", "Swift"])
        let services = try dst.services()
        XCTAssertEqual(services.count, 2)
        let general = try XCTUnwrap(services.first { $0.title == "General service" })
        XCTAssertEqual(general.totalCost, 940)
        XCTAssertEqual(general.notes, "chain, \"oil\"\nnew line")
        XCTAssertEqual(try dst.parts(serviceId: general.id).count, 2)
        XCTAssertEqual(try dst.quickLogs().count, 2)

        let reminders = try dst.allReminders()
        XCTAssertEqual(reminders.count, 1)
        XCTAssertNil(reminders[0].notificationId) // device-specific; re-created by sync
        XCTAssertEqual(reminders[0].serviceId, general.id)

        let settings = try dst.loadSettings()
        XCTAssertEqual(settings.tyreIntervalDays, 21)
        XCTAssertFalse(settings.onboardingDone) // per-device state is not transferred
    }

    func testMergeIntoItselfSkipsDuplicates() throws {
        let store = try makeStore()
        try seed(store)
        let backup = try Backup.build(from: store)
        let added = try Backup.importBackup(backup, into: store, mode: .merge)
        XCTAssertEqual(added, BackupSummary())
        XCTAssertEqual(try store.vehicles().count, 2)
        XCTAssertEqual(try store.services().count, 2)
    }

    func testMergeAddsToExistingData() throws {
        let (_, data) = try exported()
        let backup = try validated(data)
        let dst = try makeStore()
        let other = try dst.createVehicle(VehicleInput(type: .car, name: "Other"))
        try dst.saveService(ServiceInput(vehicleId: other, date: "2026-01-01", title: "Mine", notes: "", labourCost: 10, parts: [], nextDueDate: nil))

        let added = try Backup.importBackup(backup, into: dst, mode: .merge)
        XCTAssertEqual(added.vehicles, 2)
        XCTAssertEqual(added.services, 2)
        XCTAssertEqual(try dst.vehicles().count, 3)
        let duke = try XCTUnwrap(try dst.vehicles().first { $0.name == "Duke" })
        XCTAssertEqual(try dst.services(vehicleId: duke.id).map(\.title), ["General service"])
    }

    func testReplaceWipesExistingData() throws {
        let (_, data) = try exported()
        let dst = try makeStore()
        try dst.createVehicle(VehicleInput(type: .car, name: "Old"))
        try Backup.importBackup(try validated(data), into: dst, mode: .replace)
        XCTAssertEqual(try dst.vehicles().map(\.name), ["Duke", "Swift"])
    }

    func testFailingImportRollsBack() throws {
        var (backup, _) = try exported()
        backup.services[0].vehicleId = 9999 // dangling reference that slipped past validation
        let dst = try makeStore()
        try dst.createVehicle(VehicleInput(type: .car, name: "Keep me"))
        XCTAssertThrowsError(try Backup.importBackup(backup, into: dst, mode: .replace))
        XCTAssertEqual(try dst.vehicles().map(\.name), ["Keep me"])
    }

    // MARK: Validation

    func testRejectsGarbage() {
        XCTAssertThrowsError(try validated(Data("nope".utf8)))
        XCTAssertThrowsError(try validated(Data(#"{"app":"other"}"#.utf8)))
        XCTAssertThrowsError(try validated(Data("[]".utf8)))
    }

    func testRejectsNewerSchema() throws {
        let (_, data) = try exported()
        let newer = try mutate(data) { $0["schemaVersion"] = 99 }
        XCTAssertThrowsError(try validated(newer)) { XCTAssertTrue("\($0)".contains("newer version") || ($0 as? BackupError)?.message.contains("newer version") == true) }
    }

    func testRejectsMissingTablesBadFieldsAndDanglingReferences() throws {
        let (_, data) = try exported()
        XCTAssertThrowsError(try validated(try mutate(data) { $0.removeValue(forKey: "services") }))
        XCTAssertThrowsError(try validated(try mutate(data) {
            var services = $0["services"] as! [[String: Any]]; services[0]["date"] = "yesterday"; $0["services"] = services
        }))
        XCTAssertThrowsError(try validated(try mutate(data) {
            var services = $0["services"] as! [[String: Any]]; services[0]["vehicle_id"] = 12345; $0["services"] = services
        }))
        XCTAssertThrowsError(try validated(try mutate(data) {
            var vehicles = $0["vehicles"] as! [[String: Any]]; vehicles[0]["type"] = "plane"; $0["vehicles"] = vehicles
        }))
    }

    func testErrorMessagesNameTheField() throws {
        let (_, data) = try exported()
        let bad = try mutate(data) {
            var services = $0["services"] as! [[String: Any]]; services[1]["labour_cost"] = "free"; $0["services"] = services
        }
        guard case .failure(let error) = Backup.validate(bad) else { return XCTFail("expected failure") }
        XCTAssertEqual(error.message, "Invalid \"labour_cost\" in \"services\" (entry 2).")
    }

    func testAcceptsValidFileWithSummary() throws {
        let (_, data) = try exported()
        XCTAssertEqual(Backup.summary(try validated(data)), BackupSummary(vehicles: 2, services: 2, quickLogs: 2, reminders: 1))
    }

    // MARK: Compatibility with the Expo app

    /// A file shaped exactly like the Expo app's `JSON.stringify` output (integers for whole numbers, explicit nulls).
    func testImportsBackupWrittenByExpoApp() throws {
        let json = """
        {"app":"vehicle-care","schemaVersion":1,"exportedAt":"2026-10-24T10:00:00.000Z",
         "vehicles":[{"id":1,"type":"bike","name":"Duke","make":"KTM","model":"200","reg_no":"TN01","created_at":"2026-01-01T00:00:00.000Z"}],
         "services":[{"id":4,"vehicle_id":1,"date":"2026-05-01","title":"General service","notes":"oil","labour_cost":300,"total_cost":940,"next_due_date":null,"created_at":"2026-05-01T08:00:00.000Z"}],
         "serviceParts":[{"id":7,"service_id":4,"name":"Oil","price":400,"qty":1}],
         "quickLogs":[{"id":2,"vehicle_id":1,"kind":"petrol","date":"2026-10-01","cost":500,"litres":5.2,"note":""},
                      {"id":3,"vehicle_id":1,"kind":"tyre_air","date":"2026-10-02","cost":null,"litres":null,"note":""}],
         "reminders":[{"id":9,"vehicle_id":1,"service_id":null,"kind":"tyre_air","fire_at":"2026-11-06T03:30:00.000Z","label":"Check tyres","active":1}],
         "settings":{"tyreIntervalDays":"14","currency":"₹"}}
        """
        let backup = try validated(Data(json.utf8))
        let store = try makeStore()
        try Backup.importBackup(backup, into: store, mode: .replace)
        XCTAssertEqual(try store.services().first?.totalCost, 940)
        XCTAssertEqual(try store.quickLogs().count, 2)
        XCTAssertEqual(try store.allReminders().first?.kind, .tyreAir)
    }

    /// What we write must satisfy the Expo app's validator: every optional present as an explicit null.
    func testExportWritesExplicitNulls() throws {
        let (_, data) = try exported()
        let obj = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        let services = obj["services"] as! [[String: Any]]
        XCTAssertTrue(services.allSatisfy { $0.keys.contains("next_due_date") })
        XCTAssertTrue(services.contains { $0["next_due_date"] is NSNull })
        let quick = obj["quickLogs"] as! [[String: Any]]
        XCTAssertTrue(quick.allSatisfy { $0.keys.contains("cost") && $0.keys.contains("litres") })
        let reminders = obj["reminders"] as! [[String: Any]]
        XCTAssertTrue(reminders.allSatisfy { $0.keys.contains("service_id") && !$0.keys.contains("notification_id") })
        XCTAssertEqual(obj["app"] as? String, "vehicle-care")
        XCTAssertEqual(obj["schemaVersion"] as? Int, 1)
    }

    func testCsvEscaping() throws {
        let (backup, _) = try exported()
        let services = try XCTUnwrap(Backup.csvFiles(backup).first { $0.name == "services.csv" }).content
        XCTAssertEqual(services.components(separatedBy: "\n")[0], "id,vehicle,date,title,notes,labour_cost,total_cost,next_due_date")
        XCTAssertTrue(services.contains("\"chain, \"\"oil\"\"\nnew line\""))
    }
}
