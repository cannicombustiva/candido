import CandidoCore
import SwiftData
import SwiftUI

/// Candido.
@main
struct CandidoApp: App {
    /// Built from the package's model list so the app and the tests can never
    /// disagree about what the store holds.
    private let container: ModelContainer

    /// Keeps the owner's chosen backup folder holding a current copy. It
    /// listens to the store, so no view has to remember to ask for a backup.
    @State private var mirror: BackupMirror

    init() {
        do {
            let container = try ModelContainer(for: Schema(CandidoCore.models))
            self.container = container
            _mirror = State(initialValue: BackupMirror(context: container.mainContext))
        } catch {
            fatalError("Could not open the job application store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .backupProblemAlert(mirror.folder)
        }
        .modelContainer(container)
        .commands { BackupCommands(mirror: mirror) }
    }
}
