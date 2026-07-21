import JobTrackerCore
import SwiftData
import SwiftUI

/// Adding is a sheet, never a blank row appended to the table.
///
/// Typing a company name that has been seen before — in any casing — attaches
/// the new Application to the existing Company. There is no company picker
/// because there is no managing of companies.
struct AddApplicationSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var companyName = ""
    @State private var title = ""
    @State private var status = Status.applied
    @State private var appliedDate = Date()
    @State private var failure: String?

    private var canSave: Bool {
        Application.canCreate(companyName: companyName, title: title)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Application").font(.headline)

            Form {
                TextField("Company", text: $companyName)
                TextField("Title", text: $title)
                Picker("Status", selection: $status) {
                    ForEach(Status.allCases, id: \.self) { status in
                        Text(status.displayName).tag(status)
                    }
                }
                DatePicker("Applied", selection: $appliedDate, displayedComponents: .date)
            }
            .formStyle(.grouped)

            if let failure {
                Text(failure).foregroundStyle(.red).font(.callout)
            }

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { add() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    private func add() {
        do {
            try Application.create(
                companyNamed: companyName,
                title: title,
                status: status,
                appliedDate: appliedDate,
                in: context
            )
            try context.save()
            dismiss()
        } catch {
            failure = "Could not add the application: \(error.localizedDescription)"
        }
    }
}
