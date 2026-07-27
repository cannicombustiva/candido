import Foundation
import SwiftData
import Testing

@testable import CandidoCore

/// The backup file is the only copy of the owner's data that leaves the store,
/// so what matters is that nothing is lost on the way out and nothing is
/// invented on the way back in.
@MainActor
struct BackupSnapshotTests {
    // MARK: Round trip

    @Test("A snapshot survives encoding and decoding unchanged")
    func roundTripsThroughJSON() throws {
        let store = try TestStore()
        try store.application(company: "Spotify", title: "iOS Engineer", silentFor: 3)
        try store.application(
            company: "Monzo",
            title: "Platform Engineer",
            status: .interviewing,
            silentFor: 30,
            appliedDaysAgo: 60,
            jobURL: URL(string: "https://monzo.com/careers/1")!
        )

        let exported = try BackupSnapshot(of: store.context)
        let decoded = try BackupSnapshot(json: exported.json())

        #expect(decoded == exported)
    }

    @Test("An empty store round-trips as an empty snapshot")
    func roundTripsAnEmptyStore() throws {
        let store = try TestStore()

        let exported = try BackupSnapshot(of: store.context)
        let decoded = try BackupSnapshot(json: exported.json())

        #expect(exported.companies.isEmpty)
        #expect(decoded == exported)
    }

    @Test("Every field of an Application comes back")
    func carriesEveryField() throws {
        let store = try TestStore()
        let url = URL(string: "https://spotify.com/jobs/42")!
        let original = try store.application(
            company: "Spotify",
            title: "iOS Engineer",
            status: .screening,
            silentFor: 5,
            appliedDaysAgo: 20,
            jobURL: url
        )
        original.notes = "Referred by Ada"

        let decoded = try BackupSnapshot(json: BackupSnapshot(of: store.context).json())
        let application = try #require(decoded.companies.first?.applications.first)

        #expect(decoded.companies.first?.name == "Spotify")
        #expect(application.id == original.id)
        #expect(application.title == "iOS Engineer")
        #expect(application.status == .screening)
        #expect(application.jobURL == url)
        #expect(application.notes == "Referred by Ada")
        #expect(application.appliedDate == original.appliedDate.wholeSecond)
        #expect(application.lastContactDate == original.lastContactDate.wholeSecond)
    }

    @Test("An Application with no posting URL comes back with none")
    func carriesAMissingURL() throws {
        let store = try TestStore()
        try store.application(jobURL: nil)

        let decoded = try BackupSnapshot(json: BackupSnapshot(of: store.context).json())

        #expect(decoded.companies.first?.applications.first?.jobURL == nil)
    }

    // MARK: Stability

    @Test("Reading the same store twice writes byte-identical files")
    func isStableAcrossReads() throws {
        let store = try TestStore()
        try store.application(company: "Zalando", title: "Backend Engineer")
        try store.application(company: "Ableton", title: "Audio Engineer")
        try store.application(company: "Ableton", title: "iOS Engineer")

        let first = try BackupSnapshot(of: store.context).json()
        let second = try BackupSnapshot(of: store.context).json()

        #expect(first == second)
    }

    @Test("The file names the spec version it was written against")
    func namesTheSpecVersion() throws {
        let store = try TestStore()

        let text = try #require(String(data: BackupSnapshot(of: store.context).json(), encoding: .utf8))

        #expect(text.contains("\"specVersion\" : \(CandidoCore.specVersion)"))
    }

    @Test("Dates are written as readable timestamps, not as numbers")
    func writesReadableDates() throws {
        let store = try TestStore()
        try store.application(silentFor: 1)

        let text = try #require(String(data: BackupSnapshot(of: store.context).json(), encoding: .utf8))

        #expect(text.contains("\"lastContactDate\" : \"2026-07-20T"))
    }

    // MARK: Grouping

    @Test("Every Application of a Company is written under that one Company")
    func groupsApplicationsUnderTheirCompany() throws {
        let store = try TestStore()
        try store.application(company: "Ableton", title: "Audio Engineer")
        try store.application(company: "ableton", title: "iOS Engineer")

        let snapshot = try BackupSnapshot(of: store.context)

        #expect(snapshot.companies.count == 1)
        #expect(snapshot.companies.first?.applications.count == 2)
    }

    // MARK: Failure

    @Test("Something that is not a backup file is refused, not half-read")
    func refusesJunk() throws {
        let junk = Data("not a backup".utf8)

        #expect(throws: (any Error).self) { try BackupSnapshot(json: junk) }
    }
}
