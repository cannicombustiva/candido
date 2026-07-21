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

        #expect(throws: ApplicationInputError.blankCompanyName) {
            _ = try Company.findOrCreate(named: "   ", in: context)
        }
    }

    @Test func rejectsATitleThatIsOnlyWhitespace() throws {
        let context = try emptyContext()

        #expect(throws: ApplicationInputError.blankTitle) {
            _ = try Application.create(companyNamed: "Spotify", title: "  ", in: context)
        }
        #expect(try context.fetchCount(FetchDescriptor<Application>()) == 0)
    }

    @Test func trimsWhatItStores() throws {
        let context = try emptyContext()

        let application = try Application.create(
            companyNamed: "  Spotify  ", title: "  iOS Engineer  ", in: context)

        #expect(application.title == "iOS Engineer")
        #expect(application.company.name == "Spotify")
    }

    /// The add sheet's button enables on this, so it has to agree with what
    /// `create` will actually accept.
    @Test(arguments: [
        ("Spotify", "iOS Engineer", true),
        ("", "iOS Engineer", false),
        ("Spotify", "", false),
        ("   ", "iOS Engineer", false),
        ("Spotify", "\t\n", false),
    ])
    func agreesWithCreateAboutWhatIsEnoughToSubmit(
        companyName: String, title: String, expected: Bool
    ) throws {
        let context = try emptyContext()

        #expect(Application.canCreate(companyName: companyName, title: title) == expected)

        let created = try? Application.create(
            companyNamed: companyName, title: title, in: context)
        #expect((created != nil) == expected)
    }

    /// An application sent 60 days ago has been silent for 60 days. Stamping
    /// today onto it would make a backdated row read as freshly contacted.
    @Test func treatsTheAppliedDateAsTheLastContactUnlessToldOtherwise() throws {
        let context = try emptyContext()
        let sixtyDaysAgo = Calendar.current.date(byAdding: .day, value: -60, to: Date())!

        let application = try Application.create(
            companyNamed: "Spotify", title: "iOS Engineer", appliedDate: sixtyDaysAgo,
            in: context)

        #expect(application.lastContactDate == sixtyDaysAgo)
    }

    @Test func keepsAnExplicitLastContactDate() throws {
        let context = try emptyContext()
        let applied = Calendar.current.date(byAdding: .day, value: -60, to: Date())!
        let replied = Calendar.current.date(byAdding: .day, value: -2, to: Date())!

        let application = try Application.create(
            companyNamed: "Spotify", title: "iOS Engineer", appliedDate: applied,
            lastContactDate: replied, in: context)

        #expect(application.lastContactDate == replied)
    }
}
