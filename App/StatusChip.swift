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
            // A tint at both strengths rather than a solid fill: the same hue
            // reads on the label and behind it, in light appearance and dark,
            // without the white-on-pale-blue the pipeline's palest tone would
            // otherwise need.
            .background(status.tone.color.opacity(0.18), in: .capsule)
            .foregroundStyle(status.tone.color)
    }
}

extension Tone {
    /// The one place a tone becomes a color.
    ///
    /// The three waiting tones deepen through the blues in pipeline order, so
    /// how far along a row is reads off the shade. Orange is absent on
    /// purpose — it belongs to Stale, on the last-contact date and nowhere
    /// else.
    fileprivate var color: Color {
        switch self {
        case .pending: .cyan
        case .moving: .blue
        case .deep: .indigo
        case .yours: .green
        case .spent: .gray
        }
    }
}
