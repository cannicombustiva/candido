import Testing

@testable import JobTrackerCore

/// Standing is the only classification of Status. These tests are about the
/// classification itself, not about any Application, so they need no store.
@Suite("Standing")
struct StandingTests {
    /// The guarantee the Stale filter used to defend by hand: a Status that is
    /// over is not also waiting on somebody. One switch decides both, so this
    /// holds for every Status, including any added later.
    @Test(arguments: Status.allCases)
    func terminalIsExactlyOver(_ status: Status) {
        #expect(status.isTerminal == (status.standing == .over))

        if status.isTerminal, case .awaitingTheirReply = status.standing {
            Issue.record("\(status) is Terminal and awaiting their reply at once")
        }
    }

    /// Every Status that tolerates silence tolerates a positive number of days.
    /// A zero or negative tolerance would make an Application Stale the moment
    /// it was entered.
    @Test(arguments: Status.allCases)
    func toleranceIsPositiveWhereItExists(_ status: Status) {
        guard case .awaitingTheirReply(let tolerated) = status.standing else { return }

        #expect(tolerated > 0)
    }
}
