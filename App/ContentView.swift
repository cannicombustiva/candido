import CandidoCore
import SwiftData
import SwiftUI

/// The single window: sidebar filters, the table of Applications, and the
/// inspector the selected one is edited in.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var applications: [Application]

    @State private var sortOrder = [ApplicationSortField.lastContactDate.comparator(.forward)]
    @State private var selection: Application.ID?
    @State private var isAddingApplication = false
    @State private var filter = ApplicationFilter.all

    /// The Application the owner has asked to delete, held until they confirm.
    /// Deleting is the one thing here with no undo, so it is never one
    /// keystroke away from done.
    @State private var applicationToDelete: Application?

    /// Advances at local midnight, so a window left open overnight re-derives
    /// staleness instead of showing yesterday's answer. Read by the filter and
    /// by the date column alike — one Today, instant and calendar together, so
    /// they cannot disagree about what day it is or which timezone it is in.
    @State private var day = DayClock()

    private var visibleApplications: [Application] {
        filter.narrow(applications, asOf: day.today).sorted(using: sortOrder)
    }

    /// The selected row's Application, or `nil` when nothing is selected.
    /// Looked up across every Application rather than the visible ones: giving
    /// a Status a Terminal value moves the row out of the Active filter, and
    /// the panel should not blank out from under the edit that did it.
    private var selectedApplication: Application? {
        applications.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            FilterSidebar(filter: $filter)
        } detail: {
            ApplicationTable(
                applications: visibleApplications,
                today: day.today,
                sortOrder: $sortOrder,
                selection: $selection,
                delete: { applicationToDelete = $0 }
            )
            .navigationTitle(filter.displayName)
            .inspector(isPresented: .constant(true)) {
                if let selectedApplication {
                    // Keyed on the row: the inspector holds the title and URL
                    // as text, and that text belongs to one Application.
                    ApplicationInspector(application: selectedApplication)
                        .id(selectedApplication.id)
                } else {
                    ContentUnavailableView(
                        "No application selected",
                        systemImage: "sidebar.right",
                        description: Text("Select a row to read and edit it.")
                    )
                }
            }
            .toolbar {
                ToolbarItem {
                    Button {
                        isAddingApplication = true
                    } label: {
                        Label("Add Application", systemImage: "plus")
                    }
                    .help("Add an application")
                    .keyboardShortcut("n", modifiers: .command)
                }
            }
        }
        .sheet(isPresented: $isAddingApplication) {
            AddApplicationSheet()
        }
        .confirmDeletion(of: $applicationToDelete) { application in
            application.remove(from: context)
            selection = nil
        }
        // What the File menu's Delete would act on right now. Nothing selected
        // publishes nothing, and the menu item greys out.
        .focusedValue(
            \.deleteApplicationRequest,
            selectedApplication.map { application in { applicationToDelete = application } }
        )
        .frame(minWidth: 820, minHeight: 420)
    }
}

extension View {
    /// Asks before deleting, and names what is about to go.
    ///
    /// There is no undo and no trash: the row is the owner's record of having
    /// applied somewhere, and the only protection against losing one to a
    /// mis-hit Delete key is being asked first, in words naming the actual row.
    fileprivate func confirmDeletion(
        of application: Binding<Application?>,
        delete: @escaping (Application) -> Void
    ) -> some View {
        confirmationDialog(
            application.wrappedValue.map { "Delete \($0.title) at \($0.company.name)?" } ?? "",
            isPresented: Binding(
                get: { application.wrappedValue != nil },
                set: { if !$0 { application.wrappedValue = nil } }
            ),
            presenting: application.wrappedValue
        ) { presented in
            Button("Delete", role: .destructive) {
                delete(presented)
                application.wrappedValue = nil
            }
            Button("Cancel", role: .cancel) { application.wrappedValue = nil }
        } message: { _ in
            Text("This cannot be undone.")
        }
    }
}

/// The four ways the list is narrowed. Which Applications each one holds is
/// the package's decision — the sidebar only picks one.
private struct FilterSidebar: View {
    @Binding var filter: ApplicationFilter

    var body: some View {
        List(ApplicationFilter.allCases, selection: $filter) { filter in
            Label(filter.displayName, systemImage: filter.symbolName)
                .tag(filter)
        }
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
    }
}

extension ApplicationFilter {
    fileprivate var symbolName: String {
        switch self {
        case .all: "tray.full"
        case .active: "flame"
        case .stale: "clock.badge.exclamationmark"
        case .archived: "archivebox"
        }
    }
}

/// The last-contact date, styled when the Application has gone quiet for
/// longer than its Status allows.
///
/// Stale rows are styled, never hidden: hiding them would let the owner
/// forget those companies exist.
private struct LastContactCell: View {
    let application: Application
    /// Passed in rather than built here: the sidebar filter narrows against one
    /// Today, and a cell that read the clock — or named a calendar — for itself
    /// could style a row the Stale filter had not yet picked up.
    let today: Today

    var body: some View {
        Text(application.lastContactDate, format: .dateTime.day().month(.abbreviated).year())
            .foregroundStyle(
                application.isStale(asOf: today) ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
    }
}

extension TableColumn where RowValue == Application, Sort == ApplicationComparator, Label == Text {
    /// A column headed and sorted by one sort field — the heading and the
    /// comparator come from the same declaration, so they cannot drift apart.
    fileprivate init(
        _ field: ApplicationSortField,
        @ViewBuilder content: @escaping (Application) -> Content
    ) {
        self.init(field.columnTitle, sortUsing: field.comparator(), content: content)
    }
}

private struct ApplicationTable: View {
    let applications: [Application]
    let today: Today
    @Binding var sortOrder: [ApplicationComparator]
    @Binding var selection: Application.ID?

    /// Asks for a row to be deleted. The table never deletes anything itself —
    /// it raises the question, and the window puts it to the owner.
    let delete: (Application) -> Void

    /// Each column names one sort field and takes both its heading and its
    /// comparator from it, so the view cannot label a column one thing and
    /// sort it by another. What the field orders on is the package's decision.
    var body: some View {
        Table(applications, selection: $selection, sortOrder: $sortOrder) {
            TableColumn(ApplicationSortField.company) {
                Text($0.company.name)
            }
            TableColumn(ApplicationSortField.title) {
                Text($0.title)
            }
            TableColumn(ApplicationSortField.status) {
                Text($0.status.displayName)
            }
            TableColumn(ApplicationSortField.appliedDate) {
                Text($0.appliedDate, format: .dateTime.day().month(.abbreviated).year())
            }
            TableColumn(ApplicationSortField.lastContactDate) { application in
                LastContactCell(application: application, today: today)
            }
        }
        .contextMenu(forSelectionType: Application.ID.self) { ids in
            // One row at a time: deleting several at once is a bigger promise
            // than one confirmation can honestly name.
            if let id = ids.first, ids.count == 1,
                let application = applications.first(where: { $0.id == id })
            {
                Button("Delete Application…", role: .destructive) {
                    delete(application)
                }
            }
        }
        .overlay {
            if applications.isEmpty {
                ContentUnavailableView(
                    "No applications yet",
                    systemImage: "briefcase",
                    description: Text("Add one with the + button.")
                )
            }
        }
    }
}
