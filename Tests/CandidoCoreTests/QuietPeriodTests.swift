import Foundation
import Testing

@testable import CandidoCore

/// A backup per keystroke would put a folder full of half-typed notes into
/// Google Drive, so what matters is that a burst of edits ends in one run.
@MainActor
struct QuietPeriodTests {
    /// Counts runs. A class, so the closure and the assertions see the same
    /// count.
    final class Runs {
        var count = 0
    }

    @Test("A burst of changes runs the work once, not once each")
    func collapsesABurst() async {
        let runs = Runs()
        let period = QuietPeriod(wait: { _ in })

        for _ in 1...5 {
            period.whenSettled { runs.count += 1 }
        }
        await period.settle()

        #expect(runs.count == 1)
    }

    @Test("Nothing runs until the quiet period has passed")
    func waitsForTheQuiet() async {
        let runs = Runs()
        let period = QuietPeriod(wait: { _ in try await Task.sleep(for: .milliseconds(50)) })

        period.whenSettled { runs.count += 1 }
        #expect(runs.count == 0)

        await period.settle()
        #expect(runs.count == 1)
    }

    @Test("A change after the quiet has passed starts a new wait")
    func runsAgainForLaterChanges() async {
        let runs = Runs()
        let period = QuietPeriod(wait: { _ in })

        period.whenSettled { runs.count += 1 }
        await period.settle()
        period.whenSettled { runs.count += 1 }
        await period.settle()

        #expect(runs.count == 2)
    }

    @Test("The quiet it waits for is the quiet it was given")
    func waitsTheGivenDuration() async {
        let waited = Waited()
        let period = QuietPeriod(of: .seconds(7), wait: { waited.duration = $0 })

        period.whenSettled {}
        await period.settle()

        #expect(waited.duration == .seconds(7))
    }

    @Test("Backups wait two seconds, as the spec says")
    func backsUpAfterTwoSeconds() {
        #expect(QuietPeriod.beforeBackup == .seconds(2))
    }

    /// What the wait was asked for, captured out of the closure.
    final class Waited: @unchecked Sendable {
        var duration: Duration?
    }
}
