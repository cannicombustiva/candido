import Foundation
import SwiftData
import Testing

@testable import CandidoCore

/// Renaming a Company corrects a name that would otherwise be permanent. The
/// rules are in `SPEC.md` under "Renaming corrects a name", and the choice to
/// merge rather than refuse is `docs/adr/0005-a-rename-onto-a-taken-name-merges.md`.
@MainActor
@Suite struct CompanyRenameTests {
    private let store: TestStore
    private let context: ModelContext

    init() throws {
        store = try TestStore()
        context = store.context
    }

    /// Fixing casing and fixing letters are one act. A rename that moved only
    /// the display name would leave the Company answering to the typo forever,
    /// which is the thing being fixed.
    @Test func movesBothTheDisplayedNameAndTheIdentityItIsFoundBy() throws {
        let company = try store.application(company: "Spotfy").company

        try company.planRename(to: "Spotifyy", in: context).apply(in: context)

        #expect(company.name == "Spotifyy")
        #expect(company.applications.count == 1)
        #expect(try Company.findOrCreate(named: "Spotifyy", in: context) === company)
        #expect(try Company.findOrCreate(named: "Spotfy", in: context) !== company)
    }

    /// The case that motivates the feature: you notice the typo because you
    /// typed the name correctly the second time, so the good spelling is
    /// already in the store. A merge moves work and destroys none of it.
    @Test func movesEveryApplicationAcrossWhenTheNameIsAlreadyTaken() throws {
        try store.application(company: "Spotfy", title: "iOS Engineer")
        try store.application(company: "Spotfy", title: "Backend Engineer")
        try store.application(company: "Spotfy", title: "Platform Engineer")
        let destination = try store.application(company: "Spotify", title: "Designer").company
        let source = try Company.findOrCreate(named: "Spotfy", in: context)

        try source.planRename(to: "Spotify", in: context).apply(in: context)
        try context.save()

        let companies = try context.fetch(FetchDescriptor<Company>())
        #expect(companies.count == 1)
        #expect(companies.first === destination)
        #expect(destination.name == "Spotify")
        #expect(destination.applications.count == 4)
        #expect(try context.fetchCount(FetchDescriptor<Application>()) == 4)
    }

    /// A Company always collides with itself on the folded name. Reading that
    /// as a merge would clear the Company away and take its work with it, so
    /// the collision is "a Company that is not this one".
    @Test func rewritesTheDisplayNameWhenTheNewNameFoldsToItsOwnIdentity() throws {
        let application = try store.application(company: "Spotify")
        let company = application.company

        try company.planRename(to: " spotify ", in: context).apply(in: context)
        try context.save()

        #expect(company.name == "spotify")
        #expect(try context.fetchCount(FetchDescriptor<Company>()) == 1)
        #expect(company.applications.count == 1)
        #expect(application.isDeleted == false)
    }

    /// The collision is decided on the folded name, so shouting the
    /// destination's name still finds it — and the name that survives is the
    /// destination's own, not the one just typed.
    @Test func mergesOnTheFoldedNameAndKeepsTheDestinationsSpelling() throws {
        try store.application(company: "Spotfy", title: "iOS Engineer")
        let destination = try store.application(company: "Spotify", title: "Designer").company
        let source = try Company.findOrCreate(named: "Spotfy", in: context)

        try source.planRename(to: "SPOTIFY", in: context).apply(in: context)
        try context.save()

        #expect(destination.name == "Spotify")
        #expect(destination.applications.count == 2)
        #expect(try context.fetchCount(FetchDescriptor<Company>()) == 1)
        #expect(try context.fetchCount(FetchDescriptor<Application>()) == 2)
    }

    /// The add sheet's rule and the import's rule, obeyed here too: a name of
    /// only spaces folds to "" and identifies nothing. Refused before anything
    /// is touched, because there is no undo to get the old name back from.
    @Test(arguments: ["", "   ", "\t\n"])
    func refusesABlankNameAndChangesNothing(_ blank: String) throws {
        let company = try store.application(company: "Spotify").company

        #expect(throws: ApplicationInputError.blankCompanyName) {
            _ = try company.planRename(to: blank, in: context)
        }

