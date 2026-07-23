import CoreData
import Foundation

struct LogImportResult: Equatable, Sendable {
    let fileName: String
    let entryCount: Int
}

@MainActor
protocol LogImporting {
    func importFile(at url: URL) async throws -> LogImportResult
}

@MainActor
final class LogImportService: LogImporting {
    private let persistenceController: PersistenceController

    init(persistenceController: PersistenceController) {
        self.persistenceController = persistenceController
    }

    func importFile(at url: URL) async throws -> LogImportResult {
        let parsedEntries = try await readAndParseFile(at: url)
        let fileName = url.lastPathComponent
        let context = persistenceController.container.newBackgroundContext()
        context.name = "LogImportContext"
        context.transactionAuthor = "LogImport"

        do {
            try await context.perform {
                do {
                    for session in try context.fetch(LogSession.fetchRequest()) {
                        context.delete(session)
                    }

                    let session = LogSession(context: context)
                    session.id = UUID()
                    session.fileName = fileName
                    session.importedAt = Date()

                    for value in parsedEntries {
                        let row = StoredLogEntry(context: context)
                        row.id = value.id
                        row.lineNumber = Int64(value.lineNumber)
                        row.levelCode = value.level?.rawValue
                        row.levelRank = value.level?.sortOrder ?? -1
                        row.subsystem = value.subsystem
                        row.category = value.category
                        row.timestamp = value.timestamp
                        row.message = value.message
                        row.rawLine = value.rawLine
                        row.session = session
                    }

                    try context.save()
                } catch {
                    context.rollback()
                    throw error
                }
            }
        } catch {
            throw LogViewerError(error)
        }

        return LogImportResult(fileName: fileName, entryCount: parsedEntries.count)
    }

    private func readAndParseFile(at url: URL) async throws -> [LogEntry] {
        let isAccessingSecurityScopedResource = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessingSecurityScopedResource {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try await Task.detached(priority: .userInitiated) {
            let data: Data
            do {
                data = try Data(contentsOf: url, options: .mappedIfSafe)
            } catch {
                throw LogViewerError.readFailed(error.localizedDescription)
            }

            guard let contents = String(data: data, encoding: .utf8) else {
                throw LogViewerError.invalidUTF8
            }

            return LogParser.parse(fileContents: contents)
        }.value
    }
}
