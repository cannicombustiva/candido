import JobTrackerCore
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

    /// Advances at local midnight, so a window left open overnight re-derives
    /// staleness instead of showing yesterday's answer. Read by the filter and
    /// by the date column alike — one instant, so they cannot disagree.
    @State private var day = DayClock()

    private var visibleApplications: [Application] {
        filter.narrow(applications, asOf: day.now).sorted(using: sortOrder)
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
                asOf: day.now,
                sortOrder: $sortOrder,
                selection: $selection
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
        .frame(minWidth: 820, minHeight: 420)
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
    /// Passed in rather than read as `Date()` here: the sidebar filter narrows
    /// against one instant, and a cell that asked the clock for itself could
    /// style a row the Stale filter had not yet picked up.
    let now: Date

    var body: some View {
        Text(application.lastContactDate, format: .dateTime.day().month(.abbreviated).year())
            .foregroundStyle(
                application.isStale(asOf: now) ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
    }
}

private struct ApplicationTable: View {
    let applications: [Application]
    let asOf: Date
    @Binding var sortOrder: [ApplicationComparator]
    @Binding var selection: Application.ID?

    var body: some View {
        Table(applications, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Company", sortUsing: ApplicationSortField.company.comparator()) {
                Text($0.company.name)
            }
            TableColumn("Title", sortUsing: ApplicationSortField.title.comparator()) {
                Text($0.title)
            }
            TableColumn("Status", sortUsing: ApplicationSortField.status.comparator()) {
                Text($0.status.displayName)
            }
            TableColumn("Applied", sortUsing: ApplicationSortField.appliedDate.comparator()) {
                Text($0.appliedDate, format: .dateTime.day().month(.abbreviated).year())
            }
            TableColumn(
                "Last contact", sortUsing: ApplicationSortField.lastContactDate.comparator()
            ) { application in
                LastContactCell(application: application, now: asOf)
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
