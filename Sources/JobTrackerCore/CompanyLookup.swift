import Foundation
import SwiftData

/// What the add sheet can get wrong.
///
/// These are decisions, so they live here rather than in the view: the view
/// asks `Application.canCreate` whether to enable its button, and `create`
/// enforces the same rules on the way in.
public enum ApplicationInputError: Error, Equatable {
    /// A Company name has to have something in it — a name of only spaces
    /// would fold to "" and collide with every other empty name.
    case blankCompanyName

    /// An Application with no title is a row the owner cannot identify.
    case blankTitle
}

extension String {
    /// Surrounding whitespace is never meaningful in anything the owner types.
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Company {
    /// Folds a typed name down to what identity is decided on: surrounding
    /// whitespace removed, casing ignored.
    ///
    /// Interior spacing is deliberately left alone — `"Some Company"` and
    /// `"SomeCompany"` are two different names.
    static func normalize(_ name: String) throws -> String {
        let trimmed = name.trimmed
        guard !trimmed.isEmpty else { throw ApplicationInputError.blankCompanyName }
        return trimmed.lowercased()
    }

    /// Returns the Company this name refers to, creating it if this is the
    /// first time it has been seen.
    ///
    /// The unique constraint on `normalizedName` cannot do this on its own: it
    /// would reject the second spelling rather than resolve it to the first.
    /// The first spelling entered stays as the display name.
    public static func findOrCreate(named name: String, in context: ModelContext) throws
        -> Company
    {
        let normalized = try normalize(name)

        var descriptor = FetchDescriptor<Company>(
            predicate: #Predicate { $0.normalizedName == normalized }
        )
        descriptor.fetchLimit = 1

        if let existing = try context.fetch(descriptor).first {
            return existing
        }

        let company = Company(name: name.trimmed, normalizedName: normalized)
        context.insert(company)
        return company
    }
}

extension Application {
    /// Whether these two typed strings are enough to make an Application. The
    /// add sheet enables its button on this, so the rule the button obeys and
    /// the rule `create` enforces are the same rule.
    public static func canCreate(companyName: String, title: String) -> Bool {
        !companyName.trimmed.isEmpty && !title.trimmed.isEmpty
    }

    /// Adds an Application, attaching it to the Company that name refers to —
    /// creating that Company if the name is new.
    ///
    /// `lastContactDate` defaults to the applied date, never to today: an
    /// application sent 60 days ago has been silent for 60 days unless the
    /// caller says otherwise.
    @discardableResult
    public static func create(
        companyNamed companyName: String,
        title: String,
        status: Status = .applied,
        appliedDate: Date = Date(),
        lastContactDate: Date? = nil,
        jobURL: URL? = nil,
        notes: String = "",
        in context: ModelContext
    ) throws -> Application {
        let trimmedTitle = title.trimmed
        guard !trimmedTitle.isEmpty else { throw ApplicationInputError.blankTitle }

        let company = try Company.findOrCreate(named: companyName, in: context)
        let application = Application(
            company: company,
            title: trimmedTitle,
            status: status,
            appliedDate: appliedDate,
            lastContactDate: lastContactDate,
            jobURL: jobURL,
            notes: notes
        )
        context.insert(application)
        return application
    }
}
