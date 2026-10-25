import Foundation

enum Schedule {
    /// `days` from `now`, at `hour:00` local time.
    static func fireAt(now: Date, days: Int, hour: Int) -> Date {
        let day = DateUtil.addDays(now, days)
        return DateUtil.calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    /// When to remind about a service due on `dueDate` (local midnight): `leadDays` before if that is
    /// still ahead, else on the due date, else nil (both already past).
    static func serviceFireAt(now: Date, dueDate: Date, leadDays: Int, hour: Int) -> Date? {
        let cal = DateUtil.calendar
        let leadDay = DateUtil.addDays(dueDate, -leadDays)
        if let lead = cal.date(bySettingHour: hour, minute: 0, second: 0, of: leadDay), lead > now { return lead }
        if let due = cal.date(bySettingHour: hour, minute: 0, second: 0, of: dueDate), due > now { return due }
        return nil
    }
}

enum Retention {
    /// Records dated before this day are purged.
    static func cutoff(now: Date, months: Int) -> String { DateUtil.string(DateUtil.addMonths(now, -months)) }
}
