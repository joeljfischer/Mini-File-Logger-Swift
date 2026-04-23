import SwiftUI

struct LogTableView: View {
    let entries: [LogEntry]
    @Binding var selectedEntryID: LogEntry.ID?

    private let timestampWidth: CGFloat = 90
    private let categoryWidth: CGFloat = 80
    private let levelWidth: CGFloat = 38

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            LogRow(
                                entry: entry,
                                isSelected: entry.id == selectedEntryID,
                                isAlternate: index.isMultiple(of: 2),
                                timestampWidth: timestampWidth,
                                categoryWidth: categoryWidth,
                                levelWidth: levelWidth
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { selectedEntryID = entry.id }
                            .id(entry.id)
                        }
                    }
                }
                .onChange(of: selectedEntryID) { _, id in
                    guard let id else { return }
                    proxy.scrollTo(id, anchor: .center)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Color.clear.frame(width: levelWidth)
            Text("Timestamp")
                .frame(width: timestampWidth, alignment: .leading)
            Text("Category")
                .frame(width: categoryWidth, alignment: .leading)
            Text("Message")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }
}

private struct LogRow: View {
    let entry: LogEntry
    let isSelected: Bool
    let isAlternate: Bool
    let timestampWidth: CGFloat
    let categoryWidth: CGFloat
    let levelWidth: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            LevelBadge(level: entry.level)
                .frame(width: levelWidth, alignment: .leading)

            Text(entry.timestamp?.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3))) ?? "")
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: timestampWidth, alignment: .leading)

            Text(entry.category)
                .font(.caption.monospaced())
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: categoryWidth, alignment: .leading)

            Text(entry.message)
                .font(.caption.monospaced())
                .foregroundStyle(entry.level?.color ?? .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(rowBackground)
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isSelected {
            Color.accentColor.opacity(0.25)
        } else if isAlternate {
            Color.secondary.opacity(0.05)
        } else {
            Color.clear
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
