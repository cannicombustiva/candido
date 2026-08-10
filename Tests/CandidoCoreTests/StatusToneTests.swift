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

    /// Hue comes from Standing — that is the whole reason the tones are worth
    /// having. This holds for every Status, including any added later: a new
    /// Status that stands Over cannot be given a waiting tone, and one that
    /// awaits their reply cannot borrow the green that means the move is the
    /// owner's.
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
