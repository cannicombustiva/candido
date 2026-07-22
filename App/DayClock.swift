import Foundation
import JobTrackerCore
import Observation

/// The instant the window derives staleness against, advanced at every local
/// midnight.
///
/// Staleness is derived, never stored, so nothing in the store changes when a
/// row goes Stale overnight — the answer simply becomes different, and without
/// this the window has no reason to ask again. Every view that reads staleness
/// reads `now` from one of these, so the styled date column and the Stale
/// filter can never disagree about what day it is.
///
/// This is a wake-up, not a poll: it sleeps until the next boundary, which
/// `DayBoundary` works out (in the owner's timezone, daylight saving included).
/// After each wake it re-reads the wall clock rather than counting days itself,
/// so a machine asleep across two midnights lands on the right day on waking.
@MainActor
@Observable
final class DayClock {
    private(set) var now: Date

    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private var advance: Task<Void, Never>?

    /// `autoupdatingCurrent` on purpose: this calendar outlives every boundary
    /// it schedules, and an owner who changes timezone should get their new
    /// midnight, not the one they flew out of.
    init(calendar: Calendar = .autoupdatingCurrent, now: Date = Date()) {
        self.calendar = calendar
        self.now = now
        advance = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let untilBoundary = DayBoundary.secondsUntilNext(after: Date(), in: self.calendar)
                do {
                    try await Task.sleep(for: .seconds(untilBoundary))
                } catch {
                    return  // Cancelled.
                }
                self.now = Date()
            }
        }
    }

    deinit {
        advance?.cancel()
    }
}
