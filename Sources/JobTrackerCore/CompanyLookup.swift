import Foundation
import SwiftData

public enum CompanyNameError: Error, Equatable {
    /// A Company name has to have something in it — a name of only spaces
    /// would fold to "" and collide with every other empty name.
    case blank
}

extension Company {
    /// Folds a typed name down to what identity is decided on: surrounding
    /// whitespace removed, casing ignored.
    ///
    /// Interior spacing is deliberately left alone — `"Some Company"` and
    /// `"SomeCompany"` are two different names.
    static func normalize(_ name: String) throws -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw CompanyNameError.blank }
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

        let company = Company(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            normalizedName: normalized
        )
        context.insert(company)
        return company
    }
}

extension Application {
    /// Adds an Application, attaching it to the Company that name refers to —
    /// creating that Company if the name is new.
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
        let company = try Company.findOrCreate(named: companyName, in: context)
        let application = Application(
            company: company,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            status: status,
            appliedDate: appliedDate,
            lastContactDate: lastContactDate ?? appliedDate,
            jobURL: jobURL,
            notes: notes
        )
        context.insert(application)
        return application
    }
}
