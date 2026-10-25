import Foundation
@testable import Core

func makeStore() throws -> DataStore { try DataStore.inMemory() }

/// Two vehicles, two services (one with parts and a reminder), two quick logs, custom settings.
@discardableResult
func seed(_ store: DataStore) throws -> (bike: Int, car: Int, service: Int) {
    let bike = try store.createVehicle(VehicleInput(type: .bike, name: "Duke", make: "KTM", model: "200", regNo: "TN01AB1234"))
    let car = try store.createVehicle(VehicleInput(type: .car, name: "Swift"))
    let s1 = try store.saveService(ServiceInput(
        vehicleId: bike, date: "2026-05-01", title: "General service", notes: "chain, \"oil\"\nnew line", labourCost: 300,
        parts: [PartInput(name: "Oil", price: 400, qty: 1), PartInput(name: "Filter", price: 120, qty: 2)], nextDueDate: "2026-11-01"))
    try store.saveService(ServiceInput(vehicleId: car, date: "2026-06-10", title: "Wash", notes: "", labourCost: 200, parts: [], nextDueDate: nil))
    try store.addQuickLog(QuickLogInput(vehicleId: bike, kind: .petrol, date: "2026-10-01", cost: 500, litres: 5.2, note: ""))
    try store.addQuickLog(QuickLogInput(vehicleId: bike, kind: .tyreAir, date: "2026-10-02", cost: nil, litres: nil, note: ""))
    try store.insertReminder(vehicleId: bike, serviceId: s1, kind: .service, notificationId: "abc", fireAt: "2026-10-29T03:30:00.000Z", label: "due")
    try store.saveSetting(key: "tyreIntervalDays", value: "21")
    try store.saveSetting(key: "onboardingDone", value: "1")
    return (bike, car, s1)
}

func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
    DateUtil.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}

func parts(_ d: Date) -> [Int] {
    let c = DateUtil.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: d)
    return [c.year!, c.month!, c.day!, c.hour!, c.minute!]
}

/// Records what would have been scheduled, in place of the real notification centre.
final class FakeScheduler: NotificationScheduler {
    var state: NotificationPermission = .granted
    var requestResult = true
    var scheduled: [(id: String, title: String, body: String, date: Date)] = []
    var cancelled: [String] = []
    var cancelledAll = false
    var live: Set<String> = []
    private var counter = 0

    func permission() async -> NotificationPermission { state }
    func requestPermission() async -> Bool {
        if requestResult { state = .granted } else { state = .denied }
        return requestResult
    }
    func schedule(title: String, body: String, at date: Date) async throws -> String {
        counter += 1
        let id = "n\(counter)"
        scheduled.append((id, title, body, date))
        return id
    }
    func cancel(id: String) async { cancelled.append(id) }
    func cancelAll() async { cancelledAll = true }
    func pendingIdentifiers() async -> Set<String> { live }
}
