/// The domain layer for the job application tracker.
///
/// Everything with a rule in it lives here: the SwiftData models, staleness,
/// company find-or-create, and the JSON codec. The app target holds views only.
///
/// See `SPEC.md` for the behaviour this module is required to implement.
public enum JobTrackerCore {
    public static let specVersion = 1
}
