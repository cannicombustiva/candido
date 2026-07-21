import JobTrackerCore
import SwiftData
import SwiftUI

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
