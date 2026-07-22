import SwiftData

/// The domain layer for Candido, the job application tracker.
///
/// The bundle identifiers are load-bearing and must not be renamed — see
/// "Appendix: the name" in `SPEC.md` for why.
///
/// Everything with a rule in it lives here: the SwiftData models, staleness,
/// company find-or-create, and the JSON codec. The app target holds views only.
///
/// See `SPEC.md` for the behaviour this module is required to implement.
public enum CandidoCore {
    public static let specVersion = 1

    /// Everything the store persists. The app builds its `ModelContainer` from
    /// this, and so do the tests, so the two can never drift.
    public static let models: [any PersistentModel.Type] = [
        Company.self,
        Application.self,
    ]
}
