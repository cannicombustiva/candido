import Foundation

/// Whose move it is, and whether the Application is still in play.
///
/// This is the only classification of Status in the package. Terminal, "awaits
/// their reply" and the staleness threshold were three separate answers to the
/// same question and could drift apart; here they are one switch, so a Status
/// cannot be over and awaiting a reply at once.
///
/// The threshold rides on the case that has one. There is no "no threshold"
/// state to encode as `nil`: a Status that is not awaiting their reply has no
/// silence to tolerate, and the type says so.
public enum Standing: Equatable, Sendable {
    /// The next move belongs to the company. Silence longer than
    /// `silenceTolerated` calendar days reads as Stale.
    case awaitingTheirReply(silenceTolerated: Int)

    /// The next move belongs to the owner. Still live — an `offer` is Active —
    /// but it cannot go Stale, because nobody is failing to answer.
    case awaitingYourMove

    /// Over. The Application does not move on from here.
    case over
}

extension Status {
    /// Where this Status stands. The single source for Terminal, staleness and
    /// the filters.
    ///
    /// The thresholds differ on purpose — silence after a final interview is
    /// louder than silence after applying.
    public var standing: Standing {
        switch self {
        case .applied: .awaitingTheirReply(silenceTolerated: 21)
        case .screening: .awaitingTheirReply(silenceTolerated: 14)
        case .interviewing: .awaitingTheirReply(silenceTolerated: 10)
        case .offer: .awaitingYourMove
        case .rejected, .withdrawn: .over
        }
    }

    /// A Status the Application does not move on from. The owner never
    /// archives anything by hand — being Terminal *is* being archived.
    public var isTerminal: Bool {
        standing == .over
    }
}
