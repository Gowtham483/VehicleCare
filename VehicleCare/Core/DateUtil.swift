import Foundation

/// Dates are stored as local `YYYY-MM-DD` strings; reminder fire times as ISO-8601 datetimes.
enum DateUtil {
    private static func makeFormatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = format
        return f
    }

    private static let dayFormatter = makeFormatter("yyyy-MM-dd")
    private static let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let isoPlain = ISO8601DateFormatter()

    static var calendar: Calendar { Calendar(identifier: .gregorian) }

    static func string(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func today() -> String { string(Date()) }

    /// Strict parse: only real dates in `YYYY-MM-DD` form are accepted.
    static func parse(_ s: String) -> Date? {
        guard s.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
              let d = dayFormatter.date(from: s), string(d) == s else { return nil }
        return d
    }

    static func isValid(_ s: String) -> Bool { parse(s) != nil }

    static func addDays(_ d: Date, _ n: Int) -> Date { calendar.date(byAdding: .day, value: n, to: d) ?? d }
    static func addMonths(_ d: Date, _ n: Int) -> Date { calendar.date(byAdding: .month, value: n, to: d) ?? d }

    /// Display format in the locale's own order, e.g. "24 Oct 2026" or "Oct 24, 2026". Storage uses `string(_:)`.
    static func pretty(_ s: String) -> String { parse(s).map { L10n.dateFormatter(template: "dMMMyyyy").string(from: $0) } ?? s }
    static func monthTitle(_ yearMonth: String) -> String { parse("\(yearMonth)-01").map { L10n.dateFormatter(template: "MMMMyyyy").string(from: $0) } ?? yearMonth }

    /// `2026-10-24T10:00:00.000Z`, the same shape the Expo app writes.
    static func iso(_ date: Date) -> String { isoWithFraction.string(from: date) }
    static func parseISO(_ s: String) -> Date? { isoWithFraction.date(from: s) ?? isoPlain.date(from: s) }
}
