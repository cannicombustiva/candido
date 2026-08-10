import CandidoCore
import SwiftUI

/// The Status column's chip: the word, in a capsule tinted by the Status's
/// tone.
///
/// The word stays inside the capsule. Color alone is unreadable to anyone who
/// cannot separate these hues, and the column is a sort key — the text has to
/// be there to be sorted by and read.
///
/// Which tone a Status carries is `CandidoCore`'s decision. This view only
/// turns a tone into a `Color`, so no view ever decides what a Status means.
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
    /// `applied` and `screening` share one blue on purpose — hue is the
    /// Standing, and they share a Standing. `interviewing` is indigo because
    /// the contract names indigo. Orange is absent on purpose: it belongs to
    /// Stale, on the last-contact date and nowhere else.
    fileprivate var color: Color {
        switch self {
        case .pending, .moving: .blue
        case .deep: .indigo
        case .yours: .green
        case .spent: .gray
        }
    }

    /// The shade: how strongly the capsule is filled, which is how far along
    /// the pipeline the row is.
    ///
    /// Only the two blues differ — the pale/medium pair the contract asks for.
    /// The rest sit at one weight, because their hues already tell them apart
    /// and varying the fill as well would imply an ordering between grey and
    /// green that the pipeline does not have.
    fileprivate var fill: Double {
        switch self {
        case .pending: 0.10
        case .moving: 0.34
        case .deep, .yours, .spent: 0.18
        }
    }
}
