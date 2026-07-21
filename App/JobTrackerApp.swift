import JobTrackerCore
import SwiftUI

@main
struct JobTrackerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

/// Placeholder. The real window is a `NavigationSplitView` — see `SPEC.md`.
struct ContentView: View {
    var body: some View {
        Text("JobTracker — spec v\(JobTrackerCore.specVersion)")
            .frame(minWidth: 480, minHeight: 320)
    }
}
