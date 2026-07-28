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
    /// The whole file is checked before a single row is touched, so a file with
    /// a bad row anywhere in it imports nothing rather than half of itself.
    /// Saving is left to the caller.
    @discardableResult
    public func merge(into context: ModelContext) throws -> ImportSummary {
        try validate()

        var known = try knownApplications(in: context)
        var summary = ImportSummary(inserted: 0, updated: 0)

        for companyRecord in companies {
            let company = try Company.findOrCreate(named: companyRecord.name, in: context)

            for record in companyRecord.applications {
                if let existing = known[record.id] {
                    existing.update(from: record, at: company)
                    summary.updated += 1
                } else {
                    // Kept in `known` so a file that names one id twice updates
                    // that row rather than inserting a second one and tripping
                    // the unique constraint on the way to the disk.
                    known[record.id] = record.inserted(at: company, into: context)
                    summary.inserted += 1
                }
            }
        }

        return summary
    }

    /// Refuses a file that would put a row in the store the owner cannot use —
    /// before anything is inserted, because a half-applied import is the one
    /// outcome worse than a refused one.
    private func validate() throws {
        for company in companies {
            _ = try Company.normalize(company.name)

            for application in company.applications {
                guard Application.isKeepableTitle(application.title) else {
                    throw ApplicationInputError.blankTitle
                }
            }
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
    fileprivate func inserted(at company: Company, into context: ModelContext) -> Application {
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
    /// Takes every field from the file, including the Company: the file is the
    /// newer account of this Application, and a merge that kept some fields
    /// would leave a row that matches neither machine.
    fileprivate func update(from record: BackupSnapshot.ApplicationRecord, at company: Company) {
        self.company = company
        title = record.title.trimmed
        status = record.status
        appliedDate = record.appliedDate
        lastContactDate = record.lastContactDate
        jobURL = record.jobURL
        notes = record.notes
    }
}
