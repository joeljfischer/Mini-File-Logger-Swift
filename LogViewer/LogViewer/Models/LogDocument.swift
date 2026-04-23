import Foundation
import Observation

@MainActor
@Observable
final class LogDocument: Identifiable {
    let id = UUID()
    let url: URL
    var entries: [LogEntry] = []

    var fileName: String { url.lastPathComponent }

    init(url: URL) {
        self.url = url
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else { return }
        entries = LogParser.parse(fileContents: contents)
    }
}

extension LogDocument: Equatable, Hashable {
    nonisolated static func == (lhs: LogDocument, rhs: LogDocument) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
