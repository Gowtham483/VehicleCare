import Foundation

/// Which look the app uses: follow the iPhone, or always light, or always dark.
enum AppearanceChoice: String, CaseIterable {
    case system, light, dark
}

struct AppSettings: Equatable {
    var tyreIntervalDays = 14
    var petrolIntervalDays = 7
    var lubeIntervalDays = 30
    var serviceLeadDays = 3
    var notifyHour = 9 // 0-23, local time reminders fire at
    var currency = "₹"
    var retentionMonths = 24
    var themeId = "default"
    /// A per-device display preference, so it is not part of backups (like `onboardingDone`).
    var appearance = AppearanceChoice.system
    var onboardingDone = false

    static let defaults = AppSettings()

    /// Settings keys included in backups (onboarding state stays per device).
    static let backupKeys = ["tyreIntervalDays", "petrolIntervalDays", "lubeIntervalDays", "serviceLeadDays", "notifyHour", "currency", "retentionMonths", "themeId"]

    /// Invalid or missing stored values fall back to defaults.
    static func parse(_ raw: [String: String]) -> AppSettings {
        func number(_ key: String, _ min: Int, _ max: Int, _ fallback: Int) -> Int {
            if let text = raw[key], let n = Int(text), n >= min, n <= max { return n }
            return fallback
        }
        let d = AppSettings.defaults
        return AppSettings(
            tyreIntervalDays: number("tyreIntervalDays", 1, 365, d.tyreIntervalDays),
            petrolIntervalDays: number("petrolIntervalDays", 1, 365, d.petrolIntervalDays),
            lubeIntervalDays: number("lubeIntervalDays", 1, 365, d.lubeIntervalDays),
            serviceLeadDays: number("serviceLeadDays", 0, 60, d.serviceLeadDays),
            notifyHour: number("notifyHour", 0, 23, d.notifyHour),
            currency: raw["currency"] ?? d.currency,
            retentionMonths: number("retentionMonths", 1, 120, d.retentionMonths),
            themeId: raw["themeId"] ?? d.themeId,
            appearance: raw["appearance"].flatMap(AppearanceChoice.init(rawValue:)) ?? d.appearance,
            onboardingDone: raw["onboardingDone"] == "1"
        )
    }

    var asStored: [String: String] {
        [
            "tyreIntervalDays": String(tyreIntervalDays),
            "petrolIntervalDays": String(petrolIntervalDays),
            "lubeIntervalDays": String(lubeIntervalDays),
            "serviceLeadDays": String(serviceLeadDays),
            "notifyHour": String(notifyHour),
            "currency": currency,
            "retentionMonths": String(retentionMonths),
            "themeId": themeId,
            "appearance": appearance.rawValue,
            "onboardingDone": onboardingDone ? "1" : "0",
        ]
    }
}
