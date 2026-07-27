import SwiftUI

/// The File menu's backup section: where backups are going, and how to change
/// it.
///
/// The folder is shown, not just picked — an owner who cannot see where their
/// backups land has no way to tell a working backup from a stopped one.
struct BackupCommands: Commands {
    let mirror: BackupMirror

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Section {
                Text("Backing up to: \(mirror.folder.displayPath)")

                Button("Backup Folder…") {
                    mirror.chooseFolder()
                }
            }
        }
    }
}

extension View {
    /// Puts a backup failure in front of the owner.
    ///
    /// A backup that has stopped still looks exactly like one that is working,
    /// so the only honest way to fail is loudly, in a dialog, saying what to
    /// do about it.
    func backupProblemAlert(_ folder: BackupFolder) -> some View {
        alert(
            "Your backup has stopped",
            isPresented: Binding(
                get: { folder.problem != nil },
                set: { if !$0 { folder.problem = nil } }
            ),
            presenting: folder.problem
        ) { _ in
            Button("OK", role: .cancel) { folder.problem = nil }
        } message: { problem in
            Text(
                [problem.errorDescription, problem.recoverySuggestion]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            )
        }
    }
}
