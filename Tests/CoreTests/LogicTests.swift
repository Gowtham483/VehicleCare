import XCTest
@testable import Core

final class CostsTests: CoreTestCase {
    func testPartsTotalIsPriceTimesQty() {
        XCTAssertEqual(Costs.partsTotal([PartInput(name: "a", price: 100, qty: 2), PartInput(name: "b", price: 50.5, qty: 1)]), 250.5)
    }
    func testNoParts() {
        XCTAssertEqual(Costs.partsTotal([]), 0)
        XCTAssertEqual(Costs.serviceTotal(labour: 300, parts: []), 300)
    }
    func testNoFloatDrift() {
        XCTAssertEqual(Costs.serviceTotal(labour: 0.1, parts: [PartInput(name: "x", price: 0.2, qty: 1)]), 0.3)
    }
    func testLabourPlusParts() {
        XCTAssertEqual(Costs.serviceTotal(labour: 500, parts: [PartInput(name: "oil", price: 400, qty: 1), PartInput(name: "filter", price: 120, qty: 1)]), 1020)
    }
    func testParseAmount() {
        XCTAssertEqual(Costs.parseAmount("12,5"), 12.5)
        XCTAssertEqual(Costs.parseAmount(""), 0)
        XCTAssertEqual(Costs.parseAmount("abc", fallback: 7), 7)
        XCTAssertEqual(Costs.parseAmount("-3"), 0)
    }
}

final class ScheduleTests: CoreTestCase {
    let now = date(2026, 10, 24, 15, 30)

    func testFiresNDaysLaterAtHour() {
        XCTAssertEqual(parts(Schedule.fireAt(now: now, days: 14, hour: 9)), [2026, 11, 7, 9, 0])
    }
    func testServiceUsesLeadTimeWhenStillAhead() {
        let d = Schedule.serviceFireAt(now: now, dueDate: date(2026, 12, 1), leadDays: 3, hour: 9)!
        XCTAssertEqual(parts(d), [2026, 11, 28, 9, 0])
    }
    func testFallsBackToDueDateWhenLeadPassed() {
        let d = Schedule.serviceFireAt(now: now, dueDate: date(2026, 10, 26), leadDays: 3, hour: 9)!
        XCTAssertEqual(parts(d), [2026, 10, 26, 9, 0])
    }
    func testNilWhenDuePassed() {
        XCTAssertNil(Schedule.serviceFireAt(now: now, dueDate: date(2026, 10, 24), leadDays: 3, hour: 9))
        XCTAssertNil(Schedule.serviceFireAt(now: now, dueDate: date(2026, 9, 1), leadDays: 0, hour: 9))
    }
    func testRetentionCutoff() {
        XCTAssertEqual(Retention.cutoff(now: now, months: 24), "2024-10-24")
    }
}

final class DateUtilTests: CoreTestCase {
    func testStrictParsing() {
        XCTAssertTrue(DateUtil.isValid("2026-02-28"))
        XCTAssertFalse(DateUtil.isValid("2026-02-30"))
        XCTAssertFalse(DateUtil.isValid("26-1-1"))
        XCTAssertFalse(DateUtil.isValid("yesterday"))
    }
    func testIsoRoundTrip() {
        let d = date(2026, 10, 24, 10, 0)
        XCTAssertEqual(DateUtil.parseISO(DateUtil.iso(d)), d)
        XCTAssertNotNil(DateUtil.parseISO("2026-10-29T03:30:00.000Z")) // JS toISOString shape
        XCTAssertNotNil(DateUtil.parseISO("2026-10-29T03:30:00Z"))
    }
}

final class SettingsTests: CoreTestCase {
    func testDefaultsAndFallbacks() {
        XCTAssertEqual(AppSettings.parse([:]), AppSettings.defaults)
        let s = AppSettings.parse(["tyreIntervalDays": "0", "notifyHour": "25", "petrolIntervalDays": "10", "currency": "$", "onboardingDone": "1"])
        XCTAssertEqual(s.tyreIntervalDays, 14)
        XCTAssertEqual(s.notifyHour, 9)
        XCTAssertEqual(s.petrolIntervalDays, 10)
        XCTAssertEqual(s.currency, "$")
        XCTAssertTrue(s.onboardingDone)
    }
}

final class AppearanceSettingTests: CoreTestCase {
    func testDefaultsToFollowingTheDevice() {
        XCTAssertEqual(AppSettings.defaults.appearance, .system)
        XCTAssertEqual(AppSettings.parse([:]).appearance, .system)
    }

    func testParsesEachChoiceAndIgnoresGarbage() {
        XCTAssertEqual(AppSettings.parse(["appearance": "light"]).appearance, .light)
        XCTAssertEqual(AppSettings.parse(["appearance": "dark"]).appearance, .dark)
        XCTAssertEqual(AppSettings.parse(["appearance": "system"]).appearance, .system)
        XCTAssertEqual(AppSettings.parse(["appearance": "sepia"]).appearance, .system)
    }

