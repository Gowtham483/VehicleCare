import Foundation

/// The backup file format. It is identical to the one written by the Expo version of the app,
/// so a backup exported from either app can be imported into the other.
/// See docs/backup-format.md.
struct BackupReminder: Codable, Equatable {
    var id: Int
    var vehicleId: Int
    var serviceId: Int?
    var kind: ReminderKind
    var fireAt: String
    var label: String
    var active: Int

    enum CodingKeys: String, CodingKey {
        case id, kind, label, active
        case vehicleId = "vehicle_id"
        case serviceId = "service_id"
        case fireAt = "fire_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(vehicleId, forKey: .vehicleId)
        try c.encode(serviceId, forKey: .serviceId)
        try c.encode(kind, forKey: .kind)
        try c.encode(fireAt, forKey: .fireAt)
        try c.encode(label, forKey: .label)
        try c.encode(active, forKey: .active)
    }
}

struct BackupFile: Codable {
    static let appId = "vehicle-care"
    /// The newest layout this app understands. Bump when the file layout changes, and add a step to `Backup.migrate`.
    static let currentSchemaVersion = 2
    /// The original layout. A backup is written as this unless it needs something newer (see `Backup.build`),
    /// so files without newer data stay importable by the Expo app and older builds.
    static let baseSchemaVersion = 1

    var app: String
    var schemaVersion: Int
    var exportedAt: String
    var vehicles: [Vehicle]
    var services: [Service]
    var serviceParts: [ServicePart]
    var quickLogs: [QuickLog]
    var reminders: [BackupReminder]
    var settings: [String: String]
}

struct BackupSummary: Equatable {
    var vehicles = 0
    var services = 0
    var quickLogs = 0
    var reminders = 0
}

enum ImportMode { case merge, replace }

struct BackupError: Error, LocalizedError, Equatable {
    let message: String
    var errorDescription: String? { message }
}

enum Backup {
    static func summary(_ b: BackupFile) -> BackupSummary {
        BackupSummary(vehicles: b.vehicles.count, services: b.services.count, quickLogs: b.quickLogs.count, reminders: b.reminders.count)
    }

    // MARK: Validation

    private static let tables = ["vehicles", "services", "serviceParts", "quickLogs", "reminders"]

    /// Brings an older backup up to the current layout. Add a step per schema bump.
    static func migrate(_ raw: [String: Any]) -> [String: Any] {
        let b = raw
        // if (b["schemaVersion"] as? Int) == 1 { ...transform to v2...; b["schemaVersion"] = 2 }
        return b
    }

    /// Parses and validates before anything is written to the database.
    static func validate(_ data: Data) -> Result<BackupFile, BackupError> {
        guard let json = try? JSONSerialization.jsonObject(with: data) else {
            return .failure(BackupError(message: L10n.BackupError.notJSON))
        }
        guard let obj = json as? [String: Any], obj["app"] as? String == BackupFile.appId else {
            return .failure(BackupError(message: L10n.BackupError.notBackup(AppInfo.name)))
        }
        guard let version = obj["schemaVersion"] as? Int, version >= 1 else {
            return .failure(BackupError(message: L10n.BackupError.noVersion))
        }
        if version > BackupFile.currentSchemaVersion {
            return .failure(BackupError(message: L10n.BackupError.newer))
        }

        let migrated = migrate(obj)
        for table in tables where !(migrated[table] is [Any]) {
            return .failure(BackupError(message: L10n.BackupError.missing(table)))
        }
        guard let settings = migrated["settings"] as? [String: Any], settings.values.allSatisfy({ $0 is String }) else {
            return .failure(BackupError(message: L10n.BackupError.invalidIn("settings")))
        }

        let backup: BackupFile
        do {
            let normalised = try JSONSerialization.data(withJSONObject: migrated)
            backup = try JSONDecoder().decode(BackupFile.self, from: normalised)
        } catch let error as DecodingError {
            return .failure(BackupError(message: describe(error)))
        } catch {
            return .failure(BackupError(message: L10n.BackupError.unreadable))
        }

        if let problem = semanticProblem(backup) { return .failure(BackupError(message: problem)) }
        return .success(backup)
    }

