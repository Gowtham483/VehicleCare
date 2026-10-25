import Foundation
import SQLite3

struct SQLiteError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

enum SQLValue {
    case int(Int64)
    case double(Double)
    case text(String)
    case null
}

/// Anything that can be bound to a `?` placeholder.
protocol SQLParam { var sqlValue: SQLValue { get } }
extension Int: SQLParam { var sqlValue: SQLValue { .int(Int64(self)) } }
extension Double: SQLParam { var sqlValue: SQLValue { .double(self) } }
extension String: SQLParam { var sqlValue: SQLValue { .text(self) } }
extension Bool: SQLParam { var sqlValue: SQLValue { .int(self ? 1 : 0) } }
extension Optional: SQLParam where Wrapped: SQLParam {
    var sqlValue: SQLValue { self?.sqlValue ?? .null }
}

struct Row {
    fileprivate(set) var values: [String: SQLValue] = [:]

    func int(_ key: String) -> Int {
        switch values[key] {
        case .int(let v): return Int(v)
        case .double(let v): return Int(v)
        default: return 0
        }
    }
    func double(_ key: String) -> Double {
        switch values[key] {
        case .double(let v): return v
        case .int(let v): return Double(v)
        default: return 0
        }
    }
    func string(_ key: String) -> String {
        if case .text(let v) = values[key] { return v }
        return ""
    }
    func optInt(_ key: String) -> Int? {
        if case .null? = values[key] { return nil }
        return values[key] == nil ? nil : int(key)
    }
    func optDouble(_ key: String) -> Double? {
        if case .null? = values[key] { return nil }
        return values[key] == nil ? nil : double(key)
    }
    func optString(_ key: String) -> String? {
        if case .text(let v)? = values[key] { return v }
        return nil
    }
}

struct RunResult {
    let changes: Int
    let lastInsertId: Int
}

/// Thin wrapper over the system SQLite3 C API. Not thread-safe; use from one actor.
final class Database {
    private var handle: OpaquePointer?
    private var transactionDepth = 0

    /// Pass `":memory:"` for tests.
    init(path: String) throws {
        guard sqlite3_open_v2(path, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "Could not open the database."
            sqlite3_close(handle)
            throw SQLiteError(message: message)
        }
        try exec("PRAGMA foreign_keys = ON;")
    }

    deinit { sqlite3_close(handle) }

    private var lastError: SQLiteError { SQLiteError(message: String(cString: sqlite3_errmsg(handle))) }

    /// Runs one or more statements without parameters.
    func exec(_ sql: String) throws {
        guard sqlite3_exec(handle, sql, nil, nil, nil) == SQLITE_OK else { throw lastError }
    }

    @discardableResult
    func run(_ sql: String, _ params: [SQLParam] = []) throws -> RunResult {
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_DONE else { throw lastError }
        return RunResult(changes: Int(sqlite3_changes(handle)), lastInsertId: Int(sqlite3_last_insert_rowid(handle)))
    }

    func all(_ sql: String, _ params: [SQLParam] = []) throws -> [Row] {
        let stmt = try prepare(sql, params)
        defer { sqlite3_finalize(stmt) }
        var rows: [Row] = []
        while true {
            let rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { throw lastError }
            var row = Row()
            for i in 0..<sqlite3_column_count(stmt) {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER: row.values[name] = .int(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT: row.values[name] = .double(sqlite3_column_double(stmt, i))
                case SQLITE_TEXT: row.values[name] = .text(String(cString: sqlite3_column_text(stmt, i)))
                default: row.values[name] = .null
                }
            }
            rows.append(row)
        }
        return rows
    }

    func first(_ sql: String, _ params: [SQLParam] = []) throws -> Row? { try all(sql, params).first }

    /// Commits if `body` returns, rolls back if it throws. Nested calls join the outer transaction.
    func transaction<T>(_ body: () throws -> T) throws -> T {
        if transactionDepth == 0 { try exec("BEGIN") }
        transactionDepth += 1
        defer { transactionDepth -= 1 }
        do {
            let result = try body()
            if transactionDepth == 1 { try exec("COMMIT") }
            return result
        } catch {
            if transactionDepth == 1 { try? exec("ROLLBACK") }
            throw error
        }
    }

    var userVersion: Int {
        get { (try? first("PRAGMA user_version"))??.int("user_version") ?? 0 }
        set { try? exec("PRAGMA user_version = \(newValue)") }
    }

    private func prepare(_ sql: String, _ params: [SQLParam]) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &stmt, nil) == SQLITE_OK else { throw lastError }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self) // SQLITE_TRANSIENT: SQLite copies the text
        for (i, param) in params.enumerated() {
            let index = Int32(i + 1)
            switch param.sqlValue {
            case .int(let v): sqlite3_bind_int64(stmt, index, v)
            case .double(let v): sqlite3_bind_double(stmt, index, v)
            case .text(let v): sqlite3_bind_text(stmt, index, v, -1, transient)
            case .null: sqlite3_bind_null(stmt, index)
            }
        }
        return stmt
    }
}

