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
    public static func next(after now: Date, in calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) else {
            // `.day` arithmetic on a valid date does not fail; falling forward
            // a fixed day is a last resort that keeps the timer in the future.
            return now.addingTimeInterval(24 * 3600)
        }
        return calendar.startOfDay(for: tomorrow)
    }

    /// Seconds from `now` until the day next turns over. Always positive.
    public static func secondsUntilNext(
        after now: Date, in calendar: Calendar = .current
    ) -> TimeInterval {
        next(after: now, in: calendar).timeIntervalSince(now)
    }
}
