import SwiftUI

/// The File menu's backup section: where backups are going, and how to change
/// it.
///
/// The folder is shown, not just picked — an owner who cannot see where their
/// backups land has no way to tell a working backup from a stopped one.
struct BackupCommands: Commands {
    let mirror: BackupMirror
    let importer: BackupImporter

    var body: some Commands {
        CommandGroup(after: .saveItem) {
            Section {
                Text("Backing up to: \(mirror.folder.displayPath)")

                Button("Backup Folder…") {
                    mirror.chooseFolder()
                }
            }

            // Import sits in its own section, away from the folder controls:
            // it is the one command in this menu that changes the store, and
            // it is only ever run on purpose.
            Section {
                Button("Import…") {
                    importer.importFile()
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
                set: { if !$0 { folder.dismissProblem() } }
            ),
            presenting: folder.problem
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { problem in
            Text(
                [problem.errorDescription, problem.recoverySuggestion]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            )
        }
    }

    /// Reports what an import did, and what stopped one.
    ///
    /// An import that recognised every row leaves the table looking untouched,
    /// which is exactly what a failed import looks like too — so both outcomes
    /// are said out loud rather than inferred from the rows.
    func importReport(_ importer: BackupImporter) -> some View {
        alert(
            "Nothing was imported",
            isPresented: Binding(
                get: { importer.problem != nil },
                set: { if !$0 { importer.dismissProblem() } }
            ),
            presenting: importer.problem
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { problem in
            Text(
                [problem.errorDescription, problem.recoverySuggestion]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")
            )
        }
        .alert(
            "Import finished",
            isPresented: Binding(
                get: { importer.summary != nil },
                set: { if !$0 { importer.dismissSummary() } }
            ),
            presenting: importer.summary
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { summary in
            Text(summary.sentence)
        }
    }
}
