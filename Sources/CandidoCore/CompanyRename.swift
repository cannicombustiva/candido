import Foundation
import SwiftData

/// A rename that has been worked out but not yet done.
///
/// The dialog has to describe the act before the owner agrees to it, and the
/// description and the act must be the same thing — so the plan is what gets
/// shown and what gets applied.
public struct CompanyRenamePlan {
    let company: Company
    let newName: String
    let newNormalizedName: String

    /// The Company this rename would merge into, if the name is already taken
    /// by one that is not this Company. `nil` for a plain rename.
    ///
    /// The dialog reads this to decide whether it is asking about a correction
    /// or about two Companies becoming one.
    public let destination: Company?

    /// Whether this rename is about to fold two Companies into one.
    public var isMerge: Bool { destination != nil }

    /// How many Applications this act moves or re-labels — the blast radius the
    /// dialog names, because it opens from one Application's panel and the
    /// Company name belongs to more than that one.
    public var affectedCount: Int { standing.count }

    /// The Applications this act actually touches. One definition, read by both
    /// the count the dialog promises and the loop that moves them — if they
    /// disagreed, the dialog would name a number the merge does not honour.
    ///
    /// An Application already deleted and waiting for the context to work
    /// through it is not work any more, and is neither counted nor moved.
    private var standing: [Application] {
        company.applications.filter { !$0.isGoing }
    }

    /// What the confirming button says. A merge is a different act from a
    /// rename and must not be agreed to under the word "Rename".
    public var confirmation: String {
        isMerge ? "Merge" : "Rename"
    }

    /// What the dialog asks, in the owner's terms.
    ///
    /// It is here rather than in the view for the same reason
    /// `ImportSummary.sentence` is: it decides things — which of two acts is
    /// about to happen, and how to count what it touches — and a merge is
    /// irreversible, so the words are the whole of the protection.
    public var message: String {
        guard let destination else {
            return "Renaming affects \(applications(affectedCount))."
        }
        return "Move \(applications(affectedCount)) from \(company.name) "
            + "into \(destination.name)? \(company.name) will no longer exist."
    }

    private func applications(_ count: Int) -> String {
        "\(count) application\(count == 1 ? "" : "s")"
    }

    /// Performs the rename.
    public func apply(in context: ModelContext) {
        guard let destination else {
            company.name = newName
            company.normalizedName = newNormalizedName
            return
        }

        // Order is load-bearing. `Company.applications` cascades on delete, so
        // a source cleared away before its work moved would take that work with
        // it. Applications change hands first; the source is offered to
        // `clearAwayIfEmpty` after, and never to a bare `context.delete`.
        for application in standing {
            application.company = destination
        }
        company.clearAwayIfEmpty(from: context)
    }
}

extension Company {
    /// Works out what renaming this Company to `name` would do.
    public func planRename(to name: String, in context: ModelContext) throws
        -> CompanyRenamePlan
    {
        let normalized = try Company.normalize(name)
        let taken = try Company.existing(normalizedName: normalized, in: context)

        return CompanyRenamePlan(
            company: self,
            newName: name.trimmed,
            newNormalizedName: normalized,
            // A name that folds to this Company's own identity is not a
            // collision — it is a rewrite of what is displayed.
            destination: taken === self ? nil : taken
        )
    }
}
