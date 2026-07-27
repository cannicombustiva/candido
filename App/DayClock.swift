import Foundation
import CandidoCore
import Observation

/// The one Today the window derives against, replaced at every local midnight.
///
/// Staleness is derived, never stored, so nothing in the store changes when a
/// row goes Stale overnight — the answer simply becomes different, and without
/// this the window has no reason to ask again. Every view that reads staleness
/// reads `today` from one of these, so the styled date column and the Stale
/// filter can never disagree about what day it is: not by agreement, but
/// because there is one value and neither of them builds another.
///
/// A Today is an instant *and* a calendar, and both come from here. That is the
/// point: the boundary is scheduled off the same value the answers are derived
/// against, so the window can no longer wake at one day's midnight and re-derive
/// against another's.
///
/// This is a wake-up, not a poll: it sleeps until the next boundary, which
/// `DayBoundary` works out (in the owner's timezone, daylight saving included).
/// After each wake it re-reads the wall clock rather than counting days itself,
/// so a machine asleep across two midnights lands on the right day on waking.
/// It holds no arithmetic of its own — the day maths lives in `CandidoCore`.
@MainActor
@Observable
final class DayClock {
    private(set) var today: Today

    @ObservationIgnored private var advance: Task<Void, Never>?

    /// One Today in, one Today published, and the calendar is only ever the one
    /// inside it — there is no second copy for the two to drift apart.
    ///
    /// `autoupdatingCurrent` on purpose: this calendar outlives every boundary
    /// it schedules, and an owner who changes timezone should get their new
    /// midnight, not the one they flew out of. Because every Today the window
    /// sees is built here, that live calendar is also the one every answer is
    /// derived in. See `docs/adr/0002-the-owners-live-calendar.md`.
    init(today: Today = Today(instant: Date(), calendar: .autoupdatingCurrent)) {
        self.today = today
        advance = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                // The instant is read afresh rather than reused: the published
                // Today dates from the last wake, and the machine may have
                // slept through several boundaries since. The calendar comes
                // from that same Today, so the boundary is scheduled in the
                // calendar the answers are derived in.
                let scheduling = self.reading()
                do {
                    try await Task.sleep(
                        for: .seconds(DayBoundary.secondsUntilNext(after: scheduling)))
                } catch {
                    return  // Cancelled.
                }
                self.today = self.reading()
            }
        }
    }

    /// The wall clock now, in the calendar this clock is already keeping.
    private func reading() -> Today {
        Today(instant: Date(), calendar: today.calendar)
    }

    deinit {
        advance?.cancel()
    }
}
