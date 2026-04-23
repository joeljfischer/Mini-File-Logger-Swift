import Foundation

struct LogParser {
    // Matches the format written by FileLogger (MiniFileLogger.swift):
    // "\(level) [\(subsystem)|\(category)] (\(Date.now.ISO8601Format(.iso8601))): \(message)\n"
    // Example: INF [com.app|networking] (2024-01-01T12:00:00Z): Connected
    nonisolated(unsafe) private static let linePattern = /^(\w+) \[([^|]+)\|([^\]]+)\] \(([^)]+)\): (.+)$/

    nonisolated(unsafe) private static let iso8601WithFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) private static let iso8601Basic: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(fileContents: String) -> [LogEntry] {
        parseLines(fileContents, startingLineNumber: 1)
    }

    static func parseLines(_ text: String, startingLineNumber: Int) -> [LogEntry] {
        var results: [LogEntry] = []
        let lines = text.components(separatedBy: "\n")
        var lineNumber = startingLineNumber
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            if let m = try? linePattern.wholeMatch(in: line) {
                let level = LogLevel(rawValue: String(m.1))
                let subsystem = String(m.2)
                let category = String(m.3)
                let tsStr = String(m.4)
                let message = String(m.5)
                let timestamp = iso8601WithFractional.date(from: tsStr)
                             ?? iso8601Basic.date(from: tsStr)
                results.append(LogEntry(id: UUID(), lineNumber: lineNumber, level: level,
                                        subsystem: subsystem, category: category,
                                        timestamp: timestamp, message: message, rawLine: line))
            } else if var last = results.popLast() {
                last = LogEntry(id: last.id, lineNumber: last.lineNumber, level: last.level,
                                subsystem: last.subsystem, category: last.category,
                                timestamp: last.timestamp,
                                message: last.message + "\n" + line,
                                rawLine: last.rawLine + "\n" + line)
                results.append(last)
            } else {
                results.append(LogEntry(id: UUID(), lineNumber: lineNumber, level: nil,
                                        subsystem: "", category: "", timestamp: nil,
                                        message: line, rawLine: line))
            }
            lineNumber += 1
        }
        return results
    }
}
