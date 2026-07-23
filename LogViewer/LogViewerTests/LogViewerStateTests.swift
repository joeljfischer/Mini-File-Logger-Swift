import Foundation
import Testing
@testable import LogViewer

@MainActor
struct LogViewerStateTests {
    @Test func successfulImportShowsProgressAndClearsSearch() async {
        let importer = SuspendedLogImporter()
        let state = LogViewerState(importer: importer, defaults: makeDefaults())
        state.searchText = "network"

        let importTask = Task {
            await state.importFile(at: URL(filePath: "/tmp/success.log"))
        }
        await importer.waitUntilImportStarts()

        #expect(state.isImporting)
        importer.succeed()
        await importTask.value

        #expect(!state.isImporting)
        #expect(state.searchText.isEmpty)
        #expect(state.presentedError == nil)
    }

    @Test func failedImportPreservesSearchAndExposesError() async {
        let importer = SuspendedLogImporter()
        let state = LogViewerState(importer: importer, defaults: makeDefaults())
        state.searchText = "database"

        let importTask = Task {
            await state.importFile(at: URL(filePath: "/tmp/failure.log"))
        }
        await importer.waitUntilImportStarts()
        importer.fail(with: .invalidUTF8)
        await importTask.value

        #expect(!state.isImporting)
        #expect(state.searchText == "database")
        #expect(state.presentedError == .invalidUTF8)
    }

    @Test func storedMinimumLevelIsRestoredAndChangesArePersisted() {
        let defaults = makeDefaults()
        defaults.set(MinimumLogLevel.warning.rawValue, forKey: "minimumLogLevel")
        let state = LogViewerState(importer: SuspendedLogImporter(), defaults: defaults)

        #expect(state.minimumLevel == .warning)

        state.minimumLevel = .error

        #expect(defaults.string(forKey: "minimumLogLevel") == MinimumLogLevel.error.rawValue)
    }

    @Test func presentingImporterIsIgnoredDuringImport() async {
        let importer = SuspendedLogImporter()
        let state = LogViewerState(importer: importer, defaults: makeDefaults())
        let importTask = Task {
            await state.importFile(at: URL(filePath: "/tmp/running.log"))
        }
        await importer.waitUntilImportStarts()

        state.presentImporter()

        #expect(!state.isImporterPresented)
        importer.succeed()
        await importTask.value
    }

    @Test func duplicateImportIsIgnoredWhileImportIsRunning() async {
        let importer = SuspendedLogImporter()
        let state = LogViewerState(importer: importer, defaults: makeDefaults())
        let firstURL = URL(filePath: "/tmp/first.log")
        let importTask = Task {
            await state.importFile(at: firstURL)
        }
        await importer.waitUntilImportStarts()

        await state.importFile(at: URL(filePath: "/tmp/second.log"))

        #expect(importer.requestedURLs == [firstURL])
        importer.succeed()
        await importTask.value
    }

    @Test func commandCoordinatorForwardsToItsState() {
        let importer = SuspendedLogImporter()
        let state = LogViewerState(importer: importer, defaults: makeDefaults())
        let coordinator = LogViewerCommandCoordinator(state: state)

        coordinator.presentImporter()
        coordinator.focusSearch()

        #expect(state.isImporterPresented)
        #expect(state.isSearchPresented)
        #expect(!coordinator.isImporting)
    }

    @Test func openFailurePreservesUnderlyingDescription() {
        let underlying = CocoaError(.fileReadNoPermission)
        let error = LogViewerError.openFailed(underlying.localizedDescription)

        #expect(
            error.errorDescription
                == "Could not open log file: \(underlying.localizedDescription)"
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "LogViewerStateTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

@MainActor
private final class SuspendedLogImporter: LogImporting {
    private var importContinuation: CheckedContinuation<LogImportResult, any Error>?
    private var startContinuation: CheckedContinuation<Void, Never>?
    private var hasStarted = false

    private(set) var requestedURLs: [URL] = []

    func importFile(at url: URL) async throws -> LogImportResult {
        requestedURLs.append(url)
        hasStarted = true
        startContinuation?.resume()
        startContinuation = nil

        return try await withCheckedThrowingContinuation { continuation in
            importContinuation = continuation
        }
    }

    func waitUntilImportStarts() async {
        guard !hasStarted else { return }
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func succeed() {
        importContinuation?.resume(
            returning: LogImportResult(fileName: "imported.log", entryCount: 1)
        )
        importContinuation = nil
    }

    func fail(with error: LogViewerError) {
        importContinuation?.resume(throwing: error)
        importContinuation = nil
    }
}
