import CandidoCore
import Foundation
import SwiftData
import SwiftUI

/// Keeps the chosen folder holding a current copy of everything.
///
/// It listens to the store rather than to the views: every screen that can
/// change an Application already ends in a save, so there is exactly one place
/// to hook, and no view has to remember to ask for a backup.
///
/// One machine writes, and the file is a snapshot — this is backup, not sync.
@Observable
@MainActor
final class BackupMirror {
    let folder: BackupFolder

    private let context: ModelContext
    private let quietPeriod = QuietPeriod()
    /// Held only so the subscription stays alive. There is one mirror and it
    /// lives as long as the app does, so it is never unsubscribed.
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init(context: ModelContext, folder: BackupFolder = BackupFolder()) {
        self.context = context
        self.folder = folder

        observer = NotificationCenter.default.addObserver(
            forName: ModelContext.didSave, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.scheduleWrite() }
        }
    }

    /// Asks for a folder, and backs up into it immediately once there is one —
    /// otherwise a folder chosen today would sit empty until the next edit,
    /// which reads as a feature that does not work.
    func chooseFolder() {
        if folder.choose() { writeNow() }
    }

    /// Waits for the store to go quiet, then writes — so a burst of edits
    /// produces a single file. The waiting rule itself lives in `QuietPeriod`,
    /// where the tests can drive it.
    private func scheduleWrite() {
        guard folder.isChosen else { return }
        quietPeriod.whenSettled { [weak self] in self?.writeNow() }
    }

    /// Reads the whole store and writes it out. Nothing leaves the app before
    /// a folder has been chosen.
    private func writeNow() {
        guard folder.isChosen else { return }

        do {
            let json = try BackupSnapshot(of: context).json()
            folder.write(json, named: BackupSnapshot.fileName)
        } catch {
            folder.problem = .writeFailed(error.localizedDescription)
        }
    }
}
