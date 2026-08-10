/// What a Status looks like in the table's chip, said semantically.
///
/// A token rather than a color: which Status carries which tone is a decision,
/// and it lives here where `swift test` reaches it. The app target turns a token
/// into a `Color`.
///
/// It does more than that today, and should not: the pale-vs-medium
/// relationship between the tones is a fill weight in `App/StatusChip.swift`,
/// out of reach of the tests. That is #87's first item, blocked on #86.
///
/// The cases are declared in pipeline order. That is the order they are meant
/// to deepen in; it is not what the app renders today, and issue #86 is open on
/// what the deepening should be. Nothing here asserts a shade ordering, because
/// none is settled — the app target's fill weights are the only place a shade is
/// chosen, and #87 moves them here once #86 answers.
///
/// The names "pending" and "moving" are words `CONTEXT.md` tells you to avoid
/// for a Standing. They are borrowed here for appearances and say nothing about
/// whose move it is — see the glossary's Tone entry.
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
