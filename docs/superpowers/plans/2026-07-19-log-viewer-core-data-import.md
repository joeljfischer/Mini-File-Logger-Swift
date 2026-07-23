# LogViewer Core Data Import Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Import one MiniFileLogger file from File > Open, toolbar, or Finder drop; persist parsed rows in Core Data; filter them with toolbar search and minimum-level controls.

**Architecture:** A testable `PersistenceController` owns SQLite production and in-memory test stores. `LogImportService` reads and parses outside main-thread UI work, then atomically replaces one `LogSession` in a private Core Data context. SwiftUI fetch requests query persisted rows directly while `LogViewerState` coordinates import presentation, errors, and commands.

**Tech Stack:** Swift 6, SwiftUI, Observation, Core Data, UniformTypeIdentifiers, Swift Testing, macOS 15+, Xcode 27.

## Global Constraints

- Keep one active imported log; successful import replaces previous session.
- Never edit source log file or retain security-scoped access after import.
- Use SQLite in production and same managed object model with in-memory stores in tests.
- Keep Core Data managed objects inside owning context; selection crosses view boundaries as `NSManagedObjectID` only.
- Search `rawLine` case- and diacritic-insensitively; minimum Warning includes Warning, Error, and Critical.
- All Levels includes unrecognized rows; any explicit minimum excludes them.
- New import failure preserves current persisted session and visible title.
- No live file watching, multi-file library, multi-file import, source editing, or custom-format parser.

---

## File Map

- `LogViewer/LogViewer/Models/LogEntry.swift`: immutable parser output only.
- `LogViewer/LogViewer/Models/LogLevel.swift`: level identity, display, rank, and color.
- `LogViewer/LogViewer/Models/MinimumLogLevel.swift`: toolbar choices and persisted raw value.
- `LogViewer/LogViewer/Models/LogViewerError.swift`: localized store and import errors used by state alerts.
- `LogViewer/LogViewer/Parsing/LogParser.swift`: text-to-value parsing with physical line numbers.
- `LogViewer/LogViewer/Persistence/PersistenceController.swift`: store construction/loading and test injection.
- `LogViewer/LogViewer/Persistence/LogSession.swift`: managed object for active file metadata.
- `LogViewer/LogViewer/Persistence/StoredLogEntry.swift`: managed row plus filtered fetch request.
- `LogViewer/LogViewer/LogViewer.xcdatamodeld/LogViewer.xcdatamodel/contents`: versioned Core Data schema.
- `LogViewer/LogViewer/Importing/LogImportService.swift`: security scope, UTF-8 decoding, parsing, atomic replacement.
- `LogViewer/LogViewer/State/LogViewerState.swift`: import progress, alerts, search, minimum preference, async orchestration.
- `LogViewer/LogViewer/Commands/LogViewerCommands.swift`: focused Open/Find command coordinator and menu commands.
- `LogViewer/LogViewer/ContentView.swift`: root loading, file importer, drop destination, empty/loaded states, toolbar.
- `LogViewer/LogViewer/Views/LogTableView.swift`: dynamic Core Data fetch and native `Table`.
- `LogViewer/LogViewer/Views/LogDetailView.swift`: selected managed-row details.
- Delete `Models/LogDocument.swift`, `Models/FilterState.swift`, and `Views/FilterBar.swift` after replacements compile.
- `LogViewer/LogViewerTests/*.swift`: parser, persistence/filter, importer, and state tests.
- `LogViewer/LogViewer.xcodeproj/project.pbxproj`: Core Data model, new source groups, and `LogViewerTests` target.

---

### Task 1: Add Test Target and Make Parser Concurrency-Safe

**Files:**
- Create: `LogViewer/LogViewerTests/LogParserTests.swift`
- Modify: `LogViewer/LogViewer/Parsing/LogParser.swift`
- Modify: `LogViewer/LogViewer.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: `LogEntry`, `LogLevel`.
- Produces: `LogParser.parse(fileContents:) -> [LogEntry]` with physical file line numbers and no shared mutable formatter.

- [ ] **Step 1: Add native unit-test target**

Add `LogViewerTests.xctest` product, sources/frameworks/resources phases, target dependency on `LogViewer`, Debug/Release configs (`PRODUCT_BUNDLE_IDENTIFIER = com.joelfischer.LogViewerTests`, `GENERATE_INFOPLIST_FILE = YES`, `MACOSX_DEPLOYMENT_TARGET = 15.0`, `SWIFT_VERSION = 6.0`, `TEST_HOST = "$(BUILT_PRODUCTS_DIR)/LogViewer.app/Contents/MacOS/LogViewer"`, `BUNDLE_LOADER = "$(TEST_HOST)"`), product group entry, project target entry, and `LogParserTests.swift` source membership.

- [ ] **Step 2: Write failing parser tests**

```swift
import Foundation
import Testing
@testable import LogViewer

