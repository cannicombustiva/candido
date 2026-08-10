import CandidoCore
import SwiftUI

/// The Status column's chip: the word, in a capsule tinted by the Status's
/// tone.
///
/// The word stays inside the capsule. Color alone is unreadable to anyone who
/// cannot separate these hues, and the column is a sort key — the text has to
/// be there to be sorted by and read.
///
/// Which tone a Status carries, and which tone is the pale one, are both
/// `CandidoCore`'s decisions and are tested there. This view turns them into a
/// `Color` and an opacity and decides nothing else.
struct StatusChip: View {
    let status: Status

    var body: some View {
        Text(status.displayName)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            // The hue is on the label, the shade is in the fill behind it. A
            // literally pale label — blue mixed toward white — computes to
            // about 2.5:1 against a light background, which is unreadable, and
            // the word is the part that has to survive. Holding the label at
            // one blue and moving the fill keeps `applied` paler than
            // `screening` in both appearances without spending the contrast.
            .background(status.tone.color.opacity(status.tone.fill), in: .capsule)
            .foregroundStyle(status.tone.color)
    }
}

extension Tone {
    /// The hue: which colour the tone is.
    ///
    /// One blue for both `applied` and `screening`, indigo, green, one shared
    /// grey. `SPEC.md` enumerates a *pale* blue and a *medium* blue; the pale
    /// and medium live in `fill` below rather than in two hues, because a
    /// literally pale label is unreadable.
    ///
    /// The list is the whole contract — `SPEC.md` says to read it as a list and
    /// not as a rule, so `interviewing`'s indigo is not a promise that hue
    /// tracks standing, and nothing here should be generalised. That was #86,
    /// and it is settled. Orange is absent on purpose: it belongs to Stale, on
    /// the last-contact date and nowhere else.
    fileprivate var color: Color {
        switch self {
        case .pending, .moving: .blue
        case .deep: .indigo
        case .yours: .green
        case .spent: .gray
        }
    }

    /// How strongly the capsule is filled. Which tone is the pale one is
    /// `CandidoCore`'s decision and is tested there; this turns that decision
    /// into a number, and then makes one further choice of its own.
    ///
    /// The standard weights are not a second shade step. They differ because a
    /// medium blue needs more fill to separate from a pale blue of the same hue
    /// than indigo, green or grey need from anything — a contrast problem, not
    /// a position in the pipeline. `SPEC.md` requires no difference between
    /// them and none should be read into these numbers.
    fileprivate var fill: Double {
        switch (shade, self) {
        case (.pale, _): 0.10
        case (.standard, .moving): 0.34
        case (.standard, _): 0.18
        }
    }
}
