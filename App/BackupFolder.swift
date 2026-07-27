import AppKit
import CandidoCore
import Foundation
import SwiftUI

/// What can go wrong between the owner and their backup folder.
///
/// Every case is something the owner has to be told about: a backup that has
/// quietly stopped happening is worse than no backup, because it still looks
/// like one.
enum BackupFolderProblem: LocalizedError {
    /// The bookmark saved at the last pick no longer resolves — the folder was
    /// deleted, renamed, or is on a volume that is not mounted.
    case folderUnreachable(String)

    /// The bookmark resolved, but the sandbox refused to reopen the folder.
    case accessRefused

    /// The folder resolved but is not there any more.
    case folderMissing

    /// The file itself could not be written.
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .folderUnreachable(let reason):
            "Candido could not reopen your backup folder: \(reason)"
        case .accessRefused:
            "Candido is no longer allowed into your backup folder."
        case .folderMissing:
            "Your backup folder is no longer there."
        case .writeFailed(let reason):
            "Candido could not write the backup file: \(reason)"
        }
    }

    var recoverySuggestion: String? {
        "Choose a backup folder again from File ▸ Backup Folder…. Nothing is being backed up until you do."
    }
}

/// The folder the owner picked, remembered across launches.
///
/// A sandboxed app cannot simply remember a path: the sandbox grants access to
/// what the open panel returned, and that grant only survives a relaunch as a
/// security-scoped bookmark. So the bookmark is what is stored, the path is
/// only what is shown, and access is opened and closed around each write
/// rather than held for the life of the app.
@Observable
@MainActor
final class BackupFolder {
    /// Where backups are going, for showing back to the owner. `nil` means no
    /// folder has been chosen and nothing is being written.
    private(set) var url: URL?

    /// The last thing that went wrong, if it has not been dismissed yet. The
    /// app shows this; it is never only logged.
    var problem: BackupFolderProblem?

    private let defaults: UserDefaults
    private static let bookmarkKey = "backupFolderBookmark"

    /// Resolves the folder chosen on a previous launch, if there was one, so
    /// the owner never picks twice.
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resolveSavedFolder()
    }

    /// Whether backups are switched on at all.
    var isChosen: Bool { url != nil }

    /// What to show the owner: the folder, or that there isn't one.
    var displayPath: String {
        url?.path(percentEncoded: false) ?? "None chosen"
    }

    // MARK: Choosing

    /// Asks for a folder and remembers it. Returns whether the folder changed,
    /// so the caller can write a first backup straight away rather than
    /// leaving the folder empty until the next edit.
    @discardableResult
    func choose() -> Bool {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"
        panel.message =
            "Choose a folder to back up to. Point it at Google Drive or iCloud Drive and your backups sync."

        guard panel.runModal() == .OK, let chosen = panel.url else { return false }

        do {
            let bookmark = try chosen.bookmarkData(
                options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(bookmark, forKey: Self.bookmarkKey)
            url = chosen
            problem = nil
            return true
        } catch {
            report(.folderUnreachable(error.localizedDescription))
            return false
        }
    }

    // MARK: Writing

    /// Writes `data` into the folder, opening scoped access for the write and
    /// closing it again immediately after.
    ///
    /// Does nothing at all when no folder has been chosen — the point of the
    /// picker is that nothing leaves the app until the owner says where to.
    func write(_ data: Data, named name: String) {
        guard let url else { return }

        guard url.startAccessingSecurityScopedResource() else {
            report(.accessRefused)
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            report(.folderMissing)
            return
        }

        do {
            try data.write(to: url.appending(path: name), options: .atomic)
            problem = nil
        } catch {
            report(.writeFailed(error.localizedDescription))
        }
    }

    // MARK: Remembering

    private func resolveSavedFolder() {
        guard let bookmark = defaults.data(forKey: Self.bookmarkKey) else { return }

        do {
            var isStale = false
            let resolved = try URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            url = resolved
            if isStale { refreshBookmark(for: resolved) }
        } catch {
            report(.folderUnreachable(error.localizedDescription))
        }
    }

    /// A stale bookmark still resolves, but only this once — the folder moved,
    /// and the saved bytes describe where it used to be. Writing a fresh one
    /// now is what keeps the owner from being asked to pick again later.
    private func refreshBookmark(for url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        if let bookmark = try? url.bookmarkData(
            options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
        {
            defaults.set(bookmark, forKey: Self.bookmarkKey)
        }
    }

    /// Failures are surfaced, never swallowed: backups that stopped silently
    /// are the failure this whole feature exists to avoid.
    private func report(_ problem: BackupFolderProblem) {
        self.problem = problem
        NSLog("Candido backup: %@", problem.errorDescription ?? "unknown problem")
    }
}
