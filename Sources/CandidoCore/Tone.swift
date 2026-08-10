/// What a Status looks like in the table's chip, said semantically.
///
/// A token rather than a color: which Status reads as which shade is a
/// decision, and it lives here where `swift test` reaches it. The app target
/// turns a token into a `Color` and does nothing else — no view decides what a
/// Status means.
///
/// The cases are ordered as the pipeline is, so the deepening of the three
/// "awaits their reply" tones is visible in the type.
public enum Tone: Equatable, Sendable {
    /// Applied for, nothing back yet. Palest of the waiting tones.
    ///
    /// "Pending" is a word `CONTEXT.md` tells you to avoid for a Standing. It
    /// is borrowed here for a shade and means nothing about whose move it is —
    /// see the glossary's Tone entry.
    case pending

    /// In screening — they have answered once.
    case moving

    /// Interviewing. The deepest of the waiting tones, because it is the
    /// furthest in.
    case deep

    /// The move is the owner's: an offer.
    case yours

    /// Over, either way. `rejected` and `withdrawn` share this tone because
    /// they share a Standing and nothing downstream tells them apart.
    case spent
}

extension Status {
    /// The chip tone for this Status.
    ///
    /// Never orange: orange is Stale's, on the last-contact date and nowhere
    /// else. A chip does not restyle because a row went quiet.
    public var tone: Tone {
        switch self {
        case .applied: .pending
        case .screening: .moving
        case .interviewing: .deep
        case .offer: .yours
        case .rejected, .withdrawn: .spent
        }
    }
}
