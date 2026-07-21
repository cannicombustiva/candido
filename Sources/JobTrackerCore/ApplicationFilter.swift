import Foundation

/// The four ways the list of Applications is narrowed.
///
/// All of them are derived from Status on every read. None is a stored flag,
/// and an Application is never "put into" one — changing its Status is the
/// only thing that moves it.
public enum ApplicationFilter: String, CaseIterable, Identifiable, Sendable {
    /// Every Application, Active and Archived alike.
    case all

    /// Every Application whose Status is not Terminal. An `offer` is Active:
    /// the pursuit is still live, the next move is simply the owner's.
    case active

    /// The Stale subset of Active. Always a subset — a Terminal Application
    /// never awaits their reply, so it can never be Stale.
    case stale

    /// Every Application whose Status is Terminal.
    case archived

    public var id: Self { self }

    public var displayName: String {
        rawValue.capitalized
    }

    /// Whether this Application belongs in this filter right now.
    public func contains(
        _ application: Application,
        asOf now: Date = Date(),
        in calendar: Calendar = .current
    ) -> Bool {
        switch self {
        case .all: true
        case .active: !application.status.isTerminal
        // Stale is the Stale subset of Active, and says so structurally. It
        // would be true today from `isStale` alone — no Terminal Status has a
        // threshold — but that is a coincidence between two files, and this
        // filter must not depend on it.
        case .stale: !application.status.isTerminal && application.isStale(asOf: now, in: calendar)
        case .archived: application.status.isTerminal
        }
    }

    /// The Applications from this list that belong in this filter.
    public func narrow(
        _ applications: [Application],
        asOf now: Date = Date(),
        in calendar: Calendar = .current
    ) -> [Application] {
        applications.filter { contains($0, asOf: now, in: calendar) }
    }
}
