import CoreData
import SwiftUI

struct LogTableView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest private var entries: FetchedResults<StoredLogEntry>
    @ObservedObject private var session: LogSession

    @Binding var selectedEntryID: NSManagedObjectID?

    init(
        session: LogSession,
        searchText: String,
        minimumLevel: MinimumLogLevel,
        selectedEntryID: Binding<NSManagedObjectID?>
    ) {
        _session = ObservedObject(wrappedValue: session)
        _selectedEntryID = selectedEntryID

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
        _entries = FetchRequest(fetchRequest: request, animation: .default)
    }

    var body: some View {
        if entries.isEmpty {
            emptyView
        } else {
            VSplitView {
                Table(tableRows, selection: $selectedEntryID) {
                    TableColumn("Level") { row in
                        Text(levelText(for: row.entry))
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
                }
                .frame(minHeight: 220)

                Group {
                    if let selectedEntry {
                        LogDetailView(entry: selectedEntry)
                    } else {
                        Color.clear
                    }
                }
                .frame(minHeight: 140, idealHeight: 240)
            }
            .onChange(of: fetchedObjectIDs, initial: true) { _, objectIDs in
                if let selectedEntryID, objectIDs.contains(selectedEntryID) {
                    return
                }
                selectedEntryID = objectIDs.first
            }
        }
    }

    private var fetchedObjectIDs: [NSManagedObjectID] {
        entries.map(\.objectID)
    }

    private var tableRows: [LogTableRow] {
        entries.map(LogTableRow.init)
    }

    private var selectedEntry: StoredLogEntry? {
        guard let selectedEntryID,
              fetchedObjectIDs.contains(selectedEntryID),
              let object = try? viewContext.existingObject(with: selectedEntryID)
        else {
            return nil
        }
        return object as? StoredLogEntry
    }

    private var emptyView: some View {
        ContentUnavailableView {
            Label(
                session.entries.isEmpty ? "No Log Entries" : "No Matching Entries",
                systemImage: session.entries.isEmpty
                    ? "doc.text"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            selectedEntryID = nil
        }
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
