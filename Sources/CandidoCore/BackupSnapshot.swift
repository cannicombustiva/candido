import Foundation
import SwiftData

/// The whole dataset, as it is written to the backup folder.
///
/// A snapshot is a plain value, not a store: it is read out of a
/// `ModelContext` once and then knows nothing about SwiftData, which is what
/// lets `swift test` round-trip it with no folder and no file system in sight.
///
/// It is backup, not sync — one machine writes, and the file is a snapshot of
/// that machine at that moment. See "Backup" in `SPEC.md`.
public struct BackupSnapshot: Equatable, Codable, Sendable {
    /// Which version of the contract wrote this file. Nothing reads it yet; it
    /// is written now so a future import can tell an old file from a new one
    /// without guessing from its shape.
    public var specVersion: Int

    /// Every Company in the store, each carrying its own Applications.
    ///
    /// Applications are nested under their Company rather than listed
    /// alongside it with a reference, because a nested file cannot describe an
    /// Application that belongs to a Company the file does not contain.
    public var companies: [CompanyRecord]

    /// One Company and everything applied for there.
    public struct CompanyRecord: Equatable, Codable, Sendable {
        /// The display spelling. Import folds it the same way the add sheet
        /// does, so `"spotify"` in a file joins an existing `"Spotify"`.
        public var name: String
        public var applications: [ApplicationRecord]
    }

    /// One Application, flattened. The Company is implied by where it sits.
    public struct ApplicationRecord: Equatable, Codable, Sendable {
        /// Stable across export and import — what a merge matches on.
        public var id: UUID
        public var title: String
        public var status: Status
        public var appliedDate: Date
        public var lastContactDate: Date
        public var jobURL: URL?
        public var notes: String
    }

    /// The one file the mirror writes. A fixed name, so each write replaces
    /// the last one rather than leaving the folder to accumulate snapshots.
    public static let fileName = "candido-backup.json"

    /// How long the store has to sit still before a backup is written.
    ///
    /// Typing a note is dozens of changes; each one is not a backup. Two
    /// seconds is long enough that a burst of edits collapses into a single
    /// write, and short enough that the file is current by the time the owner
    /// has looked away.
    public static let quietPeriod: Duration = .seconds(2)

    public init(specVersion: Int = CandidoCore.specVersion, companies: [CompanyRecord]) {
        self.specVersion = specVersion
        self.companies = companies
    }

    /// Reads the whole store.
    ///
    /// The ordering is fixed — Companies by the name they are identified on,
    /// Applications by id — so reading an unchanged store twice produces the
    /// same bytes. A backup folder pointed at Google Drive would otherwise
    /// re-upload a file whose contents only got shuffled.
    public init(of context: ModelContext) throws {
        let companies = try context.fetch(
            FetchDescriptor<Company>(sortBy: [SortDescriptor(\.normalizedName)])
        )

        self.init(
            companies: companies.map { company in
                CompanyRecord(
                    name: company.name,
                    applications: company.applications
                        .sorted { $0.id.uuidString < $1.id.uuidString }
                        .map(ApplicationRecord.init)
                )
            }
        )
    }

    // MARK: JSON

    /// This snapshot as the bytes that go in the file.
    ///
    /// Pretty-printed with sorted keys: the file is something the owner can
    /// open and read, and a diff of two backups should show what changed
    /// rather than that the key order moved.
    public func json() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Reads bytes that were written by `json()`. Throws on anything else,
    /// rather than returning a half-read dataset.
    public init(json: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self = try decoder.decode(BackupSnapshot.self, from: json)
    }
}

extension BackupSnapshot.ApplicationRecord {
    init(_ application: Application) {
        self.init(
            id: application.id,
            title: application.title,
            status: application.status,
            appliedDate: application.appliedDate.wholeSecond,
            lastContactDate: application.lastContactDate.wholeSecond,
            jobURL: application.jobURL,
            notes: application.notes
        )
    }
}

extension Date {
    /// This instant, to the second.
    ///
    /// The file writes timestamps the owner can read, which are accurate to
    /// the second, and a value that survives its own file format is worth more
    /// here than a fraction of a second nothing in the domain looks at —
    /// staleness counts calendar days.
    var wholeSecond: Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate.rounded(.down))
    }
}
