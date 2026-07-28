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
        company.clearAwayIfEmpty(disregarding: self, from: context)
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
    /// `leaving` is the Application on its way out, if there is one. A deleted
    /// Application still sits in this list until the context works through the
    /// deletion, so a caller that has just deleted one has to say so — asking
    /// the list alone would find the Company still occupied by a row that is
    /// already gone.
    func clearAwayIfEmpty(disregarding leaving: Application? = nil, from context: ModelContext) {
        guard applications.allSatisfy({ $0 === leaving }) else { return }
        context.delete(self)
    }
}
