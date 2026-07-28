import Foundation
import SwiftData
import Testing

@testable import CandidoCore

/// Deleting is the one thing in this app with no undo, so what these tests
/// watch is the blast radius: exactly the one Application goes, and a Company
/// left holding nothing goes with it — but never one that still has work.
@MainActor
struct ApplicationRemovalTests {
    @Test("Removing an Application takes that one and nothing else")
    func removesOnlyTheOneAskedFor() throws {
        let store = try TestStore()
        let going = try store.application(company: "Spotify", title: "iOS Engineer")
        try store.application(company: "Monzo", title: "Platform Engineer")

        going.remove(from: store.context)

        #expect(try store.applications().map(\.title) == ["Platform Engineer"])
    }

    @Test("The Company it was the last Application at does not linger")
    func clearsAwayACompanyLeftWithNothing() throws {
        let store = try TestStore()
        let going = try store.application(company: "Spotify", title: "iOS Engineer")
        try store.application(company: "Monzo", title: "Platform Engineer")

        going.remove(from: store.context)

        #expect(try store.context.fetch(FetchDescriptor<Company>()).map(\.name) == ["Monzo"])
    }

    @Test("A Company with other Applications is kept, and keeps them")
    func keepsACompanyThatStillHasWork() throws {
        let store = try TestStore()
        let going = try store.application(company: "Spotify", title: "iOS Engineer")
        try store.application(company: "Spotify", title: "Android Engineer")

        going.remove(from: store.context)

        #expect(try store.context.fetch(FetchDescriptor<Company>()).map(\.name) == ["Spotify"])
        #expect(try store.applications().map(\.title) == ["Android Engineer"])
    }

    @Test("Emptying a Company one Application at a time clears it away too")
    func clearsAwayACompanyEmptiedByTwoRemovals() throws {
        let store = try TestStore()
        let first = try store.application(company: "Spotify", title: "iOS Engineer")
        let second = try store.application(company: "Spotify", title: "Android Engineer")
        try store.application(company: "Monzo", title: "Platform Engineer")

        // Both go before anything is saved, which is what the owner does when
        // they delete two rows in a row.
        first.remove(from: store.context)
        second.remove(from: store.context)

        #expect(try store.context.fetch(FetchDescriptor<Company>()).map(\.name) == ["Monzo"])
        #expect(try store.applications().map(\.title) == ["Platform Engineer"])
    }

    @Test("Removing the last Application of all empties the store")
    func emptiesTheStoreWhenItWasTheOnlyOne() throws {
        let store = try TestStore()
        let going = try store.application()

        going.remove(from: store.context)

        #expect(try store.applications().isEmpty)
        #expect(try store.context.fetch(FetchDescriptor<Company>()).isEmpty)
    }

    @Test("A Company emptied by a removal is gone from the next backup")
    func doesNotWriteAnEmptiedCompanyToTheBackupFile() throws {
        let store = try TestStore()
        let going = try store.application(company: "Spotify", title: "iOS Engineer")
        try store.application(company: "Monzo", title: "Platform Engineer")

        going.remove(from: store.context)

        #expect(try BackupSnapshot(of: store.context).companies.map(\.name) == ["Monzo"])
    }
}
