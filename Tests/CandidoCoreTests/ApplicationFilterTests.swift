import Foundation
import SwiftData
import Testing

@testable import CandidoCore

/// The four filters are derived from Status every time they are asked. None is
/// a stored flag, and an Application is never "put into" one.
///
/// Where a filter consults staleness, what is asserted here is that it consults
/// it at all — the exact day the boundary falls on belongs to `StalenessTests`
/// and is not restated.
@MainActor
@Suite struct ApplicationFilterTests {
    private let today = TestClock.today
    private let store: TestStore

    init() throws {
        store = try TestStore()
    }

    private func application(_ status: Status, silentFor days: Int) throws -> Application {
        try store.application(status: status, silentFor: days)
    }

    // MARK: - Terminal

    @Test(arguments: [Status.rejected, .withdrawn])
    func isTerminal(_ status: Status) {
        #expect(status.isTerminal)
    }

    /// An `offer` is not Terminal. The pursuit is still live; the next move is
    /// simply the owner's.
    @Test(arguments: [Status.applied, .screening, .interviewing, .offer])
    func isNotTerminal(_ status: Status) {
        #expect(!status.isTerminal)
    }

    // MARK: - Membership, per Status

    @Test(arguments: Status.allCases)
    func allContainsEveryStatus(_ status: Status) throws {
        let application = try application(status, silentFor: 3)

        #expect(ApplicationFilter.all.contains(application, asOf: today))
    }

    @Test(arguments: [Status.applied, .screening, .interviewing, .offer])
    func activeContainsEveryStatusThatIsNotTerminal(_ status: Status) throws {
        let application = try application(status, silentFor: 3)

        #expect(ApplicationFilter.active.contains(application, asOf: today))
        #expect(!ApplicationFilter.archived.contains(application, asOf: today))
    }

    @Test(arguments: [Status.rejected, .withdrawn])
    func archivedContainsExactlyTheTerminalStatuses(_ status: Status) throws {
        let application = try application(status, silentFor: 3)

        #expect(ApplicationFilter.archived.contains(application, asOf: today))
        #expect(!ApplicationFilter.active.contains(application, asOf: today))
    }

    // MARK: - Stale is always a subset of Active

    /// Stale reads staleness rather than a stored flag: a long silence puts a
    /// row in, a recent contact keeps it out, and either way it stays Active.
    ///
    /// The two silences straddle the `applied` threshold by one day rather than
    /// sitting safely either side of it, so a filter that asked staleness about
    /// the wrong day would fail here and not only in `StalenessTests`.
    @Test func staleFollowsTheSilenceAndStaysWithinActive() throws {
        let quiet = try application(.applied, silentFor: 22)
        let recentlyContacted = try application(.applied, silentFor: 21)

        #expect(ApplicationFilter.stale.contains(quiet, asOf: today))
        #expect(ApplicationFilter.active.contains(quiet, asOf: today))
        #expect(!ApplicationFilter.stale.contains(recentlyContacted, asOf: today))
        #expect(ApplicationFilter.active.contains(recentlyContacted, asOf: today))
    }

    /// A Terminal Application never awaits their reply, so however long the
    /// silence it can never appear under Stale.
    @Test(arguments: [Status.rejected, .withdrawn, .offer])
    func staleNeverContainsAStatusThatDoesNotAwaitTheirReply(_ status: Status) throws {
        let application = try application(status, silentFor: 500)

        #expect(!ApplicationFilter.stale.contains(application, asOf: today))
    }

    /// The invariant, stated directly: anything Stale is also Active, for every
    /// Status at every length of silence that matters.
    @Test func staleIsAlwaysASubsetOfActive() throws {
        for status in Status.allCases {
            for days in [0, 10, 11, 14, 15, 21, 22, 500] {
                let application = try application(status, silentFor: days)
                if ApplicationFilter.stale.contains(application, asOf: today) {
                    #expect(ApplicationFilter.active.contains(application, asOf: today))
                }
            }
        }
    }

    // MARK: - Nothing is stored

    /// There is no separate act of archiving: an Application moves between
    /// filters purely by having its Status changed.
    @Test func movesBetweenFiltersWhenTheStatusChanges() throws {
        let application = try application(.interviewing, silentFor: 3)
        #expect(ApplicationFilter.active.contains(application, asOf: today))
        #expect(!ApplicationFilter.archived.contains(application, asOf: today))

        application.status = .rejected

        #expect(!ApplicationFilter.active.contains(application, asOf: today))
        #expect(ApplicationFilter.archived.contains(application, asOf: today))
    }

    // MARK: - Narrowing a list

    @Test func narrowsAListToTheFilteredApplications() throws {
        try store.application(company: "Fresh", status: .applied, silentFor: 3)
        try store.application(company: "Quiet", status: .applied, silentFor: 30)
        try store.application(company: "Rejected", status: .rejected, silentFor: 30)
        let applications = try store.applications()

        func companies(_ filter: ApplicationFilter) -> [String] {
            filter.narrow(applications, asOf: today)
                .map(\.company.name)
                .sorted()
        }

        #expect(companies(.all) == ["Fresh", "Quiet", "Rejected"])
        #expect(companies(.active) == ["Fresh", "Quiet"])
        #expect(companies(.stale) == ["Quiet"])
        #expect(companies(.archived) == ["Rejected"])
    }
}
