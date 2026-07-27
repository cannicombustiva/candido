import Foundation

/// Waits for changes to stop coming, then does the work once.
///
/// Typing a note is dozens of changes, and each one is not a backup. Work
/// asked for while an earlier request is still waiting *replaces* it rather
/// than joining it, so a burst of edits ends in a single run.
///
/// It lives here rather than in the app because "one write, not one per
/// keystroke" is a claim the owner cannot check by reading Swift — the tests
/// drive it with their own clock and no real waiting.
@MainActor
public final class QuietPeriod {
    /// How long the store has to sit still before a backup is written. Long
    /// enough that a burst of edits collapses into one write, short enough
    /// that the file is current by the time the owner has looked away.
    public static let beforeBackup: Duration = .seconds(2)

    private let duration: Duration
    private let wait: @Sendable (Duration) async throws -> Void
    private var pending: Task<Void, Never>?

    /// - Parameter wait: how the quiet is waited out. Tests pass their own so
    ///   they neither sleep nor depend on how fast the machine is.
    public init(
        of duration: Duration = QuietPeriod.beforeBackup,
        wait: @escaping @Sendable (Duration) async throws -> Void = {
            try await Task.sleep(for: $0)
        }
    ) {
        self.duration = duration
        self.wait = wait
    }

    /// Runs `work` once the quiet period has passed with nothing else asked
    /// for. Anything already waiting is dropped.
    public func whenSettled(_ work: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task { [duration, wait] in
            try? await wait(duration)
            guard !Task.isCancelled else { return }
            work()
        }
    }

    /// Waits for any pending work to finish. Only tests need this — the app
    /// never waits for a backup.
    public func settle() async {
        await pending?.value
    }
}
