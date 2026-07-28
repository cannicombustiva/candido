import CandidoCore
import SwiftUI

/// Asking to delete the selected row, from wherever the owner reaches for it.
///
/// The menu command lives outside the window, so it cannot see the selection
/// directly — the window publishes what deleting would mean right now, and this
/// is the channel it publishes on. When nothing is selected there is nothing to
/// publish, and the menu item greys out on its own.
struct DeleteApplicationRequest: FocusedValueKey {
    typealias Value = () -> Void
}

extension FocusedValues {
    var deleteApplicationRequest: DeleteApplicationRequest.Value? {
        get { self[DeleteApplicationRequest.self] }
        set { self[DeleteApplicationRequest.self] = newValue }
    }
}

/// The File menu's entry for deleting the selected Application.
///
/// It asks rather than deletes: the request opens the confirmation the window
/// owns, so the Delete key and the row's own menu end in the same question.
struct ApplicationCommands: Commands {
    @FocusedValue(\.deleteApplicationRequest) private var requestDeletion

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Delete Application…") {
                requestDeletion?()
            }
            .keyboardShortcut(.delete, modifiers: [])
            .disabled(requestDeletion == nil)
        }
    }
}
