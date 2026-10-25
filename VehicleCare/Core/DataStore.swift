import Foundation

/// All SQL lives here. Screens and services call these methods and never touch SQL directly.
final class DataStore {
    let db: Database

    init(db: Database) throws {
        self.db = db
        try Migrations.migrate(db)
    }

    /// An in-memory store, used by tests.
    static func inMemory() throws -> DataStore { try DataStore(db: Database(path: ":memory:")) }

    // MARK: Row mapping

    private func vehicle(_ r: Row) -> Vehicle {
        Vehicle(id: r.int("id"), type: VehicleType(rawValue: r.string("type")) ?? .bike, name: r.string("name"),
                make: r.string("make"), model: r.string("model"), regNo: r.string("reg_no"), createdAt: r.string("created_at"))
    }
    private func service(_ r: Row) -> Service {
        Service(id: r.int("id"), vehicleId: r.int("vehicle_id"), date: r.string("date"), title: r.string("title"),
                notes: r.string("notes"), labourCost: r.double("labour_cost"), totalCost: r.double("total_cost"),
                nextDueDate: r.optString("next_due_date"), createdAt: r.string("created_at"))
    }
    private func part(_ r: Row) -> ServicePart {
        ServicePart(id: r.int("id"), serviceId: r.int("service_id"), name: r.string("name"), price: r.double("price"), qty: r.double("qty"))
    }
    private func quickLog(_ r: Row) -> QuickLog {
        QuickLog(id: r.int("id"), vehicleId: r.int("vehicle_id"), kind: QuickKind(rawValue: r.string("kind")) ?? .petrol,
                 date: r.string("date"), cost: r.optDouble("cost"), litres: r.optDouble("litres"), note: r.string("note"))
    }
    private func reminder(_ r: Row) -> Reminder {
        Reminder(id: r.int("id"), vehicleId: r.int("vehicle_id"), serviceId: r.optInt("service_id"),
                 kind: ReminderKind(rawValue: r.string("kind")) ?? .service, notificationId: r.optString("notification_id"),
                 fireAt: r.string("fire_at"), label: r.string("label"), active: r.int("active") == 1)
    }

    // MARK: Vehicles

    func vehicles() throws -> [Vehicle] { try db.all("SELECT * FROM vehicle ORDER BY created_at, id").map(vehicle) }
    func vehicle(id: Int) throws -> Vehicle? { try db.first("SELECT * FROM vehicle WHERE id = ?", [id]).map(vehicle) }

