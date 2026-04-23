import SwiftUI

struct FilterBar: View {
    @Bindable var filterState: FilterState

    var body: some View {
        HStack(spacing: 8) {
            ForEach(LogLevel.allCases) { level in
                LevelToggle(
                    level: level,
                    isSelected: filterState.selectedLevels.contains(level)
                ) {
                    if filterState.selectedLevels.contains(level) {
                        filterState.selectedLevels.remove(level)
                    } else {
                        filterState.selectedLevels.insert(level)
                    }
                }
            }

            Divider().frame(height: 20)

            TextField("Category", text: $filterState.categoryFilter)
                .textFieldStyle(.roundedBorder)
                .frame(width: 100)

            Spacer()

            if filterState.isFiltering {
                Button("Clear Filters") { filterState.reset() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
    }
}

private struct LevelToggle: View {
    let level: LogLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(level.rawValue)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(isSelected ? level.color.opacity(0.15) : Color.clear)
                .foregroundStyle(isSelected ? level.color : Color.secondary.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(
                            isSelected ? level.color.opacity(0.4) : Color.secondary.opacity(0.2),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.borderless)
        .help(level.displayName)
    }
}
