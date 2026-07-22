import Foundation
import SwiftData
import Testing

@testable import JobTrackerCore

/// The table's column headers sort through these comparators. Sorting by
/// company ignores casing, and sorting by status follows the pipeline —
/// `applied` before `offer` — rather than the alphabet.
@MainActor
@Suite struct ApplicationSortTests {
    private let store: TestStore

    init() throws {
        store = try TestStore()
    }

    private func sorted(
        by field: ApplicationSortField, _ order: SortOrder = .forward
    ) throws -> [Application] {
        try store.applications().sorted(using: field.comparator(order))
    }

    @Test func sortsByCompanyNameIgnoringCasing() throws {
        try store.application(company: "zalando", title: "A")
        try store.application(company: "Apple", title: "B")
        try store.application(company: "monzo", title: "C")

        #expect(try sorted(by: .company).map(\.title) == ["B", "C", "A"])
    }

    @Test func reversesWhenTheOrderIsReversed() throws {
        try store.application(company: "Apple", title: "B")
        try store.application(company: "zalando", title: "A")

        #expect(try sorted(by: .company, .reverse).map(\.title) == ["A", "B"])
    }

    @Test func sortsByStatusAlongThePipelineNotTheAlphabet() throws {
        for status in [Status.offer, .applied, .rejected, .interviewing] {
            try store.application(company: status.rawValue, title: status.rawValue, status: status)
        }

        #expect(
            try sorted(by: .status).map(\.status) == [.applied, .interviewing, .offer, .rejected])
    }

    // The two date sorts deliberately disagree with each other: in each test the
    // applied dates run one way and the last contact dates the other. A
    // comparator wired to the wrong date column fails here rather than passing
    // on a coincidence.

    @Test func sortsByLastContactOldestFirst() throws {
        try store.application(company: "Recent", title: "R", silentFor: 1, appliedDaysAgo: 50)
        try store.application(company: "Old", title: "O", silentFor: 30, appliedDaysAgo: 31)

        #expect(try sorted(by: .lastContactDate).map(\.title) == ["O", "R"])
    }

    @Test func sortsByAppliedDateOldestFirst() throws {
        try store.application(company: "Recent", title: "R", silentFor: 2, appliedDaysAgo: 2)
        try store.application(company: "Old", title: "O", silentFor: 0, appliedDaysAgo: 40)

        #expect(try sorted(by: .appliedDate).map(\.title) == ["O", "R"])
    }

    @Test func sortsByTitleIgnoringCasing() throws {
        try store.application(company: "A", title: "backend engineer")
        try store.application(company: "B", title: "Android Engineer")

        #expect(try sorted(by: .title).map(\.title) == ["Android Engineer", "backend engineer"])
    }
}
