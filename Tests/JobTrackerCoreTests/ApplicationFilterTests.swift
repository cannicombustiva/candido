import Foundation
import SwiftData
import Testing

@testable import JobTrackerCore

/// The four filters are derived from Status every time they are asked. None is
/// a stored flag, and an Application is never "put into" one.
@MainActor
@Suite struct ApplicationFilterTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London")!
        return calendar
    }()

    private var now: Date {
        calendar.date(from: DateComponents(year: 2026, month: 7, day: 21, hour: 12))!
    }

    private func application(_ status: Status, silentFor days: Int) throws -> Application {
        let container = try ModelContainer(
            for: Schema(JobTrackerCore.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        let lastContact = calendar.date(byAdding: .day, value: -days, to: now)!
        return try Application.create(
            companyNamed: "Spotify",
            title: "iOS Engineer",
            status: status,
            appliedDate: lastContact,
            lastContactDate: lastContact,
            in: context
        )
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

        #expect(ApplicationFilter.all.contains(application, asOf: now, in: calendar))
    }

    @Test(arguments: [Status.applied, .screening, .interviewing, .offer])
    func activeContainsEveryStatusThatIsNotTerminal(_ status: Status) throws {
        let application = try application(status, silentFor: 3)

        #expect(ApplicationFilter.active.contains(application, asOf: now, in: calendar))
        #expect(!ApplicationFilter.archived.contains(application, asOf: now, in: calendar))
    }

    @Test(arguments: [Status.rejected, .withdrawn])
    func archivedContainsExactlyTheTerminalStatuses(_ status: Status) throws {
        let application = try application(status, silentFor: 3)

        #expect(ApplicationFilter.archived.contains(application, asOf: now, in: calendar))
        #expect(!ApplicationFilter.active.contains(application, asOf: now, in: calendar))
    }

    // MARK: - Stale is always a subset of Active

    @Test func staleContainsAnApplicationThatHasGoneQuiet() throws {
        let application = try application(.applied, silentFor: 22)

        #expect(ApplicationFilter.stale.contains(application, asOf: now, in: calendar))
        #expect(ApplicationFilter.active.contains(application, asOf: now, in: calendar))
    }

    @Test func staleExcludesAnApplicationStillWithinItsThreshold() throws {
        let application = try application(.applied, silentFor: 21)

        #expect(!ApplicationFilter.stale.contains(application, asOf: now, in: calendar))
        #expect(ApplicationFilter.active.contains(application, asOf: now, in: calendar))
    }

    /// A Terminal Application never awaits their reply, so however long the
    /// silence it can never appear under Stale.
    @Test(arguments: [Status.rejected, .withdrawn, .offer])
    func staleNeverContainsAStatusThatDoesNotAwaitTheirReply(_ status: Status) throws {
        let application = try application(status, silentFor: 500)

        #expect(!ApplicationFilter.stale.contains(application, asOf: now, in: calendar))
    }

    /// The invariant, stated directly: anything Stale is also Active, for every
    /// Status at every length of silence that matters.
    @Test func staleIsAlwaysASubsetOfActive() throws {
        for status in Status.allCases {
            for days in [0, 10, 11, 14, 15, 21, 22, 500] {
                let application = try application(status, silentFor: days)
                if ApplicationFilter.stale.contains(application, asOf: now, in: calendar) {
                    #expect(ApplicationFilter.active.contains(application, asOf: now, in: calendar))
                }
            }
        }
    }

    // MARK: - Nothing is stored

    /// There is no separate act of archiving: an Application moves between
    /// filters purely by having its Status changed.
    @Test func movesBetweenFiltersWhenTheStatusChanges() throws {
        let application = try application(.interviewing, silentFor: 3)
        #expect(ApplicationFilter.active.contains(application, asOf: now, in: calendar))
        #expect(!ApplicationFilter.archived.contains(application, asOf: now, in: calendar))

        application.status = .rejected

        #expect(!ApplicationFilter.active.contains(application, asOf: now, in: calendar))
        #expect(ApplicationFilter.archived.contains(application, asOf: now, in: calendar))
    }

    // MARK: - Narrowing a list

    @Test func narrowsAListToTheFilteredApplications() throws {
        let container = try ModelContainer(
            for: Schema(JobTrackerCore.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        func add(_ company: String, _ status: Status, silentFor days: Int) throws {
            let lastContact = calendar.date(byAdding: .day, value: -days, to: now)!
            try Application.create(
                companyNamed: company, title: "Engineer", status: status,
                appliedDate: lastContact, lastContactDate: lastContact, in: context)
        }
        try add("Fresh", .applied, silentFor: 3)
        try add("Quiet", .applied, silentFor: 30)
        try add("Rejected", .rejected, silentFor: 30)
        let applications = try context.fetch(FetchDescriptor<Application>())

        func companies(_ filter: ApplicationFilter) -> [String] {
            filter.narrow(applications, asOf: now, in: calendar)
                .map(\.company.name)
                .sorted()
        }

        #expect(companies(.all) == ["Fresh", "Quiet", "Rejected"])
        #expect(companies(.active) == ["Fresh", "Quiet"])
        #expect(companies(.stale) == ["Quiet"])
        #expect(companies(.archived) == ["Rejected"])
    }
}
