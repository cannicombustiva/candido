import AppKit
import CandidoCore
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// What can go wrong between a chosen file and the store.
///
/// Nothing here is logged and forgotten: an import that silently did nothing is
/// indistinguishable from one that worked, and the owner would find out only by
/// counting rows.
enum BackupImportProblem: LocalizedError {
    /// The file could not be read at all — moved, or on a volume the sandbox
    /// was not let into.
    case unreadable(String)

    /// The file was read but is not a backup Candido wrote.
    case notABackupFile(String)

    /// The rows were understood but the store refused them.
    case notImported(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let reason):
            "Candido could not read that file: \(reason)"
        case .notABackupFile(let reason):
            "That file is not a Candido backup: \(reason)"
        case .notImported(let reason):
            "Candido could not import that file: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        "Nothing was imported and nothing in Candido was changed. Choose the backup file Candido wrote — it is named \(BackupSnapshot.fileName)."
    }
}

/// `File ▸ Import…`: the owner picks a backup file and it is merged in.
///
/// Import is manual only and lives nowhere else — nothing imports at launch or
/// on a schedule. Automatic import means conflict resolution, and two machines
/// writing one file is a distributed systems problem this app will not have.
///
/// The merging itself is `BackupSnapshot.merge(into:)` in the package, where
/// the tests can reach it; this type is the file picker and the reporting.
@Observable
@MainActor
final class BackupImporter {
    /// The last thing that went wrong, if it has not been dismissed. Shown in
    /// a dialog, never only logged.
    var problem: BackupImportProblem?

    /// What the last import did, until the owner dismisses it. An import that
    /// recognised every row changes nothing visible, so it says so rather than
    /// leaving the owner wondering whether the file was read.
    var summary: BackupSnapshot.ImportSummary?

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Asks for a backup file and merges it into the store.
    ///
    /// Either the whole file lands or none of it does: anything that throws
    /// rolls the context back, so a rejected file leaves the store exactly as
    /// it was rather than half-merged.
    func importFile() {
        guard let url = chooseFile() else { return }

        do {
            let data = try read(url)
            let snapshot = try decode(data)
            summary = try merge(snapshot)
        } catch let problem as BackupImportProblem {
            context.rollback()
            report(problem)
        } catch {
            context.rollback()
            report(.notImported(error.localizedDescription))
        }
    }

    /// Puts a dialog away. One way to clear each, rather than one per button.
    func dismissProblem() {
        problem = nil
    }

    func dismissSummary() {
        summary = nil
    }

    // MARK: The steps

    private func chooseFile() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.json]
        panel.prompt = "Import"
        panel.message =
            "Choose a Candido backup file. Its applications are merged into this Mac — nothing is deleted."

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    /// Reads the picked file. Access is opened around the read where the
    /// sandbox asks for it, and the panel's own grant covers it where it does
    /// not — so a file on an external volume reads the same as one on the desk.
    private func read(_ url: URL) throws -> Data {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        do {
            return try Data(contentsOf: url)
        } catch {
            throw BackupImportProblem.unreadable(error.localizedDescription)
        }
    }

    private func decode(_ data: Data) throws -> BackupSnapshot {
        do {
            return try BackupSnapshot(json: data)
        } catch {
            throw BackupImportProblem.notABackupFile(error.localizedDescription)
        }
    }

    /// Merges and saves in one step: the merge only stages the changes, and an
    /// import the owner was told about but that was never written down is the
    /// lie this whole feature is trying not to tell.
    private func merge(_ snapshot: BackupSnapshot) throws -> BackupSnapshot.ImportSummary {
        do {
            let summary = try snapshot.merge(into: context)
            try context.save()
            return summary
        } catch {
            throw BackupImportProblem.notImported(error.localizedDescription)
        }
    }

    private func report(_ problem: BackupImportProblem) {
        self.problem = problem
        NSLog("Candido import: %@", problem.errorDescription ?? "unknown problem")
    }
}
