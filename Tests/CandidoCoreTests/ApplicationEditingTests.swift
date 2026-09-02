import Foundation
import SwiftData
import Testing

@testable import CandidoCore

/// The rules editing obeys. Notes and the last-contact date are bound straight
/// to the model and have no rules of their own; the three that do are tested
/// here — a title that must stay identifiable, a posting URL the owner types as
/// text, and a Status change, which is Contact and moves the last-contact date
/// with it.
@MainActor
@Suite struct ApplicationEditingTests {
    private let today = TestClock.today
    private let store: TestStore

    init() throws {
        store = try TestStore()
    }

    private func application(
        title: String = "iOS Engineer",
        jobURL: URL? = nil
    ) throws -> Application {
        try store.application(company: "Spotify", title: title, jobURL: jobURL)
    }

    // MARK: - Renaming

    @Test func renamingReplacesTheTitle() throws {
        let application = try application()

        application.rename(to: "Senior iOS Engineer")

        #expect(application.title == "Senior iOS Engineer")
    }

    @Test func renamingTrimsSurroundingSpace() throws {
        let application = try application()

        application.rename(to: "  Staff Engineer\n")

        #expect(application.title == "Staff Engineer")
    }

    @Test(arguments: ["", "   ", "\t\n"])
    func aBlankTitleIsRefusedRatherThanStored(blank: String) throws {
        let application = try application(title: "iOS Engineer")

        application.rename(to: blank)

        #expect(application.title == "iOS Engineer")
    }

    @Test(arguments: ["", "   "])
    func aBlankTitleIsNotAKeepableRename(blank: String) {
        #expect(Application.canRename(to: blank) == false)
    }

    @Test func aTitleWithSomethingInItIsAKeepableRename() {
        #expect(Application.canRename(to: "Staff Engineer"))
    }

    // MARK: - The posting URL as text

    @Test func anApplicationWithNoPostingURLEditsAsEmptyText() throws {
        let application = try application(jobURL: nil)

        #expect(application.jobURLText == "")
    }

    @Test func anApplicationWithAPostingURLEditsAsItsText() throws {
        let application = try application(
            jobURL: URL(string: "https://jobs.example.com/123"))

        #expect(application.jobURLText == "https://jobs.example.com/123")
    }

    @Test(arguments: ["", "   "])
    func clearingTheTextClearsThePostingURL(blank: String) throws {
        let application = try application(
            jobURL: URL(string: "https://jobs.example.com/123"))

        application.setJobURL(fromText: blank)

        #expect(application.jobURL == nil)
    }

    @Test func aFullyTypedURLIsKeptAsTyped() throws {
        let application = try application()

        application.setJobURL(fromText: "https://jobs.example.com/123?ref=x")

        #expect(application.jobURL?.absoluteString == "https://jobs.example.com/123?ref=x")
    }

    @Test func aPastedURLKeepsItsSchemeWhateverItIs() throws {
        let application = try application()

        application.setJobURL(fromText: "http://careers.example.com/9")

        #expect(application.jobURL?.absoluteString == "http://careers.example.com/9")
    }

    /// Postings are pasted from a browser bar as often as copied whole, and a
    /// bare host is unusable as a link without a scheme.
    @Test func aBareHostIsAssumedToBeHTTPS() throws {
        let application = try application()

        application.setJobURL(fromText: "careers.example.com/9")

        #expect(application.jobURL?.absoluteString == "https://careers.example.com/9")
    }

    @Test func surroundingSpaceIsTrimmedFromAPastedURL() throws {
        let application = try application()

        application.setJobURL(fromText: "  https://jobs.example.com/1  ")

        #expect(application.jobURL?.absoluteString == "https://jobs.example.com/1")
    }

    /// A host with no dot in it is still a host — an intranet posting is a
    /// posting.
    @Test func aHostWithNoDotIsStillALink() throws {
        let application = try application()

        application.setJobURL(fromText: "https://careers/9")

        #expect(application.jobURL?.absoluteString == "https://careers/9")
    }

    /// Text that is not a link at all leaves no URL behind rather than
    /// storing something the owner cannot open.
    @Test(arguments: ["not a url", "???"])
    func textThatIsNotALinkClearsThePostingURL(nonsense: String) throws {
        let application = try application(
            jobURL: URL(string: "https://jobs.example.com/123"))

        application.setJobURL(fromText: nonsense)

        #expect(application.jobURL == nil)
    }

    // MARK: - Editing and the rest of the domain

    /// Staleness derives from the last-contact date alone, so moving that date
    /// forward is the whole of "clearing staleness" — there is nothing else to
    /// reset.
    @Test func movingTheLastContactDateForwardClearsStaleness() throws {
        let application = try store.application(silentFor: 60)
        #expect(application.isStale(asOf: today))

        application.lastContactDate = today.instant

        #expect(!application.isStale(asOf: today))
    }

