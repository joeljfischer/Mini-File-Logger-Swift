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

    static func filteredFetchRequest(
        searchText: String,
        minimumLevel: MinimumLogLevel
    ) -> NSFetchRequest<StoredLogEntry> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "lineNumber", ascending: true)]
        request.fetchBatchSize = 200
        var predicates: [NSPredicate] = []
        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "rawLine CONTAINS[cd] %@", searchText))
        }
        if let level = minimumLevel.level {
            predicates.append(NSPredicate(format: "levelRank >= %d", level.sortOrder))
        }
        request.predicate = predicates.isEmpty
            ? nil
            : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)

        return request
    }
}
