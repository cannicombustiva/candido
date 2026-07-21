import Foundation
import SwiftData
import Testing

@testable import JobTrackerCore

/// The table's column headers sort through these comparators. Sorting by
/// company ignores casing, and sorting by status follows the pipeline —
/// `applied` before `offer` — rather than the alphabet.
@MainActor
@Suite struct ApplicationSortTests {
    private func context() throws -> ModelContext {
        let container = try ModelContainer(
            for: Schema(JobTrackerCore.models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date())!
    }

    @Test func sortsByCompanyNameIgnoringCasing() throws {
        let context = try context()
        _ = try Application.create(companyNamed: "zalando", title: "A", in: context)
        _ = try Application.create(companyNamed: "Apple", title: "B", in: context)
        _ = try Application.create(companyNamed: "monzo", title: "C", in: context)

        let sorted = try context.fetch(FetchDescriptor<Application>())
            .sorted(using: ApplicationSortField.company.comparator(.forward))

        #expect(sorted.map(\.title) == ["B", "C", "A"])
    }

    @Test func reversesWhenTheOrderIsReversed() throws {
        let context = try context()
        _ = try Application.create(companyNamed: "Apple", title: "B", in: context)
        _ = try Application.create(companyNamed: "zalando", title: "A", in: context)

        let sorted = try context.fetch(FetchDescriptor<Application>())
            .sorted(using: ApplicationSortField.company.comparator(.reverse))

        #expect(sorted.map(\.title) == ["A", "B"])
    }

    @Test func sortsByStatusAlongThePipelineNotTheAlphabet() throws {
        let context = try context()
        for status in [Status.offer, .applied, .rejected, .interviewing] {
            let application = try Application.create(
                companyNamed: status.rawValue, title: status.rawValue, in: context)
            application.status = status
        }

        let sorted = try context.fetch(FetchDescriptor<Application>())
            .sorted(using: ApplicationSortField.status.comparator(.forward))

        #expect(sorted.map(\.status) == [.applied, .interviewing, .offer, .rejected])
    }

    @Test func sortsByLastContactOldestFirst() throws {
        let context = try context()
        let recent = try Application.create(companyNamed: "Recent", title: "R", in: context)
        recent.lastContactDate = day(-1)
        let old = try Application.create(companyNamed: "Old", title: "O", in: context)
        old.lastContactDate = day(-30)

        let sorted = try context.fetch(FetchDescriptor<Application>())
            .sorted(using: ApplicationSortField.lastContactDate.comparator(.forward))

        #expect(sorted.map(\.title) == ["O", "R"])
    }

    @Test func sortsByAppliedDateOldestFirst() throws {
        let context = try context()
        let recent = try Application.create(companyNamed: "Recent", title: "R", in: context)
        recent.appliedDate = day(-2)
        let old = try Application.create(companyNamed: "Old", title: "O", in: context)
        old.appliedDate = day(-40)

        let sorted = try context.fetch(FetchDescriptor<Application>())
            .sorted(using: ApplicationSortField.appliedDate.comparator(.forward))

        #expect(sorted.map(\.title) == ["O", "R"])
    }

    @Test func sortsByTitleIgnoringCasing() throws {
        let context = try context()
        _ = try Application.create(companyNamed: "A", title: "backend engineer", in: context)
        _ = try Application.create(companyNamed: "B", title: "Android Engineer", in: context)

        let sorted = try context.fetch(FetchDescriptor<Application>())
            .sorted(using: ApplicationSortField.title.comparator(.forward))

        #expect(sorted.map(\.title) == ["Android Engineer", "backend engineer"])
    }
}
