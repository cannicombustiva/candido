import JobTrackerCore
import SwiftData
import SwiftUI

/// Candido. The type keeps the `JobTracker` name the target and bundle
/// identifier use; `Candido` is the display name, set in `project.yml`.
@main
struct JobTrackerApp: App {
    /// Built from the package's model list so the app and the tests can never
    /// disagree about what the store holds.
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Schema(JobTrackerCore.models))
        } catch {
            fatalError("Could not open the job application store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
