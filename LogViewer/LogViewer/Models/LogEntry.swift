import Foundation

struct LogEntry: Identifiable, Equatable, Sendable {
    let id: UUID
    let lineNumber: Int
    let level: LogLevel?
    let subsystem: String
    let category: String
    let timestamp: Date?
    let message: String
    let rawLine: String

    var levelSortOrder: Int { Int(level?.sortOrder ?? -1) }
    var timestampForSort: Date { timestamp ?? .distantPast }
}
