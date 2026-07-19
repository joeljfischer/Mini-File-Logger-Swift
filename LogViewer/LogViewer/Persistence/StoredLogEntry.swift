import CoreData

@objc(StoredLogEntry)
final class StoredLogEntry: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var lineNumber: Int64
    @NSManaged var levelCode: String?
    @NSManaged var levelRank: Int16
    @NSManaged var subsystem: String
    @NSManaged var category: String
    @NSManaged var timestamp: Date?
    @NSManaged var message: String
    @NSManaged var rawLine: String
    @NSManaged var session: LogSession

    @nonobjc class func fetchRequest() -> NSFetchRequest<StoredLogEntry> {
        NSFetchRequest(entityName: "StoredLogEntry")
    }
}