        #expect(company.name == "Spotify")
        #expect(company.applications.count == 1)
        #expect(try context.fetchCount(FetchDescriptor<Application>()) == 1)
    }

    /// D43's lesson, in the merge path: what counts is Applications still
    /// standing, not Applications still listed. A row deleted in the same
    /// unsaved batch is still in the Company's list, and must be neither
    /// counted in the dialog nor carried across to the destination.
    @Test func ignoresAnAlreadyDeletedApplicationWhenItMerges() throws {
        let going = try store.application(company: "Spotfy", title: "iOS Engineer")
        try store.application(company: "Spotfy", title: "Backend Engineer")
        let destination = try store.application(company: "Spotify", title: "Designer").company
        let source = try Company.findOrCreate(named: "Spotfy", in: context)
        context.delete(going)

        let plan = try source.planRename(to: "Spotify", in: context)
        #expect(plan.affectedCount == 1)

        plan.apply(in: context)
        try context.save()

        #expect(destination.applications.map(\.title).sorted() == ["Backend Engineer", "Designer"])
        #expect(try context.fetchCount(FetchDescriptor<Company>()) == 1)
    }

    /// Documented and expected, not a defect. Import merges and never deletes,
    /// so a file written before the merge files its Applications under a name
    /// that no longer exists and brings that Company back. Teaching import
    /// otherwise needs Company identities in the file format.
    @Test func bringsTheOldCompanyBackWhenAPreMergeBackupIsImported() throws {
        try store.application(company: "Spotfy", title: "iOS Engineer")
        try store.application(company: "Spotify", title: "Designer")
        let before = try BackupSnapshot(of: context)

        let source = try Company.findOrCreate(named: "Spotfy", in: context)
        try source.planRename(to: "Spotify", in: context).apply(in: context)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<Company>()) == 1)

        _ = try before.merge(into: context)
        try context.save()

        let names = try context.fetch(FetchDescriptor<Company>()).map(\.name).sorted()
        #expect(names == ["Spotfy", "Spotify"])
        #expect(try context.fetchCount(FetchDescriptor<Application>()) == 2)
    }

    /// The panel the dialog opens from is one Application's, and the name is
    /// not — so the blast radius is said out loud before anything moves.
    @Test func namesHowManyApplicationsAPlainRenameAffects() throws {
        try store.application(company: "Spotfy", title: "iOS Engineer")
        try store.application(company: "Spotfy", title: "Backend Engineer")
        try store.application(company: "Spotfy", title: "Platform Engineer")
        let company = try Company.findOrCreate(named: "Spotfy", in: context)

        let plan = try company.planRename(to: "Spotifyy", in: context)

        #expect(plan.isMerge == false)
        #expect(plan.confirmation == "Rename")
        #expect(plan.message == "Renaming affects 3 applications.")
    }

    /// A merge is irreversible, so the question names both Companies, the
    /// count, and the fact that one of them stops existing.
    @Test func asksAboutBothCompaniesWhenTheRenameIsAMerge() throws {
        try store.application(company: "Spotfy", title: "iOS Engineer")
        try store.application(company: "Spotfy", title: "Backend Engineer")
        try store.application(company: "Spotfy", title: "Platform Engineer")
        try store.application(company: "Spotify", title: "Designer")
        let source = try Company.findOrCreate(named: "Spotfy", in: context)

        let plan = try source.planRename(to: "Spotify", in: context)

        #expect(plan.isMerge)
        #expect(plan.confirmation == "Merge")
        #expect(
            plan.message
                == "Move 3 applications from Spotfy into Spotify? Spotfy will no longer exist.")
    }

    @Test func countsOneApplicationInTheSingular() throws {
        try store.application(company: "Spotfy", title: "iOS Engineer")
        try store.application(company: "Spotify", title: "Designer")
        let source = try Company.findOrCreate(named: "Spotfy", in: context)

        #expect(
            try source.planRename(to: "Spotifyy", in: context).message
                == "Renaming affects 1 application.")
        #expect(
            try source.planRename(to: "Spotify", in: context).message
                == "Move 1 application from Spotfy into Spotify? Spotfy will no longer exist.")
    }
}
