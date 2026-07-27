import Foundation

/// When the calendar day next turns over.
///
/// Staleness is derived from calendar days (see
/// `docs/adr/0001-calendar-days-for-staleness.md`), so every answer the app
/// shows can only change at local midnight. A window left open overnight has
/// to be woken at that instant and no other: this is the arithmetic that says
/// when, so that the app target holds a timer and no decisions.
///
/// Nothing here writes anything. Crossing a boundary re-derives the same
/// values against a later `now`; no Status is mutated and no history is kept.
public enum DayBoundary {
    /// The first instant of the day after the one `now` falls in.
    ///
    /// The day's *first instant*, not literally 00:00 — some timezones skip
    /// midnight on the day they change over, and days are 23 or 25 hours long
    /// either side of a daylight-saving transition. Adding 24 hours would drift
    /// off the boundary twice a year and miss it entirely in São Paulo.
    ///
    /// Always strictly later than `now`, including when `now` is itself a
    /// boundary — a timer scheduled on the present instant would spin.
    /// Scheduling reads its calendar from the same value the answers are
    /// derived against, so the window cannot wake at one day's boundary and
    /// then re-derive against another's.
    public static func next(after today: Today) -> Date {
        let calendar = today.calendar
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today.startOfDay) else {
            // `.day` arithmetic on a valid date does not fail; falling forward
            // a fixed day is a last resort that keeps the timer in the future.
            return today.instant.addingTimeInterval(24 * 3600)
        }
        return calendar.startOfDay(for: tomorrow)
    }

    /// Seconds until the day next turns over. Always positive.
    public static func secondsUntilNext(after today: Today) -> TimeInterval {
        next(after: today).timeIntervalSince(today.instant)
    }
}
