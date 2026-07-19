import CoreData
import Observation

@MainActor @Observable
final class PersistenceController {
    let container: NSPersistentContainer
    private(set) var isLoaded = false
    private(set) var loadError: LogViewerError?
    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "LogViewer")
        if inMemory {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            container.persistentStoreDescriptions = [description]
        }
        container.viewContext.name = "ViewContext"
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyStoreTrump
    }

    func load() async {
        guard !isLoaded, loadError == nil else { return }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                container.loadPersistentStores { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: ())
                    }
                }
            }
            isLoaded = true
        } catch {
            loadError = .storeLoadFailed(error.localizedDescription)
        }
    }
}
