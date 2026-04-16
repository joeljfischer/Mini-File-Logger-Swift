import Foundation
import Observation

@MainActor
@Observable
final class LogDocument: Identifiable {
    let id = UUID()
    let url: URL
    var entries: [LogEntry] = []
    var isWatching = false

    var fileName: String { url.lastPathComponent }

    private let watcher = FileWatcher()
    private var fileOffset: Int = 0

    init(url: URL) {
        self.url = url
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else { return }
        entries = LogParser.parse(fileContents: contents)
        fileOffset = data.count
    }

    func startWatching() {
        isWatching = true
        watcher.watch(url: url) { [weak self] in
            Task { @MainActor [weak self] in
                self?.readNewEntries()
            }
        }
    }

    func stopWatching() {
        isWatching = false
        watcher.stop()
    }

    private func readNewEntries() {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: UInt64(fileOffset))
            let data = handle.readDataToEndOfFile()
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            fileOffset += data.count
            let new = LogParser.parseLines(text, startingLineNumber: entries.count + 1)
            entries.append(contentsOf: new)
        } catch {}
    }

    deinit { watcher.stop() }
}

extension LogDocument: Equatable, Hashable {
    nonisolated static func == (lhs: LogDocument, rhs: LogDocument) -> Bool { lhs.id == rhs.id }
    nonisolated func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
