/// What a Status looks like in the table's chip, said semantically.
///
/// A token rather than a color: which Status carries which tone is a decision,
/// and it lives here where `swift test` reaches it. The app target turns a token
/// into a `Color`.
///
/// It does more than that today, and should not: how strongly each tone fills
/// its capsule is decided in `App/StatusChip.swift`, out of reach of the tests.
/// That is #87's first item, unblocked now that #86 is settled.
///
/// The cases are declared in pipeline order, and that is all their order says.
/// The contract asks for one shade difference — `applied` paler than
/// `screening` — and none anywhere else, so there is no progression here to
/// encode beyond that pair.
///
/// "Pending" is a word `CONTEXT.md` tells you to avoid for a Standing. It is
/// reused here for an appearance, and naming a Tone is not naming a Standing —
/// see the glossary's Tone entry.
public enum Tone: Equatable, Sendable {
    /// Applied for, nothing back yet. The first of the waiting tones.
    case pending

    /// In screening — they have answered once.
    case moving

    /// Interviewing: the furthest in of the waiting tones.
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
