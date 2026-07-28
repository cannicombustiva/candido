import Foundation
import SwiftData
import Testing

@testable import CandidoCore

/// Import is a merge, never a restore: it updates what it recognises, inserts
/// what it does not, and leaves everything else alone. The failure that matters
/// is losing work, so every test here is ultimately asking whether something in
/// the store could disappear.
@MainActor
struct BackupImportTests {
    // MARK: Inserting

    @Test("An Application the store has never seen is inserted")
    func insertsAnUnknownApplication() throws {
        let store = try TestStore()
        let file = BackupSnapshot(companies: [
            .init(name: "Monzo", applications: [.stub(title: "Platform Engineer")])
        ])

        let summary = try file.merge(into: store.context)

        #expect(summary == .init(inserted: 1, updated: 0))
        #expect(try store.applications().map(\.title) == ["Platform Engineer"])
    }

    @Test("An inserted Application arrives with every field the file gave it")
    func insertsEveryField() throws {
        let store = try TestStore()
        let record = BackupSnapshot.ApplicationRecord(
            id: UUID(),
            title: "iOS Engineer",
            status: .interviewing,
            appliedDate: TestClock.date(daysAgo: 60),
            lastContactDate: TestClock.date(daysAgo: 3),
            jobURL: URL(string: "https://spotify.com/jobs/42"),
            notes: "Referred by Ada"
        )

        try BackupSnapshot(companies: [.init(name: "Spotify", applications: [record])])
            .merge(into: store.context)

        let application = try #require(try store.applications().first)
        #expect(application.id == record.id)
        #expect(application.company.name == "Spotify")
        #expect(application.title == "iOS Engineer")
        #expect(application.status == .interviewing)
        #expect(application.appliedDate == record.appliedDate)
        #expect(application.lastContactDate == record.lastContactDate)
        #expect(application.jobURL == record.jobURL)
        #expect(application.notes == "Referred by Ada")
    }

    // MARK: Updating

    @Test("An Application whose id is already in the store is updated in place")
    func updatesAKnownApplicationInPlace() throws {
        let store = try TestStore()
        let existing = try store.application(company: "Spotify", title: "iOS Engineer")
        let file = BackupSnapshot(companies: [
            .init(
                name: "Spotify",
                applications: [
                    .stub(id: existing.id, title: "Senior iOS Engineer", status: .offer)
                ]
            )
        ])

        let summary = try file.merge(into: store.context)

        #expect(summary == .init(inserted: 0, updated: 1))
        #expect(try store.applications().count == 1)
        #expect(existing.title == "Senior iOS Engineer")
        #expect(existing.status == .offer)
    }

    @Test("An Application that changed company in the file is reattached, not duplicated")
    func movesAKnownApplicationToItsCompanyInTheFile() throws {
        let store = try TestStore()
        let existing = try store.application(company: "Spotify", title: "iOS Engineer")
        let file = BackupSnapshot(companies: [
            .init(name: "Monzo", applications: [.stub(id: existing.id, title: "iOS Engineer")])
        ])

        try file.merge(into: store.context)

        #expect(try store.applications().count == 1)
        #expect(existing.company.name == "Monzo")
    }

    // MARK: Never deleting

    @Test("An Application the file does not mention is left alone")
    func leavesUnmentionedApplicationsAlone() throws {
        let store = try TestStore()
        try store.application(company: "Spotify", title: "iOS Engineer")
        let file = BackupSnapshot(companies: [
            .init(name: "Monzo", applications: [.stub(title: "Platform Engineer")])
        ])

        try file.merge(into: store.context)

        #expect(try store.applications().map(\.title).sorted() == ["Platform Engineer", "iOS Engineer"].sorted())
    }

    @Test("An empty file deletes nothing")
    func anEmptyFileDeletesNothing() throws {
        let store = try TestStore()
        try store.application(company: "Spotify", title: "iOS Engineer")

        let summary = try BackupSnapshot(companies: []).merge(into: store.context)

        #expect(summary == .init(inserted: 0, updated: 0))
        #expect(try store.applications().count == 1)
    }

