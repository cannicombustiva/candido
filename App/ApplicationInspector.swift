import JobTrackerCore
import SwiftData
import SwiftUI

/// The selected Application, open for editing.
///
/// Editing happens here and nowhere else — the table is not inline-editable.
/// Every field an Application has is here except `appliedDate`, which is set
/// once and so is shown but not offered.
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

                if application.isStale() {
                    Label(
                        "Silent for \(application.daysOfSilence()) days.",
                        systemImage: "clock.badge.exclamationmark"
                    )
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Section {
                TextField("Job URL", text: $jobURLText, prompt: Text("https://"))
                    .onChange(of: jobURLText) { commitJobURL() }
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
        }
        .formStyle(.grouped)
        .inspectorColumnWidth(min: 260, ideal: 300, max: 420)
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
    /// the case the acceptance criteria name, so each edit is written through.
    private func save() {
        try? context.save()
    }
}
