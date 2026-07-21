import Foundation
import SwiftData
import Testing

@testable import JobTrackerCore

/// Find-or-create is the rule the unique constraint cannot express on its own:
/// the same company typed in any casing, with any surrounding whitespace, must
/// resolve to one `Company`, and the first spelling entered stays as the name.
@MainActor
@Suite struct CompanyLookupTests {
    private func emptyContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(JobTrackerCore.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    @Test func createsACompanyTheFirstTimeANameIsSeen() throws {
        let context = try emptyContext()

        let company = try Company.findOrCreate(named: "Spotify", in: context)

        #expect(company.name == "Spotify")
        #expect(try context.fetchCount(FetchDescriptor<Company>()) == 1)
    }

    @Test(arguments: ["spotify", "SPOTIFY", "SpOtIfY", " Spotify ", "\tspotify\n"])
    func resolvesToTheSameCompanyWhateverTheCasingOrSurroundingSpace(
        _ variant: String
    ) throws {
        let context = try emptyContext()
        let first = try Company.findOrCreate(named: "Spotify", in: context)

        let second = try Company.findOrCreate(named: variant, in: context)

        #expect(second === first)
        #expect(try context.fetchCount(FetchDescriptor<Company>()) == 1)
    }

    @Test func keepsTheFirstSpellingAsTheDisplayName() throws {
        let context = try emptyContext()
        _ = try Company.findOrCreate(named: " spotify ", in: context)

        let company = try Company.findOrCreate(named: "SPOTIFY", in: context)

        #expect(company.name == "spotify")
    }

    @Test func keepsDifferentCompaniesApart() throws {
        let context = try emptyContext()

        let spotify = try Company.findOrCreate(named: "Spotify", in: context)
        let monzo = try Company.findOrCreate(named: "Monzo", in: context)

        #expect(spotify !== monzo)
        #expect(try context.fetchCount(FetchDescriptor<Company>()) == 2)
    }

    @Test func attachesEveryApplicationOfOneCompanyToThatCompany() throws {
        let context = try emptyContext()

        let first = try Application.create(
            companyNamed: "Spotify", title: "iOS Engineer", in: context)
        let second = try Application.create(
            companyNamed: " spotify ", title: "Backend Engineer", in: context)

        #expect(first.company === second.company)
        #expect(first.company.applications.count == 2)
        #expect(try context.fetchCount(FetchDescriptor<Company>()) == 1)
    }

    @Test func rejectsANameThatIsOnlyWhitespace() throws {
        let context = try emptyContext()

        #expect(throws: CompanyNameError.self) {
            _ = try Company.findOrCreate(named: "   ", in: context)
        }
    }
}