struct LogParserTests {
    @Test func keepsPhysicalLineNumbersAndMultilineMessages() throws {
        let text = """

        WRN [com.example|network] (2026-07-19T12:00:00Z): First line
        continuation
        ERR [com.example|storage] (2026-07-19T12:00:01.125Z): Disk full
        """
        let entries = LogParser.parse(fileContents: text)
        #expect(entries.map(\.lineNumber) == [2, 4])
        #expect(entries[0].message == "First line\ncontinuation")
        #expect(entries[0].level == .warning)
        #expect(entries[1].timestamp != nil)
    }

    @Test func preservesFirstUnrecognizedLine() {
        let entries = LogParser.parse(fileContents: "not MiniFileLogger output")
        #expect(entries.count == 1)
        #expect(entries[0].level == nil)
        #expect(entries[0].rawLine == "not MiniFileLogger output")
    }
}
```

- [ ] **Step 3: Run test and verify red state**

Run:

```bash
xcodebuild -project LogViewer/LogViewer.xcodeproj -scheme LogViewer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test -only-testing:LogViewerTests/LogParserTests
```

Expected: first test fails because blank physical line is not counted.

- [ ] **Step 4: Refactor parser minimally**

Iterate `lines.enumerated()`, calculate `lineNumber = startingLineNumber + offset`, and create both `ISO8601DateFormatter` instances inside `parseLines`. Keep regex immutable and remove shared `nonisolated(unsafe)` formatter properties.

```swift
for (offset, line) in text.components(separatedBy: "\n").enumerated() {
    let lineNumber = startingLineNumber + offset
    guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
    // Existing match/continuation/raw fallback mapping.
}
```

- [ ] **Step 5: Run parser tests green**

Run previous command. Expected: `** TEST SUCCEEDED **`, 2 tests passed.

- [ ] **Step 6: Commit**

```bash
git add LogViewer/LogViewer.xcodeproj/project.pbxproj LogViewer/LogViewer/Parsing/LogParser.swift LogViewer/LogViewerTests/LogParserTests.swift
git commit -m "test: cover LogViewer parsing"
```

---

### Task 2: Add Core Data Model and Persistence Controller

**Files:**
- Create: `LogViewer/LogViewer/LogViewer.xcdatamodeld/.xccurrentversion`
- Create: `LogViewer/LogViewer/LogViewer.xcdatamodeld/LogViewer.xcdatamodel/contents`
- Create: `LogViewer/LogViewer/Persistence/PersistenceController.swift`
- Create: `LogViewer/LogViewer/Persistence/LogSession.swift`
- Create: `LogViewer/LogViewer/Persistence/StoredLogEntry.swift`
- Create: `LogViewer/LogViewer/Models/LogViewerError.swift`
- Create: `LogViewer/LogViewerTests/PersistenceControllerTests.swift`
- Modify: `LogViewer/LogViewer.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `@MainActor final class PersistenceController`, `init(inMemory: Bool = false)`, `func load() async`, `var isLoaded: Bool`, `var loadError: LogViewerError?`, `var viewContext: NSManagedObjectContext`, and internal `let container: NSPersistentContainer`.
- Produces: `LogSession.fetchRequest()`, `StoredLogEntry.fetchRequest()` and manually generated `@NSManaged` properties matching model.
- Produces: `LogViewerError: LocalizedError, Identifiable, Equatable` with store/read/decode/save cases and `init(_ error: Error)` normalization.

- [ ] **Step 1: Write failing in-memory persistence test**

```swift
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
```

- [ ] **Step 2: Run test and verify red state**

Run test command with `-only-testing:LogViewerTests/PersistenceControllerTests`. Expected: compile failure, `cannot find 'PersistenceController' in scope`.

- [ ] **Step 3: Add exact model**

Create versioned model with `LogSession` (`id UUID`, `fileName String`, `importedAt Date`, `entries` cascade to-many) and `StoredLogEntry` (`id UUID`, `lineNumber Integer 64`, optional `levelCode String`, `levelRank Integer 16` default `-1`, `subsystem String`, `category String`, optional `timestamp Date`, `message String`, `rawLine String`, required `session` inverse). Set Codegen to Manual/None and module to Current Product Module for both entities.

