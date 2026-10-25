import Foundation

/// Looks strings up in the app's own `.strings` files, so UI tests can find controls in any language
/// without duplicating the text.
enum UIStrings {
    private static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("VehicleCare/Resources")

    static func table(_ language: String) -> [String: String] {
        let url = resources.appendingPathComponent("\(language).lproj/Localizable.strings")
        return (NSDictionary(contentsOf: url) as? [String: String]) ?? [:]
    }

    /// The text for `key`, failing loudly if the key does not exist.
    static func t(_ key: String, _ language: String) -> String {
        guard let text = table(language)[key] else { fatalError("missing string key \(key) for \(language)") }
        return text
    }
}

/// Launch settings for a language. Tests always start with an empty throwaway database.
enum LaunchLanguage {
    case english, arabic, englishDoubleLength

    var code: String { self == .arabic ? "ar" : "en" }

    var arguments: [String] {
        switch self {
        case .english: return ["-uitest-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        case .arabic: return ["-uitest-reset", "-AppleLanguages", "(ar)", "-AppleLocale", "ar_AE"]
        // Foundation doubles every localized string: a cheap way to find truncation and clipped layouts.
        case .englishDoubleLength: return ["-uitest-reset", "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-NSDoubleLocalizedStrings", "YES"]
        }
    }
}
