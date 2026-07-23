import SwiftUI

struct LogDetailView: View {
    @ObservedObject var entry: StoredLogEntry

    private var level: LogLevel? {
        entry.levelCode.flatMap(LogLevel.init(rawValue:))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center) {
                    if let level {
                        Text(level.rawValue)
                            .accessibilityIdentifier("detailLevelCode")
                            .font(.system(.caption, design: .monospaced, weight: .bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(level.color.opacity(0.15))
                            .foregroundStyle(level.color)
                            .clipShape(.rect(cornerRadius: 6))
                        Text(level.displayName)
                            .font(.headline)
                            .foregroundStyle(level.color)
                    } else {
                        Text("Unknown Level")
                            .font(.headline)
                    }

                    Spacer()

                    if let timestamp = entry.timestamp {
                        Text(
                            timestamp.formatted(
                                .dateTime.year().month().day().hour().minute().second()
                            )
                        )
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                    }
                }

                Divider()

                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    detailRow(
                        title: "Subsystem",
                        value: entry.subsystem,
                        identifier: "detailSubsystem"
                    )
                    detailRow(
                        title: "Category",
                        value: entry.category,
                        identifier: "detailCategory"
                    )
                    detailRow(
                        title: "Line",
                        value: entry.lineNumber.formatted(),
                        identifier: "detailLine"
                    )
                }

                Divider()

                detailSection(
                    title: "Message",
                    value: entry.message,
                    identifier: "detailMessage"
                )

                Divider()

                detailSection(
                    title: "Raw Line",
                    value: entry.rawLine,
                    identifier: "detailRawLine",
                    isSecondary: true
                )
            }
            .padding()
        }
    }

    private func detailRow(
        title: String,
        value: String,
        identifier: String
    ) -> some View {
        GridRow {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "—" : value)
                .accessibilityIdentifier(identifier)
                .font(.caption.monospaced())
                .textSelection(.enabled)
        }
    }

    private func detailSection(
        title: String,
        value: String,
        identifier: String,
        isSecondary: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .accessibilityIdentifier(identifier)
                .font((isSecondary ? Font.caption : Font.body).monospaced())
                .foregroundStyle(isSecondary ? .secondary : .primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
