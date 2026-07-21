import JobTrackerCore
import SwiftData
import SwiftUI

/// The single window: sidebar filters, the table of Applications, and (later)
/// the inspector.
struct ContentView: View {
    @Environment(\.modelContext) private var context
    @Query private var applications: [Application]

    @State private var sortOrder = [ApplicationSortField.lastContactDate.comparator(.forward)]
    @State private var selection: Application.ID?
    @State private var isAddingApplication = false

    var body: some View {
        NavigationSplitView {
            FilterSidebar()
        } detail: {
            ApplicationTable(
                applications: applications.sorted(using: sortOrder),
                sortOrder: $sortOrder,
                selection: $selection
            )
            .navigationTitle("Applications")
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

/// The four filters. Inert until the filtering ticket lands — showing them
/// disabled is honest about that; showing them live would lie.
private struct FilterSidebar: View {
    var body: some View {
        List {
            Label("All", systemImage: "tray.full")
            Label("Active", systemImage: "flame")
            Label("Stale", systemImage: "clock.badge.exclamationmark")
            Label("Archived", systemImage: "archivebox")
        }
        .disabled(true)
        .navigationSplitViewColumnWidth(min: 160, ideal: 180)
    }
}

/// The last-contact date, styled when the Application has gone quiet for
/// longer than its Status allows.
///
/// Stale rows are styled, never hidden: hiding them would let the owner
/// forget those companies exist.
private struct LastContactCell: View {
    let application: Application

    var body: some View {
        Text(application.lastContactDate, format: .dateTime.day().month(.abbreviated).year())
            .foregroundStyle(
                application.isStale() ? AnyShapeStyle(.orange) : AnyShapeStyle(.primary))
    }
}

private struct ApplicationTable: View {
    let applications: [Application]
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
                LastContactCell(application: application)
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