// MARK: - Migrations

enum Migrations {
    /// Bump when adding a step below. Stored in SQLite `PRAGMA user_version`.
    /// Version 1 is identical to the Expo (React Native) version of the app's schema.
    static let databaseVersion = 2

    /// Brings the database up to `target` (the latest by default; tests pass 1 to build an old database).
    static func migrate(_ db: Database, upTo target: Int = databaseVersion) throws {
        let current = db.userVersion
        guard current < target else { return }

        try db.transaction {
            if current < 1 && target >= 1 {
                try db.exec("""
                CREATE TABLE vehicle (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  type TEXT NOT NULL CHECK (type IN ('bike','car')),
                  name TEXT NOT NULL,
                  make TEXT NOT NULL DEFAULT '',
                  model TEXT NOT NULL DEFAULT '',
                  reg_no TEXT NOT NULL DEFAULT '',
                  created_at TEXT NOT NULL
                );
                CREATE TABLE service (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  vehicle_id INTEGER NOT NULL REFERENCES vehicle(id) ON DELETE CASCADE,
                  date TEXT NOT NULL,
                  title TEXT NOT NULL,
                  notes TEXT NOT NULL DEFAULT '',
                  labour_cost REAL NOT NULL DEFAULT 0,
                  total_cost REAL NOT NULL DEFAULT 0,
                  next_due_date TEXT,
                  created_at TEXT NOT NULL
                );
                CREATE INDEX idx_service_vehicle_date ON service(vehicle_id, date);
                CREATE TABLE service_part (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  service_id INTEGER NOT NULL REFERENCES service(id) ON DELETE CASCADE,
                  name TEXT NOT NULL,
                  price REAL NOT NULL DEFAULT 0,
                  qty REAL NOT NULL DEFAULT 1
                );
                CREATE TABLE quick_log (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  vehicle_id INTEGER NOT NULL REFERENCES vehicle(id) ON DELETE CASCADE,
                  kind TEXT NOT NULL CHECK (kind IN ('tyre_air','petrol')),
                  date TEXT NOT NULL,
                  cost REAL,
                  litres REAL,
                  note TEXT NOT NULL DEFAULT ''
                );
                CREATE INDEX idx_quick_vehicle_date ON quick_log(vehicle_id, date);
                CREATE TABLE reminder (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  vehicle_id INTEGER NOT NULL REFERENCES vehicle(id) ON DELETE CASCADE,
                  service_id INTEGER REFERENCES service(id) ON DELETE CASCADE,
                  kind TEXT NOT NULL CHECK (kind IN ('tyre_air','petrol','service')),
                  notification_id TEXT,
                  fire_at TEXT NOT NULL,
                  label TEXT NOT NULL,
                  active INTEGER NOT NULL DEFAULT 1
                );
                CREATE TABLE settings (
                  key TEXT PRIMARY KEY NOT NULL,
                  value TEXT NOT NULL
                );
                """)
            }

            // Version 2: the `kind` columns lose their CHECK so new quick-action kinds (chain lube, and any
            // later ones) need no further table rebuild. SQLite cannot alter a CHECK, so the tables are rebuilt.
            // Kinds are validated by the Swift enums instead.
            if current < 2 && target >= 2 {
                try db.exec("""
                CREATE TABLE quick_log_v2 (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  vehicle_id INTEGER NOT NULL REFERENCES vehicle(id) ON DELETE CASCADE,
                  kind TEXT NOT NULL,
                  date TEXT NOT NULL,
                  cost REAL,
                  litres REAL,
                  note TEXT NOT NULL DEFAULT ''
                );
                INSERT INTO quick_log_v2 (id, vehicle_id, kind, date, cost, litres, note)
                  SELECT id, vehicle_id, kind, date, cost, litres, note FROM quick_log;
                DROP TABLE quick_log;
                ALTER TABLE quick_log_v2 RENAME TO quick_log;
                CREATE INDEX idx_quick_vehicle_date ON quick_log(vehicle_id, date);

                CREATE TABLE reminder_v2 (
                  id INTEGER PRIMARY KEY AUTOINCREMENT,
                  vehicle_id INTEGER NOT NULL REFERENCES vehicle(id) ON DELETE CASCADE,
                  service_id INTEGER REFERENCES service(id) ON DELETE CASCADE,
                  kind TEXT NOT NULL,
                  notification_id TEXT,
                  fire_at TEXT NOT NULL,
                  label TEXT NOT NULL,
                  active INTEGER NOT NULL DEFAULT 1
                );
                INSERT INTO reminder_v2 (id, vehicle_id, service_id, kind, notification_id, fire_at, label, active)
                  SELECT id, vehicle_id, service_id, kind, notification_id, fire_at, label, active FROM reminder;
                DROP TABLE reminder;
                ALTER TABLE reminder_v2 RENAME TO reminder;
                """)
            }
        }
        db.userVersion = target
    }
}
