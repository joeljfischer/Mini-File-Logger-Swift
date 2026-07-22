import CoreData
import SwiftUI

struct LogTableView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var entries: FetchedResults<StoredLogEntry>
    @FetchRequest private var unfilteredEntries: FetchedResults<StoredLogEntry>

    @Binding var selectedEntryID: NSManagedObjectID?
    @State private var selectedEntryIsVisible = false

    private let session: LogSession
    private let searchText: String
    private let minimumLevel: MinimumLogLevel
    private let selectionContext: String

    init(
        session: LogSession,
        searchText: String,
        minimumLevel: MinimumLogLevel,
        selectedEntryID: Binding<NSManagedObjectID?>
    ) {
        self.session = session
        self.searchText = searchText
        self.minimumLevel = minimumLevel
        _selectedEntryID = selectedEntryID
        selectionContext = [
            session.objectID.uriRepresentation().absoluteString,
            searchText,
            minimumLevel.rawValue,
        ].joined(separator: "|")

        let filteredRequest = Self.filteredRequest(
            session: session,
            searchText: searchText,
            minimumLevel: minimumLevel
        )
        _entries = FetchRequest(fetchRequest: filteredRequest, animation: .default)

        let existenceRequest = StoredLogEntry.fetchRequest()
        existenceRequest.predicate = NSPredicate(format: "session == %@", session)
        existenceRequest.sortDescriptors = [
            NSSortDescriptor(key: "lineNumber", ascending: true)
        ]
        existenceRequest.fetchLimit = 1
        existenceRequest.fetchBatchSize = 1
        existenceRequest.includesPropertyValues = false
        _unfilteredEntries = FetchRequest(
            fetchRequest: existenceRequest,
            animation: .default
        )
    }

    var body: some View {
        Group {
            if entries.isEmpty {
                emptyView
            } else {
                tableAndDetail
            }
        }
        .task(id: selectionContext) {
            reconcileSelection()
        }
        .onChange(of: entries.count) {
            reconcileSelection()
        }
    }

    private var tableAndDetail: some View {
        VSplitView {
            Table(of: LogTableRow.self, selection: tableSelection) {
                TableColumn("Level") { row in
                    Text(levelText(for: row.entry))
                        .accessibilityIdentifier(
                            "logRowLevel-\(row.entry.lineNumber)"
                        )
                }
                .width(min: 70, ideal: 90, max: 120)

                TableColumn("Timestamp") { row in
                    Text(timestampText(for: row.entry))
                        .font(.body.monospacedDigit())
                }
                .width(min: 140, ideal: 175, max: 210)

                TableColumn("Category") { row in
                    Text(row.entry.category.isEmpty ? "—" : row.entry.category)
                        .lineLimit(1)
                }
                .width(min: 100, ideal: 150)

                TableColumn("Message") { row in
                    Text(row.entry.message)
                        .lineLimit(1)
                }
            } rows: {
                ForEach(entries, id: \.objectID) { entry in
                    TableRow(LogTableRow(entry: entry))
                }
            }
            .accessibilityIdentifier("logTable")
            .frame(minHeight: 220)

            Group {
                if let selectedEntry {
                    LogDetailView(entry: selectedEntry)
                        .id(selectedEntry.objectID)
                } else {
                    Color.clear
                }
            }
            .frame(minHeight: 140, idealHeight: 240)
        }
    }

    private var tableSelection: Binding<NSManagedObjectID?> {
        Binding(
            get: { selectedEntryID },
            set: { selection in
                selectedEntryID = selection
                selectedEntryIsVisible = selection != nil
            }
        )
    }

    private var selectedEntry: StoredLogEntry? {
        guard selectedEntryIsVisible,
              let selectedEntryID,
              let object = try? viewContext.existingObject(with: selectedEntryID)
        else {
            return nil
        }
        return object as? StoredLogEntry
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label(
                unfilteredEntries.isEmpty ? "No Log Entries" : "No Matching Entries",
                systemImage: unfilteredEntries.isEmpty
                    ? "doc.text"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reconcileSelection() {
        guard let firstEntryID = entries.first?.objectID else {
            selectedEntryID = nil
            selectedEntryIsVisible = false
            return
        }

        guard let selectedEntryID,
              let selectedObject = (try? viewContext.existingObject(
                with: selectedEntryID
              )) as? StoredLogEntry
        else {
            self.selectedEntryID = firstEntryID
            selectedEntryIsVisible = true
            return
        }

        let request = Self.filteredRequest(
            session: session,
            searchText: searchText,
            minimumLevel: minimumLevel
        )
        let selectionPredicate = NSPredicate(format: "SELF == %@", selectedObject)
        let filteredPredicate = request.predicate ?? NSPredicate(value: true)
        request.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [filteredPredicate, selectionPredicate]
        )
        request.fetchLimit = 1

        if (try? viewContext.count(for: request)) == 1 {
            selectedEntryIsVisible = true
        } else {
            self.selectedEntryID = firstEntryID
            selectedEntryIsVisible = true
        }
    }

    private static func filteredRequest(
        session: LogSession,
        searchText: String,
        minimumLevel: MinimumLogLevel
    ) -> NSFetchRequest<StoredLogEntry> {
        let request = StoredLogEntry.filteredFetchRequest(
            searchText: searchText,
            minimumLevel: minimumLevel
        )
        let sessionPredicate = NSPredicate(format: "session == %@", session)
        if let filterPredicate = request.predicate {
            request.predicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [sessionPredicate, filterPredicate]
            )
        } else {
            request.predicate = sessionPredicate
        }
        return request
    }

    private func levelText(for entry: StoredLogEntry) -> String {
        guard let code = entry.levelCode else { return "Unknown" }
        return LogLevel(rawValue: code)?.displayName ?? code
    }

    private func timestampText(for entry: StoredLogEntry) -> String {
        entry.timestamp?.formatted(
            .dateTime
                .year()
                .month(.twoDigits)
                .day(.twoDigits)
                .hour()
                .minute()
                .second()
                .secondFraction(.fractional(3))
        ) ?? "—"
    }
}

private struct LogTableRow: Identifiable {
    let entry: StoredLogEntry

    var id: NSManagedObjectID {
        entry.objectID
    }
}
