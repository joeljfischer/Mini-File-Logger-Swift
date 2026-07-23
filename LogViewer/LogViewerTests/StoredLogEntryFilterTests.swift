import CoreData
import Testing
@testable import LogViewer

@MainActor
struct StoredLogEntryFilterTests {
    @Test func allLevelsReturnsEveryEntryInPhysicalLineOrder() async throws {
        let context = try await makeContext()
        let request = StoredLogEntry.filteredFetchRequest(searchText: "", minimumLevel: .all)

        let results = try context.fetch(request)

        #expect(request.fetchBatchSize == 200)
        #expect(results.map(\.levelCode) == [nil, "INF", "WRN", "ERR", "CRT"])
        #expect(results.map(\.lineNumber) == [1, 2, 3, 4, 5])
    }

    @Test func warningMinimumReturnsWarningAndHigherEntries() async throws {
        let context = try await makeContext()

        let results = try context.fetch(
            StoredLogEntry.filteredFetchRequest(searchText: "", minimumLevel: .warning)
        )

        #expect(results.map(\.levelCode) == ["WRN", "ERR", "CRT"])
    }

    @Test func searchMatchesRawLineIgnoringCase() async throws {
        let context = try await makeContext()

        let results = try context.fetch(
            StoredLogEntry.filteredFetchRequest(searchText: "disk", minimumLevel: .all)
        )

        #expect(results.map(\.rawLine).contains("DISK full"))
        #expect(results.map(\.rawLine).contains("Dísk cache ready"))
    }

    @Test func searchAndMinimumLevelApplyTogether() async throws {
        let context = try await makeContext()

        let results = try context.fetch(
            StoredLogEntry.filteredFetchRequest(searchText: "disk", minimumLevel: .error)
        )

        #expect(results.map(\.levelCode) == ["ERR", "CRT"])
    }

    @Test func minimumLevelsExposeTheirMappedLevelsAndDisplayNames() {
        #expect(MinimumLogLevel.all.level == nil)
        #expect(MinimumLogLevel.warning.level == .warning)
        #expect(MinimumLogLevel.critical.displayName == "Critical")
        #expect(LogLevel.warning.sortOrder == 3)
    }

    private func makeContext() async throws -> NSManagedObjectContext {
        let controller = PersistenceController(inMemory: true)
        await controller.load()
        try #require(controller.loadError == nil)

        let session = LogSession(context: controller.viewContext)
        session.id = UUID()
        session.fileName = "filters.log"
        session.importedAt = Date()

        insertEntry(
            in: controller.viewContext,
            session: session,
            lineNumber: 1,
            levelCode: nil,
            levelRank: -1,
            rawLine: "unknown line"
        )
        insertEntry(
            in: controller.viewContext,
            session: session,
            lineNumber: 2,
            levelCode: "INF",
            levelRank: 2,
            rawLine: "Dísk cache ready"
        )
        insertEntry(
            in: controller.viewContext,
            session: session,
            lineNumber: 3,
            levelCode: "WRN",
            levelRank: 3,
            rawLine: "DISK full"
        )
        insertEntry(
            in: controller.viewContext,
            session: session,
            lineNumber: 4,
            levelCode: "ERR",
            levelRank: 4,
            rawLine: "disk write failure"
        )
        insertEntry(
            in: controller.viewContext,
            session: session,
            lineNumber: 5,
            levelCode: "CRT",
            levelRank: 5,
            rawLine: "DISK unavailable"
        )
        try controller.viewContext.save()

        return controller.viewContext
    }

    private func insertEntry(
        in context: NSManagedObjectContext,
        session: LogSession,
        lineNumber: Int64,
        levelCode: String?,
        levelRank: Int16,
        rawLine: String
    ) {
        let entry = StoredLogEntry(context: context)
        entry.id = UUID()
        entry.lineNumber = lineNumber
        entry.levelCode = levelCode
        entry.levelRank = levelRank
        entry.subsystem = "App"
        entry.category = "Storage"
        entry.message = rawLine
        entry.rawLine = rawLine
        entry.session = session
    }
}
