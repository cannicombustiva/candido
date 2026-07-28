import Foundation
import SwiftData

extension Application {
    /// Deletes this Application, and the Company behind it if that was the last
    /// thing applied for there.
    ///
    /// There is no undo, so the whole rule lives here rather than in the view:
    /// one Application goes, and nothing else does unless it has stopped
    /// meaning anything.
    public func remove(from context: ModelContext) {
        let company = self.company
        context.delete(self)
        company.clearAwayIfEmpty(from: context)
    }
}

extension Application {
    /// Whether this Application has been deleted and is only waiting for the
    /// context to work through it. Nothing should count it as work any more.
    var isGoing: Bool {
        isDeleted || modelContext == nil
    }
}

extension Company {
    /// Drops this Company if it is holding nothing.
    ///
    /// A Company is not work. It is never managed directly, exists only because
    /// something was applied for there, and once the last Application has gone
    /// it appears in no screen and in no filter — but it would still be written
    /// to every backup from then on, so the file slowly fills with names
    /// nothing was ever applied for.
    ///
    /// The emptiness check is the whole safeguard: the relationship cascades,
    /// so deleting a Company that still held work would take that work with it.
    ///
    /// What counts as holding nothing is "no Application still standing", not
    /// "no Application listed". A deleted Application stays in this list until
    /// the context works through the deletion, so a Company emptied by two
    /// deletions in a row would otherwise look occupied by the first of them
    /// and survive — invisible, and in every backup from then on.
    func clearAwayIfEmpty(from context: ModelContext) {
        guard applications.allSatisfy(\.isGoing) else { return }
        context.delete(self)
    }
}
