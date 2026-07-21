import Foundation
import SwiftData

/// Where an Application currently stands.
///
/// The order of the cases is the pipeline order, and sorting relies on it —
/// see `Status.rank`.
public enum Status: String, Codable, CaseIterable, Sendable {
    case applied
    case screening
    case interviewing
    case offer
    case rejected
    case withdrawn

    /// Position in the pipeline. Sorting by status follows this, not the
    /// alphabet: `applied` comes before `offer` because that is the order the
    /// owner moves through, and `withdrawn` sorts last because it is over.
    public var rank: Int {
        Status.allCases.firstIndex(of: self) ?? 0
    }

    /// A Status the Application does not move on from. The owner never
    /// archives anything by hand — being Terminal *is* being archived.
    public var isTerminal: Bool {
        switch self {
        case .rejected, .withdrawn: true
        case .applied, .screening, .interviewing, .offer: false
        }
    }

    public var displayName: String {
        rawValue.capitalized
    }
}

/// An organization the owner has applied to.
///
/// Companies are never managed directly — one comes into existence the first
/// time it is named in the add sheet. `normalizedName` is what identity is
/// decided on; `name` is only ever shown.
@Model
public final class Company {
    /// The first spelling ever entered. Shown everywhere, compared nowhere.
    public var name: String

    /// `name` folded for comparison. Unique, so the store cannot end up with
    /// two Companies that differ only by casing or surrounding space.
    @Attribute(.unique) public var normalizedName: String

    @Relationship(deleteRule: .cascade, inverse: \Application.company)
    public var applications: [Application] = []

    init(name: String, normalizedName: String) {
        self.name = name
        self.normalizedName = normalizedName
    }
}

/// One pursuit of one role at one Company.
@Model
public final class Application {
    /// Stable across export and import. Import matches on this, so it is
    /// generated once and never reassigned.
    @Attribute(.unique) public var id: UUID

    public var company: Company
    public var title: String
    public var status: Status

    /// Set once, never changes.
    public var appliedDate: Date

    /// Resets whenever either side makes contact. Drives staleness.
    ///
    /// Defaults to `appliedDate` rather than today: sending an application
    /// *is* the last contact, and a row backdated on import must not read as
    /// freshly contacted just because it was constructed today.
    public var lastContactDate: Date

    public var jobURL: URL?
    public var notes: String

    init(
        id: UUID = UUID(),
        company: Company,
        title: String,
        status: Status = .applied,
        appliedDate: Date = Date(),
        lastContactDate: Date? = nil,
        jobURL: URL? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.company = company
        self.title = title
        self.status = status
        self.appliedDate = appliedDate
        self.lastContactDate = lastContactDate ?? appliedDate
        self.jobURL = jobURL
        self.notes = notes
    }
}
