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
/// Status) and where staleness is cleared — either by moving the last-contact
/// date, or by changing the Status, which is Contact and moves that date with
/// it. Neither archiving nor clearing is a separate act.
struct ApplicationInspector: View {
    @Environment(\.modelContext) private var context

    /// `@Bindable` because the last-contact date and notes have no rules of
    /// their own: they are bound straight to the model, so the table row
    /// restyles as the field changes, with no reselect. Status is bound
    /// through `statusSelection` below — it does have a rule.
    @Bindable var application: Application

    /// The day this window is deriving against, from the window's one
    /// `DayClock`. A Status change stamps the last-contact date with it, so the
    /// stamp and the staleness the table styles against cannot disagree about
    /// what day it is — not by agreement, but because there is one value.
    let today: Today

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

    @State private var isRenaming = false

    init(application: Application, today: Today) {
        self.application = application
        self.today = today
        _titleText = State(initialValue: application.title)
        _jobURLText = State(initialValue: application.jobURLText)
    }

    var body: some View {
        Form {
            Section {
                // Read-only still — a Company is never managed directly. The
                // one thing offered is a correction to a name that would
                // otherwise be permanent.
                LabeledContent("Company") {
                    HStack(spacing: 8) {
                        Text(application.company.name)
                        Button("Rename…") { isRenaming = true }
                            .buttonStyle(.link)
                    }
                }

                TextField("Title", text: $titleText)
                    .onChange(of: titleText) { commitTitle() }
                if !Application.canRename(to: titleText) {
                    Text("A title is how the row is recognised — the last one is kept.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Picker("Status", selection: statusSelection) {
                    ForEach(Status.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
            }

            Section {
                LabeledContent("Applied") {
                    Text(application.appliedDate, format: .dateTime.day().month(.abbreviated).year())
                }

                DatePicker(
                    "Last contact",
                    selection: lastContactSelection,
                    displayedComponents: .date
                )
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
        .sheet(isPresented: $isRenaming) {
            CompanyRenameSheet(company: application.company)
        }
    }

    /// The Status picker, routed through the act rather than bound to the
    /// field.
    ///
    /// A Status change is Contact, and what that means lives in `CandidoCore`
    /// where `swift test` can reach it — the picker only has to call it. The
    /// date field below keeps its direct binding on purpose: overriding the
    /// stamp is the point of it.
    private var statusSelection: Binding<Status> {
        Binding(
            get: { application.status },
            set: { newStatus in
                application.changeStatus(to: newStatus, asOf: today)
                save()
            }
        )
    }

    /// The last-contact date, saved when the owner moves it.
    ///
    /// Bound through a setter rather than watched with `onChange`, because a
    /// Status change writes this field too: watching it would save a second
    /// time for one edit. Correcting the stamped date is still the point of
    /// this field — it writes the model directly, exactly as before.
    private var lastContactSelection: Binding<Date> {
        Binding(
            get: { application.lastContactDate },
            set: { newDate in
                application.lastContactDate = newDate
                save()
            }
        )
    }

    private func commitTitle() {
        application.rename(to: titleText)
        save()
    }

    private func commitJobURL() {
        application.setJobURL(fromText: jobURLText)
        save()
    }

    private func save() {
        failure = context.saveOrDescribeFailure()
    }
}
