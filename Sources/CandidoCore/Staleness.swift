import Foundation

extension Application {
    /// Calendar days of silence, in the given timezone, between the last
    /// contact and now.
    ///
    /// Calendar days, not elapsed time: subtracting two `Date`s would make the
    /// arbitrary time of day decide outcomes, and put two applications
    /// contacted on the same afternoon on opposite sides of the boundary. See
    /// `docs/adr/0001-calendar-days-for-staleness.md`.
    public func daysOfSilence(asOf now: Date = Date(), in calendar: Calendar = .current) -> Int {
        let lastContactDay = calendar.startOfDay(for: lastContactDate)
        let today = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: lastContactDay, to: today).day ?? 0
    }

    /// Whether this Application awaits their reply and has been silent longer
    /// than its Status allows.
    ///
    /// Only a Status that awaits their reply can be Stale, and only that case
    /// carries a tolerance — so an `offer` and a Terminal Application fall out
    /// as never Stale by construction, not by a second check.
    ///
    /// Derived on every read and never stored: Stale is a property of the
    /// present moment, with no history and nothing mutating Status in the
    /// background.
    ///
    /// The boundary is strict. At exactly the threshold the Application is not
    /// yet Stale; one day later it is.
    public func isStale(asOf now: Date = Date(), in calendar: Calendar = .current) -> Bool {
        guard case .awaitingTheirReply(let tolerated) = status.standing else { return false }
        return daysOfSilence(asOf: now, in: calendar) > tolerated
    }
}
