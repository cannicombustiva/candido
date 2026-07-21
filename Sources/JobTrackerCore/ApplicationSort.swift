import Foundation

/// The columns the table can be sorted by.
public enum ApplicationSortField: String, CaseIterable, Sendable {
    case company
    case title
    case status
    case appliedDate
    case lastContactDate

    public func comparator(_ order: SortOrder = .forward) -> ApplicationComparator {
        ApplicationComparator(field: self, order: order)
    }
}

/// Orders Applications by one field.
///
/// Text fields compare case-insensitively — the table should not put
/// `"backend engineer"` after `"Zalando"` because of a lowercase `b`. Equal
/// values fall back to company then title so that repeated sorts of the same
/// data always come out in the same order.
public struct ApplicationComparator: SortComparator, Sendable {
    public typealias Compared = Application

    public let field: ApplicationSortField
    public var order: SortOrder

    public init(field: ApplicationSortField, order: SortOrder = .forward) {
        self.field = field
        self.order = order
    }

    public func compare(_ lhs: Application, _ rhs: Application) -> ComparisonResult {
        let result = compareForward(lhs, rhs)
        guard order == .reverse else { return result }
        switch result {
        case .orderedAscending: return .orderedDescending
        case .orderedDescending: return .orderedAscending
        case .orderedSame: return .orderedSame
        }
    }

    private func compareForward(_ lhs: Application, _ rhs: Application) -> ComparisonResult {
        let primary: ComparisonResult
        switch field {
        case .company:
            primary = compare(lhs.companySortKey, rhs.companySortKey)
        case .title:
            primary = compare(lhs.titleSortKey, rhs.titleSortKey)
        case .status:
            primary = compare(lhs.status.rank, rhs.status.rank)
        case .appliedDate:
            primary = compare(lhs.appliedDate, rhs.appliedDate)
        case .lastContactDate:
            primary = compare(lhs.lastContactDate, rhs.lastContactDate)
        }
        guard primary == .orderedSame else { return primary }

        let byCompany = compare(lhs.companySortKey, rhs.companySortKey)
        guard byCompany == .orderedSame else { return byCompany }
        return compare(lhs.titleSortKey, rhs.titleSortKey)
    }

    private func compare<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
        if lhs < rhs { return .orderedAscending }
        if lhs > rhs { return .orderedDescending }
        return .orderedSame
    }
}

extension Application {
    /// Company name folded for comparison, so sorting ignores casing.
    public var companySortKey: String { company.name.lowercased() }

    /// Title folded for comparison, so sorting ignores casing.
    public var titleSortKey: String { title.lowercased() }
}