    func testIsStoredAndLoadedFromTheDatabase() throws {
        let store = try makeStore()
        var settings = try store.loadSettings()
        XCTAssertEqual(settings.appearance, .system)
        settings.appearance = .dark
        for (key, value) in settings.asStored { try store.saveSetting(key: key, value: value) }
        XCTAssertEqual(try store.loadSettings().appearance, .dark)
    }

    func testIsPerDeviceAndNotPartOfBackups() throws {
        XCTAssertFalse(AppSettings.backupKeys.contains("appearance"))
        let store = try makeStore()
        try store.saveSetting(key: "appearance", value: "dark")
        let backup = try Backup.build(from: store)
        XCTAssertNil(backup.settings["appearance"])
        // and importing a backup must not change the device's look
        try Backup.importBackup(backup, into: store, mode: .replace)
        XCTAssertEqual(try store.loadSettings().appearance, .dark)
    }
}

final class StoreTests: CoreTestCase {
    func testServiceTotalAndParts() throws {
        let store = try makeStore()
        let (_, _, sid) = try seed(store)
        XCTAssertEqual(try store.service(id: sid)?.totalCost, 940)
        XCTAssertEqual(try store.parts(serviceId: sid).count, 2)
    }
    func testEditingReplacesParts() throws {
        let store = try makeStore()
        let (bike, _, sid) = try seed(store)
        try store.saveService(ServiceInput(vehicleId: bike, date: "2026-05-01", title: "General service", notes: "", labourCost: 100,
                                           parts: [PartInput(name: "Only", price: 10, qty: 3)], nextDueDate: nil), id: sid)
        XCTAssertEqual(try store.parts(serviceId: sid).map(\.name), ["Only"])
        XCTAssertEqual(try store.service(id: sid)?.totalCost, 130)
    }
    func testBlankPartsAreIgnored() throws {
        let store = try makeStore()
        let v = try store.createVehicle(VehicleInput(type: .car, name: "C"))
        let sid = try store.saveService(ServiceInput(vehicleId: v, date: "2026-01-01", title: "t", notes: "", labourCost: 0,
                                                     parts: [PartInput(name: "  ", price: 99, qty: 1)], nextDueDate: nil))
        XCTAssertEqual(try store.parts(serviceId: sid).count, 0)
        XCTAssertEqual(try store.service(id: sid)?.totalCost, 0)
    }
    func testDeletingVehicleCascades() throws {
        let store = try makeStore()
        let (bike, _, _) = try seed(store)
        try store.deleteVehicle(id: bike)
        XCTAssertEqual(try store.services().map(\.title), ["Wash"])
        XCTAssertEqual(try store.quickLogs().count, 0)
        XCTAssertEqual(try store.allReminders().count, 0)
    }
    func testRetentionPurge() throws {
        let store = try makeStore()
        let v = try store.createVehicle(VehicleInput(type: .bike, name: "B"))
        let part = [PartInput(name: "p", price: 1, qty: 1)]
        let oldId = try store.saveService(ServiceInput(vehicleId: v, date: "2024-01-01", title: "old", notes: "", labourCost: 0, parts: part, nextDueDate: nil))
        try store.saveService(ServiceInput(vehicleId: v, date: "2026-09-01", title: "new", notes: "", labourCost: 0, parts: part, nextDueDate: nil))
        try store.addQuickLog(QuickLogInput(vehicleId: v, kind: .petrol, date: "2024-02-01", cost: 1, litres: 1, note: ""))
        try store.addQuickLog(QuickLogInput(vehicleId: v, kind: .petrol, date: "2026-10-01", cost: 1, litres: 1, note: ""))

        try store.purgeOldRecords(months: 24, now: date(2026, 10, 24))

        XCTAssertEqual(try store.services().map(\.title), ["new"])
        XCTAssertEqual(try store.parts(serviceId: oldId).count, 0)
        XCTAssertEqual(try store.quickLogs().count, 1)
    }
    func testResetAllWipesEverythingIncludingSettings() throws {
        let store = try makeStore()
        try seed(store)
        try store.resetAll()
        XCTAssertEqual(try store.vehicles().count, 0)
        XCTAssertFalse(try store.loadSettings().onboardingDone)
    }
    func testTransactionRollsBack() throws {
        let store = try makeStore()
        struct Boom: Error {}
        XCTAssertThrowsError(try store.db.transaction {
            try store.createVehicle(VehicleInput(type: .car, name: "x"))
            throw Boom()
        })
        XCTAssertEqual(try store.vehicles().count, 0)
    }
}