`.xccurrentversion` must select `LogViewer.xcdatamodel`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>_XCCurrentVersionName</key><string>LogViewer.xcdatamodel</string></dict></plist>
```

Model XML must declare both inverse relationships and `usedWithCloudKit="NO"`; do not enable code generation because manual classes below are source-controlled.

- [ ] **Step 4: Add managed object classes**

```swift
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
```

- [ ] **Step 5: Implement async-loadable controller**

Configure `NSInMemoryStoreType` for tests, SQLite default for production, name view context `ViewContext`, set `automaticallyMergesChangesFromParent = true`, and store-trump merge policy. `load()` bridges `loadPersistentStores`; it is idempotent and converts an error to `LogViewerError.storeLoadFailed(String)`.

```swift
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
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
    }

    func load() async {
        guard !isLoaded, loadError == nil else { return }
        do {
            try await withCheckedThrowingContinuation { continuation in
                container.loadPersistentStores { _, error in
                    if let error { continuation.resume(throwing: error) }
                    else { continuation.resume() }
                }
            }
            isLoaded = true
        } catch {
            loadError = .storeLoadFailed(error.localizedDescription)
        }
    }
}

enum LogViewerError: LocalizedError, Identifiable, Equatable {
    case storeLoadFailed(String)
    case readFailed(String)
    case invalidUTF8
    case storeSaveFailed(String)

    init(_ error: Error) {
        self = (error as? LogViewerError) ?? .storeSaveFailed(error.localizedDescription)
    }

    var id: String { errorDescription ?? String(describing: self) }
    var errorDescription: String? {
        switch self {
        case .storeLoadFailed(let detail): "Could not load log database: \(detail)"
        case .readFailed(let detail): "Could not read log file: \(detail)"
        case .invalidUTF8: "Log file is not valid UTF-8 text."
        case .storeSaveFailed(let detail): "Could not save imported log: \(detail)"
        }
    }
}
```

- [ ] **Step 6: Run test green and full app build**

Expected: persistence test passes; Debug app builds.

- [ ] **Step 7: Commit**

```bash
git add LogViewer/LogViewer.xcodeproj/project.pbxproj LogViewer/LogViewer/LogViewer.xcdatamodeld LogViewer/LogViewer/Persistence LogViewer/LogViewer/Models/LogViewerError.swift LogViewer/LogViewerTests/PersistenceControllerTests.swift
git commit -m "feat: add LogViewer Core Data store"
```

---

### Task 3: Add Minimum-Level and Search Fetch Predicates

**Files:**
- Create: `LogViewer/LogViewer/Models/MinimumLogLevel.swift`
- Modify: `LogViewer/LogViewer/Models/LogLevel.swift`
- Modify: `LogViewer/LogViewer/Persistence/StoredLogEntry.swift`
- Create: `LogViewer/LogViewerTests/StoredLogEntryFilterTests.swift`
- Modify: `LogViewer/LogViewer.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `enum MinimumLogLevel: String, CaseIterable, Identifiable`, `var level: LogLevel?`, `var displayName: String`.
- Produces: `StoredLogEntry.filteredFetchRequest(searchText: String, minimumLevel: MinimumLogLevel) -> NSFetchRequest<StoredLogEntry>`.

- [ ] **Step 1: Write failing predicate tests**

Insert unknown, Info, Warning, Error, and Critical rows in one in-memory context. Assert All returns five; Warning+ returns three; search `disk` matches `DISK full`; combined `disk` plus Error+ returns only Error/Critical matching text.

```swift
let request = StoredLogEntry.filteredFetchRequest(searchText: "disk", minimumLevel: .warning)
let results = try context.fetch(request)
#expect(results.map(\.levelCode) == ["ERR"])
```

- [ ] **Step 2: Run red**

Expected: compile failure because `MinimumLogLevel` and filtered request do not exist.

- [ ] **Step 3: Implement choices and predicate factory**

```swift
enum MinimumLogLevel: String, CaseIterable, Identifiable, Sendable {
    case all, verbose, debug, info, warning, error, critical
    var id: String { rawValue }
    var level: LogLevel? {
        switch self {
        case .all: nil
        case .verbose: .verbose
        case .debug: .debug
        case .info: .info
        case .warning: .warning
        case .error: .error
        case .critical: .critical
        }
    }
    var displayName: String {
        switch self {
        case .all: "All Levels"
        case .verbose: "Verbose+"
        case .debug: "Debug+"
        case .info: "Info+"
        case .warning: "Warning+"
        case .error: "Error+"
        case .critical: "Critical"
        }
    }
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
    request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    return request
}
```

