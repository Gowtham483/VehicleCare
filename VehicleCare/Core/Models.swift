import Foundation

enum VehicleType: String, Codable, CaseIterable, Identifiable {
    case bike, car
    var id: String { rawValue }
    var label: String { self == .bike ? L10n.Common.bike : L10n.Common.car }
}

enum QuickKind: String, Codable {
    case tyreAir = "tyre_air"
    case petrol
    /// Clean and lube the chain (bikes only). Added in schema/backup version 2.
    case lube
}

enum ReminderKind: String, Codable {
    case tyreAir = "tyre_air"
    case petrol
    case service
    case lube
}

struct Vehicle: Codable, Identifiable, Equatable {
    var id: Int
    var type: VehicleType
    var name: String
    var make: String
    var model: String
    var regNo: String
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, name, make, model
        case regNo = "reg_no"
        case createdAt = "created_at"
    }
}

struct Service: Codable, Identifiable, Equatable {
    var id: Int
    var vehicleId: Int
    var date: String
    var title: String
    var notes: String
    var labourCost: Double
    var totalCost: Double
    var nextDueDate: String?
    var createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, date, title, notes
        case vehicleId = "vehicle_id"
        case labourCost = "labour_cost"
        case totalCost = "total_cost"
        case nextDueDate = "next_due_date"
        case createdAt = "created_at"
    }

    // Optionals are written as explicit nulls so the file matches the Expo app's backup format.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(vehicleId, forKey: .vehicleId)
        try c.encode(date, forKey: .date)
        try c.encode(title, forKey: .title)
        try c.encode(notes, forKey: .notes)
        try c.encode(labourCost, forKey: .labourCost)
        try c.encode(totalCost, forKey: .totalCost)
        try c.encode(nextDueDate, forKey: .nextDueDate)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

struct ServicePart: Codable, Identifiable, Equatable {
    var id: Int
    var serviceId: Int
    var name: String
    var price: Double
    var qty: Double

    enum CodingKeys: String, CodingKey {
        case id, name, price, qty
        case serviceId = "service_id"
    }
}

struct QuickLog: Codable, Identifiable, Equatable {
    var id: Int
    var vehicleId: Int
    var kind: QuickKind
    var date: String
    var cost: Double?
    var litres: Double?
    var note: String

    enum CodingKeys: String, CodingKey {
        case id, kind, date, cost, litres, note
        case vehicleId = "vehicle_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(vehicleId, forKey: .vehicleId)
        try c.encode(kind, forKey: .kind)
        try c.encode(date, forKey: .date)
        try c.encode(cost, forKey: .cost)
        try c.encode(litres, forKey: .litres)
        try c.encode(note, forKey: .note)
    }
}

struct Reminder: Identifiable, Equatable {
    var id: Int
    var vehicleId: Int
    var serviceId: Int?
    var kind: ReminderKind
    var notificationId: String?
    var fireAt: String
    var label: String
    var active: Bool
}

// MARK: - Inputs

struct VehicleInput {
    var type: VehicleType
    var name: String
    var make = ""
    var model = ""
    var regNo = ""
}

struct PartInput: Equatable {
    var name: String
    var price: Double
    var qty: Double
}

struct ServiceInput {
    var vehicleId: Int
    var date: String
    var title: String
    var notes: String
    var labourCost: Double
    var parts: [PartInput]
    var nextDueDate: String?
}

struct QuickLogInput {
    var vehicleId: Int
    var kind: QuickKind
    var date: String
    var cost: Double?
    var litres: Double?
    var note: String
}
