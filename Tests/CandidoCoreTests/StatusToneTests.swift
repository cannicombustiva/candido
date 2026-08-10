import Testing

@testable import CandidoCore

/// The tone a Status carries in the table's chip. About the classification
/// itself, so no store is needed.
@Suite("Status tone")
struct StatusToneTests {
    /// The table from the contract, written out. Each pair is quoted from
    /// `SPEC.md`, not derived from `tone` — a test that recomputed the mapping
    /// could never disagree with it.
    @Test(
        arguments: [
            (Status.applied, Tone.pending),
            (Status.screening, Tone.moving),
            (Status.interviewing, Tone.deep),
            (Status.offer, Tone.yours),
            (Status.rejected, Tone.spent),
            (Status.withdrawn, Tone.spent),
        ])
    func statusCarriesItsContractTone(_ status: Status, _ expected: Tone) {
        #expect(status.tone == expected)
    }

    /// Tone refines Standing — that is the whole reason the tones are worth
    /// having. Which colour a Tone renders as is a separate question, answered
    /// by `SPEC.md`'s enumerated list; this test is about the partition, not
    /// the colours. It holds for every Status, including any added later: a new
    /// Status that stands Over cannot be given a waiting tone, and one that
    /// awaits their reply cannot borrow the green that means the move is the
    /// owner's.
    /// The one shade relation `SPEC.md` requires: `applied` is a pale blue and
    /// `screening` a medium blue of the same hue, so the chip for `applied`
    /// must read paler than the chip for `screening`.
    ///
    /// This is the decision, not the rendering. How much paler — the opacity a
    /// capsule ends up with — is the view's business and is not asserted here.
    @Test
    func appliedIsPalerThanScreening() {
        #expect(Status.applied.tone.shade < Status.screening.tone.shade)
    }

    /// `applied` is the only Status the contract makes pale. Every other one
    /// reads at the same weight, including `interviewing` — it is told apart by
    /// its hue, not by being darker still.
    ///
    /// This is the guard against re-encoding "shade is the distance along",
    /// which `SPEC.md` no longer says and candido#86 settled against. A second
    /// pale step added here would fail it.
    @Test(arguments: Status.allCases.filter { $0 != .applied })
    func nothingButAppliedIsPale(_ status: Status) {
        #expect(status.tone.shade == .standard)
    }

    @Test(arguments: Status.allCases)
    func toneAgreesWithStanding(_ status: Status) {
        switch status.standing {
        case .awaitingTheirReply:
            #expect([.pending, .moving, .deep].contains(status.tone))
        case .awaitingYourMove:
            #expect(status.tone == .yours)
        case .over:
            #expect(status.tone == .spent)
        }
    }
}
