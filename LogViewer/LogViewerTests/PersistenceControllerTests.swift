import CoreData
import Testing
@testable import LogViewer

@MainActor
struct PersistenceControllerTests {
    @Test func loadsSharedModelAndPersistsSession() async throws {
        let controller = PersistenceController(inMemory: true)
        await controller.load()
        #expect(controller.isLoaded)
        #expect(controller.loadError == nil)

        let session = LogSession(context: controller.viewContext)
        session.id = UUID()
        session.fileName = "sample.log"
        session.importedAt = Date()
        try controller.viewContext.save()

        let sessions = try controller.viewContext.fetch(LogSession.fetchRequest())
        #expect(sessions.map(\.fileName) == ["sample.log"])
    }
}
