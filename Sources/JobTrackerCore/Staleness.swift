import Foundation

extension Status {
    /// Whether the next move belongs to the company rather than the owner.
    /// Only these Statuses can go Stale: an `offer` is the owner's to answer,
    /// and the two terminal Statuses are over.
    public var awaitsTheirReply: Bool {
        stalenessThreshold != nil
    }

    /// Days of silence this Status tolerates before the Application reads as
    /// Stale, or `nil` for the Statuses that never await a reply.
    ///
    /// The thresholds differ on purpose — silence after a final interview is
    /// louder than silence after applying.
    public var stalenessThreshold: Int? {
        switch self {
        case .applied: 21
        case .screening: 14
        case .interviewing: 10
        case .offer, .rejected, .withdrawn: nil
        }
    }
}

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
    /// Derived on every read and never stored: Stale is a property of the
    /// present moment, with no history and nothing mutating Status in the
    /// background.
    ///
    /// The boundary is strict. At exactly the threshold the Application is not
    /// yet Stale; one day later it is.
    public func isStale(asOf now: Date = Date(), in calendar: Calendar = .current) -> Bool {
        guard let threshold = status.stalenessThreshold else { return false }
        return daysOfSilence(asOf: now, in: calendar) > threshold
    }

    /// Staleness as of right now, in the owner's own timezone. What the table
    /// renders from.
    public var isStale: Bool {
        isStale()
    }
}
