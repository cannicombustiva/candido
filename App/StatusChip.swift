import CandidoCore
import SwiftUI

/// The Status column's chip: the word, in a capsule tinted by the Status's
/// tone.
///
/// The word stays inside the capsule. Color alone is unreadable to anyone who
/// cannot separate these hues, and the column is a sort key — the text has to
/// be there to be sorted by and read.
///
/// Which tone a Status carries is `CandidoCore`'s decision. Turning a tone into
/// a `Color` is this view's, and so — for now, wrongly — is how strongly each
/// tone fills its capsule: that decision belongs in the package where the tests
/// reach it, and moving it is #87's first item, blocked on #86.
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
    /// The same paragraph of `SPEC.md` also says "hue is the standing", which
    /// `interviewing`'s indigo contradicts. #86 decides which of the two the
    /// chip should obey; until it does, this map follows the enumerated
    /// colours. Orange is absent on purpose: it belongs to Stale, on the
    /// last-contact date and nowhere else.
    fileprivate var color: Color {
        switch self {
        case .pending, .moving: .blue
        case .deep: .indigo
        case .yours: .green
        case .spent: .gray
        }
    }

    /// The shade: how strongly the capsule is filled.
    ///
    /// Only `pending` and `moving` differ, giving `applied` and `screening` the
    /// pale and medium the contract names. Everything else sits at one weight,
    /// `deep` included — so the fills do not deepen along the pipeline, which is
    /// half of what #86 is open about. The other three hues already tell each
    /// other apart, and varying their fills too would imply an ordering between
    /// grey and green that the pipeline does not have.
    fileprivate var fill: Double {
        switch self {
        case .pending: 0.10
        case .moving: 0.34
        case .deep, .yours, .spent: 0.18
        }
    }
}
