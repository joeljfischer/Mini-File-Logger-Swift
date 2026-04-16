import SwiftUI

struct LogTableView: View {
    let entries: [LogEntry]
    @Binding var selectedEntryID: LogEntry.ID?

    @State private var sortOrder: [KeyPathComparator<LogEntry>] = [
        KeyPathComparator(\.lineNumber, order: .forward)
    ]
    @State private var sortedEntries: [LogEntry] = []

    var body: some View {
        Table(sortedEntries, selection: $selectedEntryID, sortOrder: $sortOrder) {
            TableColumn("", value: \.levelSortOrder) { entry in
                LevelBadge(level: entry.level)
            }
            .width(38)

            TableColumn("Timestamp", value: \.timestampForSort) { entry in
                Text(entry.timestamp?.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3))) ?? "")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            .width(min: 100, ideal: 150)

            TableColumn("Subsystem", value: \.subsystem) { entry in
                Text(entry.subsystem)
                    .font(.caption.monospaced())
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 140)

            TableColumn("Category", value: \.category) { entry in
                Text(entry.category)
                    .font(.caption.monospaced())
                    .lineLimit(1)
            }
            .width(min: 60, ideal: 100)

            TableColumn("Message", value: \.message) { entry in
                Text(entry.message)
                    .font(.caption.monospaced())
                    .lineLimit(1)
                    .foregroundStyle(entry.level?.color ?? .primary)
            }
        }
        .onChange(of: entries, initial: true) { _, new in
            sortedEntries = new.sorted(using: sortOrder)
        }
        .onChange(of: sortOrder) { _, new in
            sortedEntries = entries.sorted(using: new)
        }
    }
}

private struct LevelBadge: View {
    let level: LogLevel?

    var body: some View {
        if let level {
            Text(level.rawValue)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(level.color.opacity(0.15))
                .foregroundStyle(level.color)
                .clipShape(RoundedRectangle(cornerRadius: 3))
        }
    }
}
