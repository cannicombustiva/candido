import CandidoCore
import SwiftData
import SwiftUI

/// Candido.
@main
struct CandidoApp: App {
    /// Built from the package's model list so the app and the tests can never
    /// disagree about what the store holds.
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for: Schema(CandidoCore.models))
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
