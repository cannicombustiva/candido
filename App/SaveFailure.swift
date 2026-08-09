import SwiftData

extension ModelContext {
    /// Writes pending changes through, answering with what to tell the owner if
    /// they did not land.
    ///
    /// SwiftData autosaves, but a relaunch right after a keystroke is exactly
    /// the case the owner will hit, so every edit is written through. A failure
    /// is reported rather than swallowed: an edit that never reached the store
    /// looks exactly like one that did.
    ///
    /// The sentence lives here rather than in each view so that every screen
    /// says the same thing when the store refuses.
    func saveOrDescribeFailure() -> String? {
        do {
            try save()
            return nil
        } catch {
            return "Could not save the change: \(error.localizedDescription)"
        }
    }
}
