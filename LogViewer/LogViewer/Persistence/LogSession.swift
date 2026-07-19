import CoreData

@objc(LogSession)
final class LogSession: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var fileName: String
    @NSManaged var importedAt: Date
    @NSManaged var entries: Set<StoredLogEntry>

    @nonobjc class func fetchRequest() -> NSFetchRequest<LogSession> {
        NSFetchRequest(entityName: "LogSession")
    }
}
