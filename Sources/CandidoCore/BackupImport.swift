import Foundation
import SwiftData

extension BackupSnapshot {
    /// What a merge did. The owner picked a file and watched nothing visibly
    /// happen if every row was already there, so the app has something to say.
    public struct ImportSummary: Equatable, Sendable {
        /// Applications the store had never seen before.
        public var inserted: Int

        /// Applications already in the store, refreshed from the file.
        public var updated: Int

        /// Rows in the file that could not become an Application — no title, or
        /// filed under a company with no name. They are passed over rather than
        /// taken as a reason to refuse the file, so one damaged row cannot cost
        /// the owner every good row alongside it.
        public var skipped: Int

        /// What the import did, in the owner's terms — the whole body of the
        /// dialog they read afterwards.
        ///
        /// It is here rather than in the view because it decides things: which
        /// of four things happened, and how to count them. An import that
        /// recognised every row leaves the table looking exactly like one that
        /// failed, so this sentence is the only evidence the owner gets, and it
        /// is the kind of thing `swift test` should be able to read.
        public var sentence: String {
            [outcome, skippedNote].compactMap { $0 }.joined(separator: " ")
        }

        private var outcome: String {
            switch (inserted, updated) {
            case (0, 0):
                "Nothing in that file was new, so nothing changed."
            case (0, _):
                "\(applications(updated)) already here \(updated == 1 ? "was" : "were") brought up to date. Nothing was added, and nothing was deleted."
            case (_, 0):
                "\(applications(inserted)) added. Nothing already here was changed, and nothing was deleted."
            default:
                "\(applications(inserted)) added and \(applications(updated)) brought up to date. Nothing was deleted."
            }
        }

        /// Said out loud when rows were passed over: the owner has to be able to
        /// tell an import that took everything from one that quietly did not.
        private var skippedNote: String? {
            guard skipped > 0 else { return nil }
            return
                "\(applications(skipped)) in the file had no title or no company name and \(skipped == 1 ? "was" : "were") skipped."
        }

        private func applications(_ count: Int) -> String {
            "\(count) application\(count == 1 ? "" : "s")"
        }
    }

    /// Merges this file into the store.
    ///
    /// A merge, never a restore: an Application matches on its stable id and is
    /// updated in place, an unknown id is inserted, and a row the file does not
    /// mention is left exactly as it is. Import deletes nothing. The cost is
    /// that a row deleted before the file was written comes back, and that the
    /// store can only grow — the price of an import that cannot lose work. See
    /// "Import merges. It never deletes." in `SPEC.md`.
    ///
    /// Companies resolve through the same find-or-create the add sheet uses, so
    /// `"spotify"` in a file joins an existing `"Spotify"`.
    ///
    /// A row the store could not hold — no title, or filed under a company with
    /// no name — is passed over and counted, not treated as a reason to refuse
    /// the file: one damaged row must not cost the owner every good row beside
    /// it. Saving is left to the caller.
    @discardableResult
    public func merge(into context: ModelContext) throws -> ImportSummary {
        var known = try knownApplications(in: context)
        var summary = ImportSummary(inserted: 0, updated: 0, skipped: 0)
        /// Companies an Application was moved off. Whether they are empty can
        /// only be asked once every row has been placed.
        var vacated: [Company] = []

        for companyRecord in companies {
            // A company with no name identifies nothing, so nothing filed under
            // it can be placed — its rows go by together.
            guard Company.isKeepableName(companyRecord.name) else {
                summary.skipped += companyRecord.applications.count
                continue
            }
            let company = try Company.findOrCreate(named: companyRecord.name, in: context)

            for record in companyRecord.applications {
                // A row with no title is one the owner could not pick out of
                // the table afterwards.
                guard Application.isKeepableTitle(record.title) else {
                    summary.skipped += 1
                    continue
                }

                if let existing = known[record.id] {
                    if existing.company !== company { vacated.append(existing.company) }
                    existing.update(from: record, at: company)
                    summary.updated += 1
                } else {
                    // Kept in `known` so a file that names one id twice updates
                    // that row rather than inserting a second one and tripping
                    // the unique constraint on the way to the disk.
                    known[record.id] = record.insert(at: company, into: context)
                    summary.inserted += 1
                }
            }
        }

        clearAway(vacated, in: context)
        return summary
    }

    /// Drops the Companies a merge left holding nothing.
    ///
    /// This is not the deleting the spec forbids. What must never disappear is
    /// work: an Application the file did not mention. A Company that has been
    /// left holding nothing is not work, and it goes by the same rule a
    /// deletion uses — one notion of a Company that has stopped meaning
    /// anything, not one per caller.
    private func clearAway(_ vacated: [Company], in context: ModelContext) {
        for company in vacated {
            company.clearAwayIfEmpty(from: context)
        }
    }

    /// Everything already in the store, by the id a merge matches on. Read once
    /// rather than fetched per row: the id is unique, so this is the whole
    /// question a merge asks of the store.
    private func knownApplications(in context: ModelContext) throws -> [UUID: Application] {
        let existing = try context.fetch(FetchDescriptor<Application>())
        return Dictionary(existing.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

extension BackupSnapshot.ApplicationRecord {
    /// Adds this record to the store as a new Application, keeping its id — the
    /// id is what makes the next import of the same file a no-op.
    fileprivate func insert(at company: Company, into context: ModelContext) -> Application {
        let application = Application(
            id: id,
            company: company,
            title: title.trimmed,
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

extension Application {
    /// Takes the file's account of this Application, including its Company: the
    /// file is the newer account, and a merge that kept some fields would leave
    /// a row that matches neither machine.
    ///
    /// `appliedDate` is the exception, and it is not one this merge gets to
    /// make: it is set once and never changes, so a file cannot rewrite the day
    /// an application was sent.
    fileprivate func update(from record: BackupSnapshot.ApplicationRecord, at company: Company) {
        self.company = company
        title = record.title.trimmed
        status = record.status
        lastContactDate = record.lastContactDate
        jobURL = record.jobURL
        notes = record.notes
    }
}