    /// Turns a Codable failure into "Invalid "field" in "table" (entry N)."
    private static func describe(_ error: DecodingError) -> String {
        let context: DecodingError.Context
        switch error {
        case .keyNotFound(let key, let c):
            if c.codingPath.isEmpty { return L10n.BackupError.missing(key.stringValue) }
            context = DecodingError.Context(codingPath: c.codingPath + [key], debugDescription: c.debugDescription)
        case .typeMismatch(_, let c), .valueNotFound(_, let c), .dataCorrupted(let c):
            context = c
        @unknown default:
            return L10n.BackupError.unreadable
        }
        let path = context.codingPath
        if path.count >= 3, let index = path[1].intValue {
            return L10n.BackupError.invalidField(path[2].stringValue, path[0].stringValue, index + 1)
        }
        return L10n.BackupError.invalidIn(path.first?.stringValue ?? "data")
    }

    private static func semanticProblem(_ b: BackupFile) -> String? {
        for (i, s) in b.services.enumerated() {
            if !DateUtil.isValid(s.date) { return L10n.BackupError.invalidField("date", "services", i + 1) }
            if let due = s.nextDueDate, !DateUtil.isValid(due) { return L10n.BackupError.invalidField("next_due_date", "services", i + 1) }
        }
        for (i, q) in b.quickLogs.enumerated() where !DateUtil.isValid(q.date) {
            return L10n.BackupError.invalidField("date", "quickLogs", i + 1)
        }
        for (i, r) in b.reminders.enumerated() where DateUtil.parseISO(r.fireAt) == nil {
            return L10n.BackupError.invalidField("fire_at", "reminders", i + 1)
        }
        let vehicleIds = Set(b.vehicles.map(\.id))
        let serviceIds = Set(b.services.map(\.id))
        let dangling = b.services.contains { !vehicleIds.contains($0.vehicleId) }
            || b.quickLogs.contains { !vehicleIds.contains($0.vehicleId) }
            || b.reminders.contains { !vehicleIds.contains($0.vehicleId) || ($0.serviceId.map { !serviceIds.contains($0) } ?? false) }
            || b.serviceParts.contains { !serviceIds.contains($0.serviceId) }
        return dangling ? L10n.BackupError.dangling : nil
    }

    // MARK: Export

    static func build(from store: DataStore, now: Date = Date()) throws -> BackupFile {
        let reminders = try store.db.all("SELECT * FROM reminder WHERE active = 1 ORDER BY id").map { r in
            BackupReminder(id: r.int("id"), vehicleId: r.int("vehicle_id"), serviceId: r.optInt("service_id"),
                           kind: ReminderKind(rawValue: r.string("kind")) ?? .service, fireAt: r.string("fire_at"),
                           label: r.string("label"), active: 1) // notification ids are device-specific, so not exported
        }
        let parts = try store.db.all("SELECT * FROM service_part ORDER BY id").map { r in
            ServicePart(id: r.int("id"), serviceId: r.int("service_id"), name: r.string("name"), price: r.double("price"), qty: r.double("qty"))
        }
        var settings: [String: String] = [:]
        for r in try store.db.all("SELECT key, value FROM settings") where AppSettings.backupKeys.contains(r.string("key")) {
            settings[r.string("key")] = r.string("value")
        }
        // chain-lube entries are the only data an older app cannot read, so only then is the file marked version 2
        let quickLogs = try store.quickLogs().sorted { $0.id < $1.id }
        let usesLube = quickLogs.contains { $0.kind == .lube } || reminders.contains { $0.kind == .lube }
        let byId: (Vehicle, Vehicle) -> Bool = { $0.id < $1.id }
        return BackupFile(
            app: BackupFile.appId,
            schemaVersion: usesLube ? 2 : BackupFile.baseSchemaVersion,
            exportedAt: DateUtil.iso(now),
            vehicles: try store.vehicles().sorted(by: byId),
            services: try store.services().sorted { $0.id < $1.id },
            serviceParts: parts,
            quickLogs: quickLogs,
            reminders: reminders,
            settings: settings
        )
    }