Use explicit switch mapping instead of forced unwrap in final implementation. Change `LogLevel.sortOrder` to `Int16`.

- [ ] **Step 4: Run green and commit**

```bash
git add LogViewer/LogViewer.xcodeproj/project.pbxproj LogViewer/LogViewer/Models/LogLevel.swift LogViewer/LogViewer/Models/MinimumLogLevel.swift LogViewer/LogViewer/Persistence/StoredLogEntry.swift LogViewer/LogViewerTests/StoredLogEntryFilterTests.swift
git commit -m "feat: add persisted log filtering"
```

---

### Task 4: Import Files Atomically Into Core Data

**Files:**
- Create: `LogViewer/LogViewer/Importing/LogImportService.swift`
- Create: `LogViewer/LogViewerTests/LogImportServiceTests.swift`
- Modify: `LogViewer/LogViewer.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `struct LogImportResult: Equatable, Sendable { let fileName: String; let entryCount: Int }`.
- Produces: `@MainActor protocol LogImporting { func importFile(at url: URL) async throws -> LogImportResult }`.
- Produces: `@MainActor final class LogImportService: LogImporting`, initialized with `PersistenceController`.

- [ ] **Step 1: Write failing importer tests**

Use temporary files for:

```swift
let first = try temporaryFile(named: "first.log", contents: "INF [app|one] (2026-07-19T12:00:00Z): hello")
let second = try temporaryFile(named: "second.log", contents: "WRN [app|two] (2026-07-19T12:00:01Z): caution\nERR [app|two] (2026-07-19T12:00:02Z): failed")
_ = try await service.importFile(at: first)
let result = try await service.importFile(at: second)
#expect(result == LogImportResult(fileName: "second.log", entryCount: 2))
#expect(try context.fetch(LogSession.fetchRequest()).map(\.fileName) == ["second.log"])
#expect(try context.fetch(StoredLogEntry.fetchRequest()).count == 2)
```

Also test field mapping, empty valid file creates one session with zero entries, invalid UTF-8 throws and preserves previous session.

- [ ] **Step 2: Run red**

Expected: compile failure because importer types do not exist.

- [ ] **Step 3: Implement read/parse stage**

Balance security scope with `defer`; use `Task.detached(priority: .userInitiated)` to read `Data`, validate UTF-8, and call concurrency-safe `LogParser`. Map read/decode errors to localized `LogViewerError` cases.

- [ ] **Step 4: Implement atomic background-context replacement**

```swift
let context = persistenceController.container.newBackgroundContext()
context.name = "LogImportContext"
context.transactionAuthor = "LogImport"
try await context.perform {
    do {
        for session in try context.fetch(LogSession.fetchRequest()) { context.delete(session) }
        let session = LogSession(context: context)
        session.id = UUID()
        session.fileName = url.lastPathComponent
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
```

- [ ] **Step 5: Run all importer tests green**

Expected: successful replacement, empty import, field mapping, and failure-preservation tests pass.

- [ ] **Step 6: Commit**

```bash
git add LogViewer/LogViewer.xcodeproj/project.pbxproj LogViewer/LogViewer/Importing LogViewer/LogViewerTests/LogImportServiceTests.swift
git commit -m "feat: import log files into Core Data"
```

---

### Task 5: Add Observable State and Focused Commands

**Files:**
- Create: `LogViewer/LogViewer/State/LogViewerState.swift`
- Create: `LogViewer/LogViewer/Commands/LogViewerCommands.swift`
- Create: `LogViewer/LogViewerTests/LogViewerStateTests.swift`
- Modify: `LogViewer/LogViewer.xcodeproj/project.pbxproj`

**Interfaces:**
- Produces: `@MainActor @Observable final class LogViewerState`, initialized by `init(importer: any LogImporting, defaults: UserDefaults = .standard)`, with `searchText`, `minimumLevel`, `isImporterPresented`, `isSearchPresented`, `isImporting`, `presentedError`, `presentImporter()`, `focusSearch()`, and `importFile(at:) async`.
- Produces: `@MainActor final class LogViewerCommandCoordinator`, initialized by `init(state: LogViewerState)`, forwarding methods to current state without stored closures.
- Produces: `struct LogViewerCommands: Commands` with focused coordinator, Command-O, and Command-F.

- [ ] **Step 1: Write failing state tests**

Use a main-actor spy importer. Assert successful import toggles progress and clears search; failed import preserves search and exposes alert; defaults value `warning` initializes `.warning`; `presentImporter()` is ignored while import runs.

- [ ] **Step 2: Run red**

Expected: compile failure because state and coordinator do not exist.

- [ ] **Step 3: Implement state**

```swift
@MainActor @Observable
final class LogViewerState {
    var searchText = ""
    var minimumLevel: MinimumLogLevel { didSet { defaults.set(minimumLevel.rawValue, forKey: Self.minimumLevelKey) } }
    var isImporterPresented = false
    var isSearchPresented = false
    private(set) var isImporting = false
    var presentedError: LogViewerError?

    @ObservationIgnored private let importer: any LogImporting
    @ObservationIgnored private let defaults: UserDefaults

    init(importer: any LogImporting, defaults: UserDefaults = .standard) {
        self.importer = importer
        self.defaults = defaults
        minimumLevel = defaults.string(forKey: Self.minimumLevelKey)
            .flatMap(MinimumLogLevel.init(rawValue:)) ?? .all
    }

    private static let minimumLevelKey = "minimumLogLevel"

    func presentImporter() {
        guard !isImporting else { return }
        isImporterPresented = true
    }

    func focusSearch() {
        isSearchPresented = true
    }

    func importFile(at url: URL) async {
        guard !isImporting else { return }
        isImporting = true
        defer { isImporting = false }
        do { _ = try await importer.importFile(at: url); searchText = "" }
        catch { presentedError = LogViewerError(error) }
    }
}
```

- [ ] **Step 4: Implement focused command object**

`FocusedValues` stores `LogViewerCommandCoordinator?`, never a closure. `CommandGroup(replacing: .newItem)` adds Open… Command-O. `CommandGroup(after: .textEditing)` adds Find… Command-F. Commands disable while no focused coordinator or import active.

```swift
import SwiftUI

@MainActor
final class LogViewerCommandCoordinator {
    private let state: LogViewerState
    init(state: LogViewerState) { self.state = state }
    var isImporting: Bool { state.isImporting }
    func presentImporter() { state.presentImporter() }
    func focusSearch() { state.focusSearch() }
}

private struct LogViewerCommandCoordinatorKey: FocusedValueKey {
    typealias Value = LogViewerCommandCoordinator
}

extension FocusedValues {
    var logViewerCommandCoordinator: LogViewerCommandCoordinator? {
        get { self[LogViewerCommandCoordinatorKey.self] }
        set { self[LogViewerCommandCoordinatorKey.self] = newValue }
    }
}

struct LogViewerCommands: Commands {
    @FocusedValue(\.logViewerCommandCoordinator) private var coordinator

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Open…") { coordinator?.presentImporter() }
                .keyboardShortcut("o")
                .disabled(coordinator == nil || coordinator?.isImporting == true)
        }
        CommandGroup(after: .textEditing) {
            Button("Find…") { coordinator?.focusSearch() }
                .keyboardShortcut("f")
                .disabled(coordinator == nil)
        }
    }
}
```

- [ ] **Step 5: Run green and commit**

```bash
git add LogViewer/LogViewer.xcodeproj/project.pbxproj LogViewer/LogViewer/State LogViewer/LogViewer/Commands LogViewer/LogViewerTests/LogViewerStateTests.swift
git commit -m "feat: add LogViewer import commands"
```

---

### Task 6: Wire Core Data UI, Toolbar, Open Panel, and Drop

**Files:**
- Modify: `LogViewer/LogViewer/LogViewerApp.swift`
- Replace: `LogViewer/LogViewer/ContentView.swift`
- Replace: `LogViewer/LogViewer/Views/LogTableView.swift`
- Replace: `LogViewer/LogViewer/Views/LogDetailView.swift`
- Delete: `LogViewer/LogViewer/Models/LogDocument.swift`
- Delete: `LogViewer/LogViewer/Models/FilterState.swift`
- Delete: `LogViewer/LogViewer/Views/FilterBar.swift`
- Modify: `LogViewer/LogViewer.xcodeproj/project.pbxproj`

**Interfaces:**
- Consumes: controller, state, commands, session and entry managed objects, filtered fetch request.
- Produces: all requested user entry paths and toolbar filters in running app.

- [ ] **Step 1: Establish UI verification gates**

Use existing focused state and persistence tests for nonvisual behavior. Verify each UI slice by compiling the app, then verify menu, open-panel, toolbar, and drop interactions manually in Task 7; do not add tests that inspect source strings.

- [ ] **Step 2: Inject dependencies at app root**

Construct one `PersistenceController`, `LogImportService`, `LogViewerState`, and `LogViewerCommandCoordinator`; inject controller observation object and `managedObjectContext`; install `LogViewerCommands` on scene. Load store before constructing fetch-driven workspace.

- [ ] **Step 3: Replace root content**

Use `@FetchRequest` for current session, `.fileImporter` for `.logFile` and `.plainText`, `.dropDestination(for: URL.self)`, `.alert`, and one always-visible toolbar. All URLs call `Task { await state.importFile(at: url) }`.

Toolbar requirements:

```swift
ToolbarItem(placement: .navigation) {
    if state.isImporting { ProgressView().accessibilityLabel("Importing Log File") }
    else { Button("Open Log File", systemImage: "folder") { state.presentImporter() } }
}
ToolbarItem {
    Picker("Minimum Log Level", selection: $state.minimumLevel) {
        ForEach(MinimumLogLevel.allCases) { level in Text(level.displayName).tag(level) }
    }
    .pickerStyle(.menu)
}
```

Apply `.searchable(text:isPresented:placement:prompt:)` with toolbar placement and prompt `Search Logs`.

- [ ] **Step 4: Replace log list with dynamic Core Data `Table`**

Initialize `@FetchRequest` from `StoredLogEntry.filteredFetchRequest`. Bind single selection to `NSManagedObjectID?`. Columns show textual level, timestamp, category, and message. Resolve selected object through `viewContext.existingObject(with:)` before sending it to detail view.

- [ ] **Step 5: Preserve empty and no-results states**

No session: “No Log File Open” plus open button and drop hint. Session with zero rows: “No Log Entries”. Filter with zero rows: “No Matching Entries”. Keep window title at session file name. Maintain selected object only while present in current fetched results.

- [ ] **Step 6: Remove in-memory document/filter code and build**

Delete old files and PBX references/build files only after replacement UI compiles. Run:

```bash
xcodebuild -project LogViewer/LogViewer.xcodeproj -scheme LogViewer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
```

Expected: `** BUILD SUCCEEDED **` with no Swift 6 concurrency errors.

- [ ] **Step 7: Run full test suite and commit**

```bash
xcodebuild -project LogViewer/LogViewer.xcodeproj -scheme LogViewer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
git add LogViewer
git commit -m "feat: add Core Data log viewer workflow"
```

---

### Task 7: Requirement Audit and Fresh Verification

**Files:**
- Modify only files required by failures found below.

**Interfaces:**
- Consumes completed app and tests.
- Produces evidence for every requested behavior.

- [ ] **Step 1: Run complete automated verification**

```bash
swift test
xcodebuild -project LogViewer/LogViewer.xcodeproj -scheme LogViewer -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
xcodebuild -project LogViewer/LogViewer.xcodeproj -scheme LogViewer -destination 'generic/platform=macOS' CODE_SIGNING_ALLOWED=NO build
git diff --check
```

Expected: package tests pass, LogViewer tests pass, app build succeeds, diff check prints nothing.

- [ ] **Step 2: Audit source wiring for every entry path**

Use `rg` to prove File > Open and Command-O, toolbar open button, empty-state button, drop destination, shared `importFile(at:)`, Core Data insertion, toolbar search, and minimum predicate all exist. Inspect each match; search output alone is not proof.

- [ ] **Step 3: Inspect database and app metadata assumptions**

Confirm `.momd` exists in built app resources and `otool`/bundle inspection shows Core Data-linked executable. Confirm test target actually executes importer/predicate tests rather than only compiling them.

- [ ] **Step 4: Perform available Mac interaction checks**

Launch app if environment permits. Verify toolbar open, File > Open/Command-O, Finder drop, Warning+, search, invalid UTF-8 alert with preserved current rows, relaunch persistence, keyboard table selection, and toolbar accessibility labels. Report any unexecutable manual checks explicitly; never claim them from source inspection.

- [ ] **Step 5: Fix discovered gaps with red-green tests**

For each gap, first add focused failing test, run it red, implement smallest correction, rerun green, then repeat full commands from Step 1.

- [ ] **Step 6: Final commit if verification produced fixes**

```bash
git add LogViewer
git commit -m "fix: complete LogViewer import workflow"
```

Skip commit when worktree has no verification fixes.
