/// How pale a chip reads, relative to the others.
///
/// `SPEC.md` requires exactly one shade difference: `applied` is a pale blue
/// and `screening` a medium blue of the same hue. Nothing else in the contract
/// is required to differ by shade, so nothing else does here — `interviewing`
/// is told apart by its hue, and a second step would re-encode the
/// distance-along reading the contract rejects (candido#86).
///
/// Ordered, so the requirement is expressible as `pale < standard` rather than
/// as two opacities a test would have to know. The opacities themselves are the
/// view's: how much paler a pale chip renders is a question about contrast on a
/// particular capsule, and answering it here would pull rendering into the
/// package.
///
/// `Comparable` is safe only while there are two cases: `pale < standard` is
/// then the single required relation and nothing more. A third case would make
/// the declaration order load-bearing and turn this into the scale the contract
/// does not have — so if one is ever needed, drop `Comparable` first and make
/// the tests say which pairs differ.
public enum Shade: Comparable, Sendable {
    /// The paler of the two. `applied` only.
    case pale

    /// Everything else. Not "dark" — it is the absence of a required
    /// difference, not a second point on a scale.
    case standard
}

extension Tone {
    /// How pale this tone reads. See `Shade`.
    public var shade: Shade {
        switch self {
        case .pending: .pale
        case .moving, .deep, .yours, .spent: .standard
        }
    }
}
