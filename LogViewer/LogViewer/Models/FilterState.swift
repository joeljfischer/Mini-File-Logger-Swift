import Foundation
import Observation

@Observable
final class FilterState {
    var searchText: String = ""
    var selectedLevels: Set<LogLevel> = Set(LogLevel.allCases)
    var subsystemFilter: String = ""
    var categoryFilter: String = ""

    func matches(_ entry: LogEntry) -> Bool {
        if let level = entry.level, !selectedLevels.contains(level) { return false }

        if !subsystemFilter.isEmpty,
           !entry.subsystem.localizedCaseInsensitiveContains(subsystemFilter) { return false }

        if !categoryFilter.isEmpty,
           !entry.category.localizedCaseInsensitiveContains(categoryFilter) { return false }

        if !searchText.isEmpty,
           !entry.rawLine.localizedCaseInsensitiveContains(searchText) { return false }

        return true
    }

    var isFiltering: Bool {
        !searchText.isEmpty
            || selectedLevels.count != LogLevel.allCases.count
            || !subsystemFilter.isEmpty
            || !categoryFilter.isEmpty
    }

    func reset() {
        searchText = ""
        selectedLevels = Set(LogLevel.allCases)
        subsystemFilter = ""
        categoryFilter = ""
    }
}
