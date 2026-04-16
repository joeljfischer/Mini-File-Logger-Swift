import SwiftUI

struct LogDetailView: View {
    let entry: LogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    if let level = entry.level {
                        Text(level.rawValue)
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(level.color.opacity(0.15))
                            .foregroundStyle(level.color)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        Text(level.displayName)
                            .font(.headline)
                            .foregroundStyle(level.color)
                    }
                    Spacer()
                    if let ts = entry.timestamp {
                        Text(ts.formatted(.dateTime.year().month().day().hour().minute().second()))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Subsystem").foregroundStyle(.secondary).font(.caption)
                        Text(entry.subsystem.isEmpty ? "—" : entry.subsystem)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    GridRow {
                        Text("Category").foregroundStyle(.secondary).font(.caption)
                        Text(entry.category.isEmpty ? "—" : entry.category)
                            .font(.caption.monospaced())
                            .textSelection(.enabled)
                    }
                    GridRow {
                        Text("Line").foregroundStyle(.secondary).font(.caption)
                        Text("\(entry.lineNumber)")
                            .font(.caption.monospaced())
                    }
                }

                Divider()

                Text("Message")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(entry.message)
                    .font(.body.monospaced())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()

                Text("Raw Line")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(entry.rawLine)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
    }
}
