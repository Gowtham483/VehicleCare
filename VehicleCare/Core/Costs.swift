import Foundation

enum Costs {
    static func round2(_ n: Double) -> Double { (n * 100).rounded() / 100 }

    static func partsTotal(_ parts: [PartInput]) -> Double {
        round2(parts.reduce(0) { sum, p in
            (p.price.isFinite && p.qty.isFinite) ? sum + p.price * p.qty : sum
        })
    }

    /// Service total = labour + sum(part price * qty).
    static func serviceTotal(labour: Double, parts: [PartInput]) -> Double {
        round2((labour.isFinite ? labour : 0) + partsTotal(parts))
    }

    /// Turns Arabic-Indic (٠-٩) and Persian (۰-۹) digits and Arabic separators into plain ASCII, so a number
    /// typed on any keyboard is read correctly. Without this, "١٢" would silently parse as 0.
    static func normalizeDigits(_ text: String) -> String {
        var out = String.UnicodeScalarView()
        for scalar in text.unicodeScalars {
            switch scalar.value {
            case 0x0660...0x0669: out.append(UnicodeScalar(scalar.value - 0x0660 + 0x30)!)
            case 0x06F0...0x06F9: out.append(UnicodeScalar(scalar.value - 0x06F0 + 0x30)!)
            case 0x066B: out.append(".")        // Arabic decimal separator ٫
            case 0x066C, 0x200E, 0x200F: break  // Arabic thousands separator ٬ and direction marks
            default: out.append(scalar)
            }
        }
        return String(out)
    }

    /// Parses a user-typed number. Empty or invalid input becomes `fallback`.
    static func parseAmount(_ text: String, fallback: Double = 0) -> Double {
        let trimmed = normalizeDigits(text).trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let n = Double(trimmed.replacingOccurrences(of: ",", with: ".")), n.isFinite, n >= 0 else {
            return fallback
        }
        return n
    }

    /// Parses a whole number typed by the user (same digit handling as `parseAmount`).
    static func parseInt(_ text: String) -> Int? {
        Int(normalizeDigits(text).trimmingCharacters(in: .whitespaces))
    }

    /// A number for display, in the app's language (Western digits), with the currency symbol in front.
    static func format(_ currency: String, _ n: Double) -> String {
        let f = NumberFormatter()
        f.locale = L10n.locale
        f.numberStyle = .decimal
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return L10n.ltr(currency + (f.string(from: NSNumber(value: n)) ?? String(n)))
    }

    /// A number for editing in a text field: no grouping, "." as the decimal separator, no trailing zeros.
    static func editableText(_ n: Double) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.numberStyle = .decimal
        f.usesGroupingSeparator = false
        f.minimumFractionDigits = 0
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
}