    @discardableResult
    func createVehicle(_ v: VehicleInput) throws -> Int {
        try db.run("INSERT INTO vehicle (type, name, make, model, reg_no, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                   [v.type.rawValue, v.name, v.make, v.model, v.regNo, DateUtil.iso(Date())]).lastInsertId
    }

    func updateVehicle(id: Int, _ v: VehicleInput) throws {
        try db.run("UPDATE vehicle SET type = ?, name = ?, make = ?, model = ?, reg_no = ? WHERE id = ?",
                   [v.type.rawValue, v.name, v.make, v.model, v.regNo, id])
    }

    /// Cascades to services, parts, quick logs and reminders. Cancel notifications first.
    func deleteVehicle(id: Int) throws { try db.run("DELETE FROM vehicle WHERE id = ?", [id]) }

    // MARK: Services

    func services(vehicleId: Int? = nil) throws -> [Service] {
        if let vehicleId {
            return try db.all("SELECT * FROM service WHERE vehicle_id = ? ORDER BY date DESC, id DESC", [vehicleId]).map(service)
        }
        return try db.all("SELECT * FROM service ORDER BY date DESC, id DESC").map(service)
    }

    func service(id: Int) throws -> Service? { try db.first("SELECT * FROM service WHERE id = ?", [id]).map(service) }
    func parts(serviceId: Int) throws -> [ServicePart] {
        try db.all("SELECT * FROM service_part WHERE service_id = ? ORDER BY id", [serviceId]).map(part)
    }

    /// Inserts or updates a service and replaces its parts in one transaction. Returns the service id.
    @discardableResult
    func saveService(_ input: ServiceInput, id: Int? = nil) throws -> Int {
        let parts = input.parts.map { PartInput(name: $0.name.trimmingCharacters(in: .whitespaces), price: $0.price, qty: $0.qty) }
            .filter { !$0.name.isEmpty }
        let total = Costs.serviceTotal(labour: input.labourCost, parts: parts)
        return try db.transaction {
            var serviceId = id ?? 0
            if let id {
                try db.run("""
                    UPDATE service SET vehicle_id = ?, date = ?, title = ?, notes = ?, labour_cost = ?, total_cost = ?, next_due_date = ?
                    WHERE id = ?
                    """, [input.vehicleId, input.date, input.title, input.notes, input.labourCost, total, input.nextDueDate, id])
            } else {
                serviceId = try db.run("""
                    INSERT INTO service (vehicle_id, date, title, notes, labour_cost, total_cost, next_due_date, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """, [input.vehicleId, input.date, input.title, input.notes, input.labourCost, total, input.nextDueDate, DateUtil.iso(Date())]).lastInsertId
            }
            try db.run("DELETE FROM service_part WHERE service_id = ?", [serviceId])
            for p in parts {
                try db.run("INSERT INTO service_part (service_id, name, price, qty) VALUES (?, ?, ?, ?)", [serviceId, p.name, p.price, p.qty])
            }
            return serviceId
        }
    }

    /// Cascades to parts and the service reminder row. Cancel the notification first.
    func deleteService(id: Int) throws { try db.run("DELETE FROM service WHERE id = ?", [id]) }

    // MARK: Quick logs

    func quickLogs(vehicleId: Int? = nil) throws -> [QuickLog] {
        if let vehicleId {
            return try db.all("SELECT * FROM quick_log WHERE vehicle_id = ? ORDER BY date DESC, id DESC", [vehicleId]).map(quickLog)
        }
        return try db.all("SELECT * FROM quick_log ORDER BY date DESC, id DESC").map(quickLog)
    }

    func lastQuickLog(vehicleId: Int, kind: QuickKind) throws -> QuickLog? {
        try db.first("SELECT * FROM quick_log WHERE vehicle_id = ? AND kind = ? ORDER BY date DESC, id DESC LIMIT 1",
                     [vehicleId, kind.rawValue]).map(quickLog)
    }

    @discardableResult
    func addQuickLog(_ q: QuickLogInput) throws -> Int {
        try db.run("INSERT INTO quick_log (vehicle_id, kind, date, cost, litres, note) VALUES (?, ?, ?, ?, ?, ?)",
                   [q.vehicleId, q.kind.rawValue, q.date, q.cost, q.litres, q.note]).lastInsertId
    }

    func deleteQuickLog(id: Int) throws { try db.run("DELETE FROM quick_log WHERE id = ?", [id]) }

    // MARK: Reminders

    func activeReminders(vehicleId: Int? = nil) throws -> [Reminder] {
        if let vehicleId {
            return try db.all("SELECT * FROM reminder WHERE active = 1 AND vehicle_id = ? ORDER BY fire_at", [vehicleId]).map(reminder)
        }
        return try db.all("SELECT * FROM reminder WHERE active = 1 ORDER BY fire_at").map(reminder)
    }

    func allReminders() throws -> [Reminder] { try db.all("SELECT * FROM reminder ORDER BY id").map(reminder) }

    func reminders(vehicleId: Int) throws -> [Reminder] {
        try db.all("SELECT * FROM reminder WHERE vehicle_id = ?", [vehicleId]).map(reminder)
    }

    func findReminders(vehicleId: Int, kind: ReminderKind, serviceId: Int?) throws -> [Reminder] {
        if let serviceId {
            return try db.all("SELECT * FROM reminder WHERE vehicle_id = ? AND kind = ? AND service_id = ?",
                              [vehicleId, kind.rawValue, serviceId]).map(reminder)
        }
        return try db.all("SELECT * FROM reminder WHERE vehicle_id = ? AND kind = ? AND service_id IS NULL",
                          [vehicleId, kind.rawValue]).map(reminder)
    }

    @discardableResult
    func insertReminder(vehicleId: Int, serviceId: Int?, kind: ReminderKind, notificationId: String?, fireAt: String, label: String) throws -> Int {
        try db.run("INSERT INTO reminder (vehicle_id, service_id, kind, notification_id, fire_at, label, active) VALUES (?, ?, ?, ?, ?, ?, 1)",
                   [vehicleId, serviceId, kind.rawValue, notificationId, fireAt, label]).lastInsertId
    }

    func setNotificationId(reminderId: Int, _ notificationId: String?) throws {
        try db.run("UPDATE reminder SET notification_id = ? WHERE id = ?", [notificationId, reminderId])
    }

    func deactivateReminder(id: Int) throws { try db.run("UPDATE reminder SET active = 0, notification_id = NULL WHERE id = ?", [id]) }
    func deleteReminder(id: Int) throws { try db.run("DELETE FROM reminder WHERE id = ?", [id]) }

    // MARK: Settings

    func loadSettings() throws -> AppSettings {
        var raw: [String: String] = [:]
        for r in try db.all("SELECT key, value FROM settings") { raw[r.string("key")] = r.string("value") }
        return AppSettings.parse(raw)
    }

    func saveSetting(key: String, value: String) throws {
        try db.run("INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)", [key, value])
    }

    // MARK: Maintenance

    /// Deletes records older than the retention window. Services cascade to parts and reminders.
    @discardableResult
    func purgeOldRecords(months: Int, now: Date = Date()) throws -> String {
        let cutoff = Retention.cutoff(now: now, months: months)
        try db.transaction {
            try db.run("DELETE FROM service WHERE date < ?", [cutoff])
            try db.run("DELETE FROM quick_log WHERE date < ?", [cutoff])
        }
        return cutoff
    }

    /// Wipes every table, including settings (so the onboarding tour shows again).
    func resetAll() throws {
        try db.transaction {
            for table in ["reminder", "service_part", "service", "quick_log", "vehicle", "settings"] {
                try db.run("DELETE FROM \(table)")
            }
        }
    }

    func totalSpent(vehicleId: Int) throws -> Double {
        try db.first("""
            SELECT (SELECT COALESCE(SUM(total_cost), 0) FROM service WHERE vehicle_id = ?) +
                   (SELECT COALESCE(SUM(cost), 0) FROM quick_log WHERE vehicle_id = ?) AS s
            """, [vehicleId, vehicleId])?.double("s") ?? 0
    }
}
