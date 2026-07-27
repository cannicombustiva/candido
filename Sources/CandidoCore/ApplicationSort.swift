import Foundation

/// A column the table can be sorted by.
///
/// A field is declared once, below, and that one declaration carries both the
/// heading the column shows and the value it orders on. Nothing downstream
/// re-decides either: there is no `switch` in the comparator and no separate
/// label in the view, so a column can no longer end up sorting by something
/// other than what its heading says while nothing fails.
///
/// `allCases` is still written by hand — it is the roster the tests sweep, and
/// a field left out of it is a field nothing checks. Adding a field means
/// adding it there too.
public struct ApplicationSortField: Hashable, Sendable, CaseIterable {
    /// Stable name for the field. Identity and equality are decided on it.
    public let name: String

    /// The heading the table shows for this column.
    public let columnTitle: String

    /// Orders two Applications on this field's value alone, before any
    /// tie-break.
    let compareKeys: @Sendable (Application, Application) -> ComparisonResult

    private init<Key: Comparable>(
        name: String,
        columnTitle: String,
        key: @escaping @Sendable (Application) -> Key
    ) {
        self.name = name
        self.columnTitle = columnTitle
        self.compareKeys = { compareValues(key($0), key($1)) }
    }

    // The declaration list, in the order the columns appear in the table.

    public static let company = ApplicationSortField(
        name: "company", columnTitle: "Company", key: \.companySortKey)

    public static let title = ApplicationSortField(
        name: "title", columnTitle: "Title", key: \.titleSortKey)

    /// Status sorts along the pipeline rather than the alphabet — see
    /// `Status.rank`.
    public static let status = ApplicationSortField(
        name: "status", columnTitle: "Status", key: { $0.status.rank })

    public static let appliedDate = ApplicationSortField(
        name: "appliedDate", columnTitle: "Applied", key: \.appliedDate)

    public static let lastContactDate = ApplicationSortField(
        name: "lastContactDate", columnTitle: "Last contact", key: \.lastContactDate)

    public static let allCases: [ApplicationSortField] = [
        .company, .title, .status, .appliedDate, .lastContactDate,
    ]

    /// What equal values fall back on, in order, so that repeated sorts of the
    /// same data always come out the same way round.
    static let tieBreak: [ApplicationSortField] = [.company, .title]

    public func comparator(_ order: SortOrder = .forward) -> ApplicationComparator {
        ApplicationComparator(field: self, order: order)
    }

    public static func == (lhs: ApplicationSortField, rhs: ApplicationSortField) -> Bool {
        lhs.name == rhs.name
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}

/// Orders Applications by one field.
///
/// It asks the field for the comparison rather than deciding per field itself:
/// the knowledge of what a column means lives with the column.
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
        let primary = field.compareKeys(lhs, rhs)
        guard primary == .orderedSame else { return primary }

        for fallback in ApplicationSortField.tieBreak {
            let result = fallback.compareKeys(lhs, rhs)
            guard result == .orderedSame else { return result }
        }
        return .orderedSame
    }
}

private func compareValues<Value: Comparable>(_ lhs: Value, _ rhs: Value) -> ComparisonResult {
    if lhs < rhs { return .orderedAscending }
    if lhs > rhs { return .orderedDescending }
    return .orderedSame
}

extension Application {
    /// Company name folded for comparison, so sorting ignores casing.
    public var companySortKey: String { company.name.lowercased() }

    /// Title folded for comparison, so sorting ignores casing.
    public var titleSortKey: String { title.lowercased() }
}
