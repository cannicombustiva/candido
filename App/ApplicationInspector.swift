import CandidoCore
import SwiftData
import SwiftUI

/// The selected Application, open for editing.
///
/// Editing happens here and nowhere else — the table is not inline-editable.
/// Title, Status, the last-contact date, the posting URL and notes are all
/// editable. `appliedDate` and the Company are shown but not offered: the
/// applied date is set once, and a Company is never managed directly.
///
/// This is also where an Application becomes Archived (by taking a Terminal
/// Status) and where staleness is cleared (by moving the last-contact date).
/// Neither is a separate act.
struct ApplicationInspector: View {
    @Environment(\.modelContext) private var context

    /// `@Bindable` because Status, the last-contact date and notes have no
    /// rules of their own: they are bound straight to the model, so the table
    /// row restyles as the field changes, with no reselect.
    @Bindable var application: Application

    /// Title and URL are held as text first. The package decides what a typed
    /// title or a pasted link becomes, and refuses some of them — so the field
    /// has to be able to hold something the model does not.
    @State private var titleText: String
    @State private var jobURLText: String

    /// Half-typed text is not a link, so the URL is written when the field is
    /// left or submitted rather than on every keystroke — otherwise typing a
    /// new one would throw the stored one away at the first character.
    @FocusState private var jobURLFieldIsFocused: Bool

    @State private var failure: String?

    init(application: Application) {
        self.application = application
        _titleText = State(initialValue: application.title)
        _jobURLText = State(initialValue: application.jobURLText)
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Company", value: application.company.name)

                TextField("Title", text: $titleText)
                    .onChange(of: titleText) { commitTitle() }
                if !Application.canRename(to: titleText) {
                    Text("A title is how the row is recognised — the last one is kept.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Status", selection: $application.status) {
                    ForEach(Status.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                .onChange(of: application.status) { save() }
            }

            Section {
                LabeledContent("Applied") {
                    Text(application.appliedDate, format: .dateTime.day().month(.abbreviated).year())
                }

                DatePicker(
                    "Last contact",
                    selection: $application.lastContactDate,
                    displayedComponents: .date
                )
                .onChange(of: application.lastContactDate) { save() }
            }

            Section {
                TextField("Job URL", text: $jobURLText, prompt: Text("https://"))
                    .focused($jobURLFieldIsFocused)
                    .onSubmit { commitJobURL() }
                    .onChange(of: jobURLFieldIsFocused) { _, isFocused in
                        if !isFocused { commitJobURL() }
                    }
                if let url = application.jobURL {
                    Link("Open posting", destination: url)
                        .font(.caption)
                }
            } header: {
                Text("Posting")
            } footer: {
                Text("Postings vanish. Keep the link to reread the description before a call.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notes") {
                TextEditor(text: $application.notes)
                    .frame(minHeight: 140)
                    .font(.body)
                    .onChange(of: application.notes) { save() }
            }

            if let failure {
                Text(failure)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
        // Selecting another row replaces this view, taking a URL that was
        // typed but never submitted with it unless it is written first.
        .onDisappear { commitJobURL() }
    }

    private func commitTitle() {
        application.rename(to: titleText)
        save()
    }

    private func commitJobURL() {
        application.setJobURL(fromText: jobURLText)
        save()
    }

    /// SwiftData autosaves, but a relaunch right after a keystroke is exactly
    /// the case the owner will hit, so each edit is written through.
    ///
    /// A failure is shown rather than swallowed: an edit that never reached
    /// the store would otherwise look exactly like one that did.
    private func save() {
        do {
            try context.save()
            failure = nil
        } catch {
            failure = "Could not save the change: \(error.localizedDescription)"
        }
    }
}