    // MARK: Companies

    @Test("A company named differently only by case or whitespace joins the existing one")
    func foldsCompanyNamesOntoTheExistingCompany() throws {
        let store = try TestStore()
        try store.application(company: "Spotify", title: "iOS Engineer")
        let file = BackupSnapshot(companies: [
            .init(name: "  spotify ", applications: [.stub(title: "Android Engineer")])
        ])

        try file.merge(into: store.context)

        let companies = try store.context.fetch(FetchDescriptor<Company>())
        #expect(companies.map(\.name) == ["Spotify"])
        #expect(companies.first?.applications.count == 2)
    }

    // MARK: Idempotence

    @Test("Importing the same file twice leaves the store identical after the second import")
    func isIdempotent() throws {
        let store = try TestStore()
        try store.application(company: "Spotify", title: "iOS Engineer")
        let file = BackupSnapshot(companies: [
            .init(name: "monzo", applications: [.stub(title: "Platform Engineer")]),
            .init(name: "Spotify", applications: [.stub(title: "Android Engineer")]),
        ])

        try file.merge(into: store.context)
        let afterFirst = try BackupSnapshot(of: store.context)

        let summary = try file.merge(into: store.context)

        #expect(summary == .init(inserted: 0, updated: 2))
        #expect(try BackupSnapshot(of: store.context) == afterFirst)
    }

    // MARK: Round trip

    @Test("Export then import yields an identical dataset")
    func roundTripsThroughAFile() throws {
        let source = try TestStore()
        try source.application(company: "Spotify", title: "iOS Engineer", silentFor: 3)
        try source.application(
            company: "Monzo",
            title: "Platform Engineer",
            status: .interviewing,
            silentFor: 30,
            appliedDaysAgo: 60,
            jobURL: URL(string: "https://monzo.com/careers/1")!
        )
        let exported = try BackupSnapshot(of: source.context)

        let destination = try TestStore()
        try BackupSnapshot(json: exported.json()).merge(into: destination.context)

        #expect(try BackupSnapshot(of: destination.context) == exported)
    }

    // MARK: Refusing a file rather than half-importing it

    @Test("A file naming an Application with no title is refused whole")
    func refusesABlankTitleWithoutImportingAnything() throws {
        let store = try TestStore()
        let file = BackupSnapshot(companies: [
            .init(
                name: "Monzo",
                applications: [.stub(title: "Platform Engineer"), .stub(title: "  ")]
            )
        ])

        #expect(throws: ApplicationInputError.blankTitle) { try file.merge(into: store.context) }
        #expect(try store.applications().isEmpty)
    }

    @Test("A file naming a company with no name is refused whole")
    func refusesABlankCompanyNameWithoutImportingAnything() throws {
        let store = try TestStore()
        let file = BackupSnapshot(companies: [
            .init(name: "Monzo", applications: [.stub(title: "Platform Engineer")]),
            .init(name: " ", applications: [.stub(title: "iOS Engineer")]),
        ])

        #expect(throws: ApplicationInputError.blankCompanyName) {
            try file.merge(into: store.context)
        }
        #expect(try store.applications().isEmpty)
    }
}

extension BackupSnapshot.ApplicationRecord {
    /// A record as a file would carry it. Dates come from `TestClock` so a
    /// merged row means the same thing to staleness as a typed one.
    static func stub(
        id: UUID = UUID(),
        title: String = "iOS Engineer",
        status: Status = .applied,
        silentFor days: Int = 0
    ) -> Self {
        .init(
            id: id,
            title: title,
            status: status,
            appliedDate: TestClock.date(daysAgo: days),
            lastContactDate: TestClock.date(daysAgo: days),
            jobURL: nil,
            notes: ""
        )
    }
}
