import Foundation
import SwiftData
import Testing

@testable import JobTrackerCore

/// The rules editing obeys. The inspector binds Status, notes and the
/// last-contact date straight to the model — those have no rules — so what is
/// tested here is the two fields that do: a title that must stay identifiable,
/// and a posting URL the owner types as text.
@MainActor
@Suite struct ApplicationEditingTests {
    private func applicationInAContext(
        title: String = "iOS Engineer",
        jobURL: URL? = nil
    ) throws -> Application {
        let container = try ModelContainer(
            for: Schema(JobTrackerCore.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = ModelContext(container)
        return try Application.create(
            companyNamed: "Spotify",
            title: title,
            jobURL: jobURL,
            in: context
        )
    }

    // MARK: - Renaming

    @Test func renamingReplacesTheTitle() throws {
        let application = try applicationInAContext()

        application.rename(to: "Senior iOS Engineer")

        #expect(application.title == "Senior iOS Engineer")
    }

    @Test func renamingTrimsSurroundingSpace() throws {
        let application = try applicationInAContext()

        application.rename(to: "  Staff Engineer\n")

        #expect(application.title == "Staff Engineer")
    }

    @Test(arguments: ["", "   ", "\t\n"])
    func aBlankTitleIsRefusedRatherThanStored(blank: String) throws {
        let application = try applicationInAContext(title: "iOS Engineer")

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
        let application = try applicationInAContext(jobURL: nil)

        #expect(application.jobURLText == "")
    }

    @Test func anApplicationWithAPostingURLEditsAsItsText() throws {
        let application = try applicationInAContext(
            jobURL: URL(string: "https://jobs.example.com/123"))

        #expect(application.jobURLText == "https://jobs.example.com/123")
    }

    @Test(arguments: ["", "   "])
    func clearingTheTextClearsThePostingURL(blank: String) throws {
        let application = try applicationInAContext(
            jobURL: URL(string: "https://jobs.example.com/123"))

        application.setJobURL(fromText: blank)

        #expect(application.jobURL == nil)
    }

    @Test func aFullyTypedURLIsKeptAsTyped() throws {
        let application = try applicationInAContext()

        application.setJobURL(fromText: "https://jobs.example.com/123?ref=x")

        #expect(application.jobURL?.absoluteString == "https://jobs.example.com/123?ref=x")
    }

    @Test func aPastedURLKeepsItsSchemeWhateverItIs() throws {
        let application = try applicationInAContext()

        application.setJobURL(fromText: "http://careers.example.com/9")

        #expect(application.jobURL?.absoluteString == "http://careers.example.com/9")
    }

    /// Postings are pasted from a browser bar as often as copied whole, and a
    /// bare host is unusable as a link without a scheme.
    @Test func aBareHostIsAssumedToBeHTTPS() throws {
        let application = try applicationInAContext()

        application.setJobURL(fromText: "careers.example.com/9")

        #expect(application.jobURL?.absoluteString == "https://careers.example.com/9")
    }

    @Test func surroundingSpaceIsTrimmedFromAPastedURL() throws {
        let application = try applicationInAContext()

        application.setJobURL(fromText: "  https://jobs.example.com/1  ")

        #expect(application.jobURL?.absoluteString == "https://jobs.example.com/1")
    }

    /// Text that is not a link at all leaves no URL behind rather than
    /// storing something the owner cannot open.
    @Test(arguments: ["not a url", "???"])
    func textThatIsNotALinkClearsThePostingURL(nonsense: String) throws {
        let application = try applicationInAContext(
            jobURL: URL(string: "https://jobs.example.com/123"))

        application.setJobURL(fromText: nonsense)

        #expect(application.jobURL == nil)
    }

    // MARK: - Editing and the rest of the domain

    /// Staleness derives from the last-contact date alone, so moving that date
    /// forward is the whole of "clearing staleness" — there is nothing else to
    /// reset.
    @Test func movingTheLastContactDateForwardClearsStaleness() throws {
        let application = try applicationInAContext()
        let now = Date()
        application.lastContactDate = now.addingTimeInterval(-60 * 24 * 60 * 60)
        #expect(application.isStale(asOf: now))

        application.lastContactDate = now

        #expect(application.isStale(asOf: now) == false)
    }

    /// Archiving is not a separate act: it is what a Terminal Status means.
    @Test func changingTheStatusToATerminalOneArchivesTheApplication() throws {
        let application = try applicationInAContext()
        #expect(ApplicationFilter.active.narrow([application]).count == 1)

        application.status = .rejected

        #expect(ApplicationFilter.archived.narrow([application]).count == 1)
        #expect(ApplicationFilter.active.narrow([application]).isEmpty)
    }
}