    /// Archiving is not a separate act: it is what a Terminal Status means.
    ///
    /// Assigned directly rather than changed, because what is under test is
    /// what the Status *means*, not what changing it does.
    @Test func changingTheStatusToATerminalOneArchivesTheApplication() throws {
        let application = try application()
        #expect(ApplicationFilter.active.narrow([application], asOf: today).count == 1)

        application.status = .rejected

        #expect(ApplicationFilter.archived.narrow([application], asOf: today).count == 1)
        #expect(ApplicationFilter.active.narrow([application], asOf: today).isEmpty)
    }

    // MARK: - A Status change is Contact

    /// Nearly every Status change happens because they wrote — a rejection, an
    /// invitation to screen, an offer — so the change carries the date of that
    /// letter with it.
    ///
    /// Origin and destination are paired rather than crossed: what is under
    /// test is that a real transition stamps, and a pair whose two halves are
    /// the same Status is not a transition at all.
    @Test(arguments: [
        (Status.screening, Status.applied),
        (.applied, .screening),
        (.screening, .interviewing),
        (.interviewing, .offer),
        (.interviewing, .rejected),
    ])
    func changingTheStatusStampsTheLastContactDate(
        origin: Status, destination: Status
    ) throws {
        let application = try store.application(status: origin, silentFor: 30)

        application.changeStatus(to: destination, asOf: today)

        #expect(application.status == destination)
        #expect(application.lastContactDate == today.startOfDay)
    }

    /// Withdrawing is the owner's act alone. Nobody wrote to anybody, so
    /// nothing about the last contact changed.
    @Test func withdrawingLeavesTheLastContactDateAlone() throws {
        let application = try store.application(status: .interviewing, silentFor: 30)
        let before = application.lastContactDate

        application.changeStatus(to: .withdrawn, asOf: today)

        #expect(application.status == .withdrawn)
        #expect(application.lastContactDate == before)
    }

    /// The carve-out is on arriving at `withdrawn`, not on the Status. Leaving
    /// it means something brought the pursuit back, and that something came
    /// from them — a row revived after months must not read Stale the instant
    /// it is revived.
    @Test func leavingWithdrawnStampsLikeAnyOtherChange() throws {
        let application = try store.application(status: .withdrawn, silentFor: 180)

        application.changeStatus(to: .interviewing, asOf: today)

        #expect(application.lastContactDate == today.startOfDay)
        #expect(!application.isStale(asOf: today))
    }

    /// A `Picker` can fire on re-selection. Re-affirming a Status is not a
    /// change, and must not become a covert way to reset the clock — the date
    /// field is the honest way to say contact happened.
    @Test(arguments: Status.allCases)
    func reSelectingTheSameStatusChangesNothing(status: Status) throws {
        let application = try store.application(status: status, silentFor: 30)
        let before = application.lastContactDate

        application.changeStatus(to: status, asOf: today)

        #expect(application.status == status)
        #expect(application.lastContactDate == before)
    }

    /// No rule reads a time of day — staleness counts calendar days
    /// (`docs/adr/0001-calendar-days-for-staleness.md`) — so the stamp stores
    /// the day and not the moment the picker happened to move.
    @Test func theStampCarriesNoTimeOfDay() throws {
        let application = try store.application(status: .applied, silentFor: 5)

        application.changeStatus(to: .screening, asOf: today)

        let components = today.calendar.dateComponents(
            [.hour, .minute, .second], from: application.lastContactDate)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
        #expect(today.daysSince(application.lastContactDate) == 0)
    }

    /// Assigning the Status is not the act of changing it. Import restores a
    /// Status while restoring a record, and a restore that stamped would age
    /// every row in a backup to today — leaving the owner with a backup that
    /// is not one.
    @Test func assigningTheStatusDirectlyDoesNotStamp() throws {
        let application = try store.application(status: .applied, silentFor: 30)
        let before = application.lastContactDate

        application.status = .rejected

        #expect(application.lastContactDate == before)
    }

    /// The point of the rule, stated in the vocabulary the owner sees: a Stale
    /// row stops being Stale as the Status moves, so the Stale view empties as
    /// it is worked through rather than needing a second edit per row.
    @Test func aStaleApplicationIsNoLongerStaleAfterAStatusChange() throws {
        let application = try store.application(status: .applied, silentFor: 60)
        #expect(application.isStale(asOf: today))

        application.changeStatus(to: .screening, asOf: today)

        #expect(!application.isStale(asOf: today))
    }

    /// `appliedDate` is set once and never changes, stamp or no stamp.
    @Test func changingTheStatusLeavesTheAppliedDateAlone() throws {
        let application = try store.application(
            status: .applied, silentFor: 10, appliedDaysAgo: 60)
        let applied = application.appliedDate

        application.changeStatus(to: .interviewing, asOf: today)

        #expect(application.appliedDate == applied)
    }
}