    static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(backup)
    }

    // MARK: Import

    private static func keyPart<T>(_ value: T?) -> String { value.map { "\($0)" } ?? "nil" }
    private static func norm(_ s: String) -> String { s.trimmingCharacters(in: .whitespaces).lowercased() }
    private static func vehicleKey(_ type: VehicleType, _ name: String, _ regNo: String) -> String { "\(type.rawValue)|\(norm(name))|\(norm(regNo))" }
    private static func serviceKey(_ vehicleId: Int, _ date: String, _ title: String, _ total: Double) -> String { "\(vehicleId)|\(date)|\(norm(title))|\(total)" }
    private static func quickKey(_ vehicleId: Int, _ kind: QuickKind, _ date: String, _ cost: Double?, _ litres: Double?) -> String {
        "\(vehicleId)|\(kind.rawValue)|\(date)|\(keyPart(cost))|\(keyPart(litres))"
    }
    private static func reminderKey(_ vehicleId: Int, _ kind: ReminderKind, _ serviceId: Int?, _ fireAt: String) -> String {
        "\(vehicleId)|\(kind.rawValue)|\(keyPart(serviceId))|\(fireAt)"
    }

    /// Writes a validated backup in one transaction (a failure leaves existing data untouched).
    /// Ids are regenerated and relations remapped. Callers must cancel scheduled notifications before a
    /// `.replace`, then run `ReminderService.sync` and the retention purge afterwards.
    @discardableResult
    static func importBackup(_ backup: BackupFile, into store: DataStore, mode: ImportMode) throws -> BackupSummary {
        try store.db.transaction { try apply(backup, to: store, mode: mode) }
    }

    private static func apply(_ backup: BackupFile, to store: DataStore, mode: ImportMode) throws -> BackupSummary {
        let db = store.db
        var added = BackupSummary()
        if mode == .replace {
            for table in ["reminder", "service_part", "service", "quick_log", "vehicle"] { try db.run("DELETE FROM \(table)") }
            for key in AppSettings.backupKeys { try db.run("DELETE FROM settings WHERE key = ?", [key]) }
            for (key, value) in backup.settings where AppSettings.backupKeys.contains(key) {
                try store.saveSetting(key: key, value: value)
            }
        }

        // vehicles
        var vehicleMap: [Int: Int] = [:]
        var existingVehicles: [String: Int] = [:]
        for v in try store.vehicles() { existingVehicles[vehicleKey(v.type, v.name, v.regNo)] = v.id }
        for v in backup.vehicles {
            let key = vehicleKey(v.type, v.name, v.regNo)
            if let existing = existingVehicles[key] {
                vehicleMap[v.id] = existing
                continue
            }
            let id = try db.run("INSERT INTO vehicle (type, name, make, model, reg_no, created_at) VALUES (?, ?, ?, ?, ?, ?)",
                                [v.type.rawValue, v.name, v.make, v.model, v.regNo, v.createdAt]).lastInsertId
            vehicleMap[v.id] = id
            existingVehicles[key] = id
            added.vehicles += 1
        }
        func mappedVehicle(_ old: Int) throws -> Int {
            guard let id = vehicleMap[old] else { throw BackupError(message: L10n.BackupError.dangling) }
            return id
        }

        // services (+ parts for newly added services only)
        var serviceMap: [Int: Int] = [:]
        var existingServices: [String: Int] = [:]
        for s in try store.services() { existingServices[serviceKey(s.vehicleId, s.date, s.title, s.totalCost)] = s.id }
        var newServiceIds = Set<Int>()
        for s in backup.services {
            let vehicleId = try mappedVehicle(s.vehicleId)
            let key = serviceKey(vehicleId, s.date, s.title, s.totalCost)
            if let existing = existingServices[key] {
                serviceMap[s.id] = existing
                continue
            }
            let id = try db.run("""
                INSERT INTO service (vehicle_id, date, title, notes, labour_cost, total_cost, next_due_date, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """, [vehicleId, s.date, s.title, s.notes, s.labourCost, s.totalCost, s.nextDueDate, s.createdAt]).lastInsertId
            serviceMap[s.id] = id
            existingServices[key] = id
            newServiceIds.insert(s.id)
            added.services += 1
        }
        for p in backup.serviceParts where newServiceIds.contains(p.serviceId) {
            guard let serviceId = serviceMap[p.serviceId] else { continue }
            try db.run("INSERT INTO service_part (service_id, name, price, qty) VALUES (?, ?, ?, ?)", [serviceId, p.name, p.price, p.qty])
        }

        // quick logs
        var existingQuick = Set<String>()
        for q in try store.quickLogs() { existingQuick.insert(quickKey(q.vehicleId, q.kind, q.date, q.cost, q.litres)) }
        for q in backup.quickLogs {
            let vehicleId = try mappedVehicle(q.vehicleId)
            let key = quickKey(vehicleId, q.kind, q.date, q.cost, q.litres)
            if existingQuick.contains(key) { continue }
            try db.run("INSERT INTO quick_log (vehicle_id, kind, date, cost, litres, note) VALUES (?, ?, ?, ?, ?, ?)",
                       [vehicleId, q.kind.rawValue, q.date, q.cost, q.litres, q.note])
            existingQuick.insert(key)
            added.quickLogs += 1
        }

        // reminders (notification ids are filled in by ReminderService.sync)
        var existingReminders = Set<String>()
        for r in try store.activeReminders() { existingReminders.insert(reminderKey(r.vehicleId, r.kind, r.serviceId, r.fireAt)) }
        for r in backup.reminders where r.active != 0 {
            let vehicleId = try mappedVehicle(r.vehicleId)
            let serviceId = try r.serviceId.map { old -> Int in
                guard let id = serviceMap[old] else { throw BackupError(message: L10n.BackupError.dangling) }
                return id
            }
            let key = reminderKey(vehicleId, r.kind, serviceId, r.fireAt)
            if existingReminders.contains(key) { continue }
            try store.insertReminder(vehicleId: vehicleId, serviceId: serviceId, kind: r.kind, notificationId: nil, fireAt: r.fireAt, label: r.label)
            existingReminders.insert(key)
            added.reminders += 1
        }
        return added
    }

    // MARK: CSV (read-only export for spreadsheets)

    private static func cell(_ value: String) -> String {
        value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) ? "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\"" : value
    }

    private static func number(_ d: Double?) -> String {
        guard let d else { return "" }
        return d == d.rounded() && abs(d) < 1e15 ? String(Int(d)) : String(d)
    }

    static func csv(_ columns: [String], _ rows: [[String]]) -> String {
        ([columns] + rows).map { $0.map(cell).joined(separator: ",") }.joined(separator: "\n")
    }

    static func csvFiles(_ b: BackupFile) -> [(name: String, content: String)] {
        let names = Dictionary(uniqueKeysWithValues: b.vehicles.map { ($0.id, $0.name) })
        return [
            ("vehicles.csv", csv(["id", "type", "name", "make", "model", "reg_no"],
                                 b.vehicles.map { [String($0.id), $0.type.rawValue, $0.name, $0.make, $0.model, $0.regNo] })),
            ("services.csv", csv(["id", "vehicle", "date", "title", "notes", "labour_cost", "total_cost", "next_due_date"],
                                 b.services.map { [String($0.id), names[$0.vehicleId] ?? "", $0.date, $0.title, $0.notes, number($0.labourCost), number($0.totalCost), $0.nextDueDate ?? ""] })),
            ("service-parts.csv", csv(["service_id", "name", "price", "qty"],
                                      b.serviceParts.map { [String($0.serviceId), $0.name, number($0.price), number($0.qty)] })),
            ("quick-logs.csv", csv(["vehicle", "kind", "date", "cost", "litres", "note"],
                                   b.quickLogs.map { [names[$0.vehicleId] ?? "", $0.kind.rawValue, $0.date, number($0.cost), number($0.litres), $0.note] })),
        ]
    }
}
