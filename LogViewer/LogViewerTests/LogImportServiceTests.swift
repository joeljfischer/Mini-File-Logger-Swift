import CoreData
import Foundation
import Testing
@testable import LogViewer

@MainActor
struct LogImportServiceTests {
    @Test func importingAnotherFileReplacesThePreviousSession() async throws {
        let (controller, service) = try await makeService()
        let first = try temporaryFile(
            named: "first.log",
            contents: "INF [app|one] (2026-07-19T12:00:00Z): hello"
        )
        let second = try temporaryFile(
            named: "second.log",
            contents: "WRN [app|two] (2026-07-19T12:00:01Z): caution\nERR [app|two] (2026-07-19T12:00:02Z): failed"
        )

        _ = try await service.importFile(at: first)
        let result = try await service.importFile(at: second)

        #expect(result == LogImportResult(fileName: "second.log", entryCount: 2))
        #expect(try controller.viewContext.fetch(LogSession.fetchRequest()).map(\.fileName) == ["second.log"])
        #expect(try controller.viewContext.fetch(StoredLogEntry.fetchRequest()).count == 2)
    }

    @Test func importMapsEveryParsedField() async throws {
        let (controller, service) = try await makeService()
        let file = try temporaryFile(
            named: "mapped.log",
            contents: "ERR [com.example.app|network] (2026-07-19T12:34:56.789Z): request failed"
        )

        _ = try await service.importFile(at: file)

        let entries = try controller.viewContext.fetch(StoredLogEntry.fetchRequest())
        let entry = try #require(entries.first)
        #expect(entries.count == 1)
        #expect(entry.lineNumber == 1)
        #expect(entry.levelCode == "ERR")
        #expect(entry.levelRank == 4)
        #expect(entry.subsystem == "com.example.app")
        #expect(entry.category == "network")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        #expect(entry.timestamp == formatter.date(from: "2026-07-19T12:34:56.789Z"))
        #expect(entry.message == "request failed")
        #expect(entry.rawLine == "ERR [com.example.app|network] (2026-07-19T12:34:56.789Z): request failed")
        #expect(entry.session.fileName == "mapped.log")
    }

    @Test func emptyValidFileCreatesAnEmptySession() async throws {
        let (controller, service) = try await makeService()
        let file = try temporaryFile(named: "empty.log", contents: "")

        let result = try await service.importFile(at: file)

        #expect(result == LogImportResult(fileName: "empty.log", entryCount: 0))
        #expect(try controller.viewContext.fetch(LogSession.fetchRequest()).map(\.fileName) == ["empty.log"])
        #expect(try controller.viewContext.fetch(StoredLogEntry.fetchRequest()).isEmpty)
    }

    @Test func invalidUTF8ThrowsAndPreservesThePreviousSession() async throws {
        let (controller, service) = try await makeService()
        let valid = try temporaryFile(
            named: "valid.log",
            contents: "INF [app|one] (2026-07-19T12:00:00Z): hello"
        )
        let invalid = try temporaryFile(named: "invalid.log", data: Data([0xC3, 0x28]))
        _ = try await service.importFile(at: valid)

        await #expect(throws: LogViewerError.invalidUTF8) {
            try await service.importFile(at: invalid)
        }

        #expect(try controller.viewContext.fetch(LogSession.fetchRequest()).map(\.fileName) == ["valid.log"])
        #expect(try controller.viewContext.fetch(StoredLogEntry.fetchRequest()).count == 1)
    }

    @Test func unreadableURLMapsToReadFailed() async throws {
        let (_, service) = try await makeService()
        let missing = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            .appending(path: "missing.log")

        do {
            _ = try await service.importFile(at: missing)
            Issue.record("Expected import to fail for a missing file")
        } catch let error as LogViewerError {
            guard case .readFailed = error else {
                Issue.record("Expected readFailed, received \(error)")
                return
            }
        }
    }

    private func makeService() async throws -> (PersistenceController, LogImportService) {
        let controller = PersistenceController(inMemory: true)
        controller.container.persistentStoreDescriptions[0].url = FileManager.default.temporaryDirectory
            .appending(path: "LogImportServiceTests-\(UUID().uuidString).store")
        await controller.load()
        try #require(controller.isLoaded)
        try #require(controller.loadError == nil)
        return (controller, LogImportService(persistenceController: controller))
    }

    private func temporaryFile(named name: String, contents: String) throws -> URL {
        try temporaryFile(named: name, data: Data(contents.utf8))
    }

    private func temporaryFile(named name: String, data: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appending(path: name)
        try data.write(to: file, options: .atomic)
        return file
    }
}
