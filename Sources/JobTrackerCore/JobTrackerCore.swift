import SwiftData

/// The domain layer for Candido, the job application tracker.
///
/// Candido is the product name only. This module, the app target and the bundle
/// identifiers keep the `JobTracker` names — the sandbox container is keyed by
/// the identifier, so renaming it would orphan the owner's store.
///
/// Everything with a rule in it lives here: the SwiftData models, staleness,
/// company find-or-create, and the JSON codec. The app target holds views only.
///
/// See `SPEC.md` for the behaviour this module is required to implement.
public enum JobTrackerCore {
    public static let specVersion = 1

    /// Everything the store persists. The app builds its `ModelContainer` from
    /// this, and so do the tests, so the two can never drift.
    public static let models: [any PersistentModel.Type] = [
        Company.self,
        Application.self,
    ]
}
