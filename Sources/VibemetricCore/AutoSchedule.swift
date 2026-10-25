import Foundation

/// When the automatic score should run: a time of day on chosen days of the week. Pure date logic, so the app can
/// call it every minute and after wake without caring about timers, sleep, or time-zone changes.
public struct AutoSchedule: Sendable, Equatable {
    public var enabled: Bool
    /// Minutes after midnight, local time. 14 * 60 = 2:00pm.
    public var minuteOfDay: Int
    /// The days it runs, as a bit per `Calendar` weekday: bit 0 is Sunday (weekday 1), bit 6 is Saturday.
    public var days: Int

    public static let defaultMinuteOfDay = 14 * 60
    public static let everyDay = 0b111_1111
    public static let weekdays = 0b011_1110
    public static let weekends = 0b100_0001

    public init(enabled: Bool = true, minuteOfDay: Int = AutoSchedule.defaultMinuteOfDay, days: Int = AutoSchedule.everyDay) {
        self.enabled = enabled
        self.minuteOfDay = min(max(minuteOfDay, 0), 24 * 60 - 1)
        let days = days & Self.everyDay
        // No day chosen would never run; treat it as every day.
        self.days = days == 0 ? Self.everyDay : days
    }

    /// `weekday` as `Calendar` numbers it: 1 is Sunday, 7 is Saturday.
    public func runs(onWeekday weekday: Int) -> Bool {
        (1...7).contains(weekday) && days & (1 << (weekday - 1)) != 0
    }

    public func runs(on day: Date, calendar: Calendar = .current) -> Bool {
        runs(onWeekday: calendar.component(.weekday, from: day))
    }

    /// The scheduled time on `day`'s date (whether or not it runs that day).
    public func time(on day: Date, calendar: Calendar = .current) -> Date {
        let start = calendar.startOfDay(for: day)
        return calendar.date(byAdding: .minute, value: minuteOfDay, to: start) ?? start
    }

    /// The next scheduled time after `now`, or nil when disabled.
    public func next(after now: Date, calendar: Calendar = .current) -> Date? {
        guard enabled else { return nil }
        for offset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let slot = time(on: day, calendar: calendar)
            if slot > now, runs(on: day, calendar: calendar) { return slot }
        }
        return nil
    }

    /// True when today is a chosen day, today's slot has passed, and it hasn't been handled yet. A slot is handled
    /// when a score was produced after it (manual or automatic) or an automatic attempt already ran for it.
    /// Missed slots from earlier days are not replayed; only today's counts (catch-up after sleep).
    public func isDue(now: Date, lastResultAt: Date?, lastAttemptAt: Date?, calendar: Calendar = .current) -> Bool {
        guard enabled, runs(on: now, calendar: calendar) else { return false }
        let slot = time(on: now, calendar: calendar)
        guard now >= slot else { return false }
        if let lastResultAt, lastResultAt >= slot { return false }
        if let lastAttemptAt, lastAttemptAt >= slot { return false }
        return true
    }

    /// The chosen days in plain words: "Every day", "Weekdays", "Weekends", "Every Monday and Wednesday",
    /// or "Every Mon, Wed and Fri", in the calendar's week order.
    public func daysDescription(calendar: Calendar = .current) -> String {
        switch days {
        case Self.everyDay: return "Every day"
        case Self.weekdays: return "Weekdays"
        case Self.weekends: return "Weekends"
        default: break
        }
        let chosen = Self.weekOrder(calendar: calendar).filter { runs(onWeekday: $0) }
        let names = chosen.count <= 2 ? calendar.standaloneWeekdaySymbols : calendar.shortStandaloneWeekdaySymbols
        let words = chosen.map { names[$0 - 1] }
        guard let last = words.last else { return "Every day" }
        let list = words.count == 1 ? last : words.dropLast().joined(separator: ", ") + " and " + last
        return "Every " + list
    }

    /// Weekday numbers starting from the calendar's first day of the week (Sunday in the US, Monday in much of Europe).
    public static func weekOrder(calendar: Calendar = .current) -> [Int] {
        (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
    }
}
