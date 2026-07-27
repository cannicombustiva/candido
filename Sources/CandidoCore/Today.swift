import Foundation

/// The day the window is deriving against: one instant, and the calendar that
/// instant is read in.
///
/// Every answer this app gives is relative to today — days of silence, Stale,
/// which rows the Stale view holds, when the window next wakes. "Today" is not
/// an instant on its own: the same moment is two different days in two
/// timezones, so the instant is only half of the answer and the calendar is the
/// other half.
///
/// They travel as one value because they were previously two arguments that
/// happened to be passed together, each with its own default. A caller could
/// supply the instant and let the calendar quietly fall back to something else,
/// and the compiler accepted it — which is how the window came to schedule its
/// wake-up in the owner's live calendar while deriving its answers in another.
/// Nothing threw and nothing logged. One value removes the gap rather than
/// documenting it.
///
/// A plain value: no scheduling, no observation, no store access. Advancing to
/// the next day is the app target's job (`DayClock`), and it does it by reading
/// the wall clock again rather than by counting days.
public struct Today: Equatable, Sendable {
    /// The moment being derived against.
    public let instant: Date

    /// The calendar `instant` is read in — which day it falls on, and where the
    /// day's edges are. Deliberately not defaulted: the whole point of this
    /// type is that it cannot be left implicit.
    public let calendar: Calendar

    public init(instant: Date, calendar: Calendar) {
        self.instant = instant
        self.calendar = calendar
    }

    /// The first instant of this day. Not literally 00:00 — some timezones skip
    /// midnight on the day they change over.
    public var startOfDay: Date {
        calendar.startOfDay(for: instant)
    }

    /// The whole calendar days from `date` to this day, in this calendar.
    ///
    /// Calendar days, not elapsed time: the time of day never decides an
    /// answer. See `docs/adr/0001-calendar-days-for-staleness.md`.
    public func daysSince(_ date: Date) -> Int {
        calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: startOfDay).day
            ?? 0
    }
}
