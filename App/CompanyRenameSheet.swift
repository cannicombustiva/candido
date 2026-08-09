import CandidoCore
import SwiftData
import SwiftUI

/// Correcting the name a Company was first typed under.
///
/// This is the only place a Company is edited, and it is still not a company
/// screen: it opens from one row's inspector, names one Company, and closes.
///
/// The view decides nothing. `CompanyRenamePlan` works out whether the typed
/// name is a correction or a merge, how many Applications it touches, and what
/// to say about it — so what the owner reads and what the button does are the
/// same object, and `swift test` can read the words.
struct CompanyRenameSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let company: Company

    @State private var typedName: String
    @State private var failure: String?

    init(company: Company) {
        self.company = company
        _typedName = State(initialValue: company.name)
    }

    /// `nil` when the package will not plan this rename. The button goes with
    /// it, so a refusal is visible before it is attempted.
    private var plan: CompanyRenamePlan? {
        try? company.planRename(to: typedName, in: context)
    }

    /// Why there is no plan, in the owner's terms.
    ///
    /// A blank name and a store that could not be read are told apart rather
    /// than both reported as a typing mistake — the owner can fix the first and
    /// can only be misled by being blamed for the second.
    private var refusal: String? {
        guard plan == nil else { return nil }
        return Company.isKeepableName(typedName)
            ? "Could not work out what renaming this would do."
            : "A company name has to have something in it."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rename Company")
                .font(.headline)

            TextField("Company name", text: $typedName)
                .textFieldStyle(.roundedBorder)
                .onSubmit { commit() }

            Text(plan?.message ?? refusal ?? "")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let failure {
                Text(failure)
                    .font(.callout)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                // The word on the button is the plan's, because agreeing to
                // "Rename" must never perform a merge.
                Button(plan?.confirmation ?? "Rename") { commit() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(plan == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }

    private func commit() {
        guard let plan else { return }
        plan.apply(in: context)
        failure = context.saveOrDescribeFailure()
        // Left open on failure rather than dismissed: a merge that did not
        // reach the store must not look like one that did.
        if failure == nil { dismiss() }
    }
}
