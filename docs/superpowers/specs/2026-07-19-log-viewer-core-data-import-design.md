# LogViewer Core Data Import Design

## Goal

Turn LogViewer into a single-log macOS viewer that imports a MiniFileLogger text file through standard Mac entry points, stores parsed rows in Core Data, and filters those rows through toolbar controls.

Opening a new file replaces the active imported log. LogViewer does not become a multi-file library or editor in this change.

## Mac Identity

LogViewer is a viewer utility. Its primary object is one imported `.log` or plain-text file, its primary selection is one parsed log row, and its main workflow is opening a file, narrowing visible rows, and inspecting a selected row.

The app uses one workspace window because imported data is an internal searchable representation rather than an editable document. Standard File > Open behavior, Command-O, a toolbar open command, an open panel, drag and drop from Finder, native toolbar search, keyboard table selection, and state restoration make the workflow fit macOS. This intentionally differs from an `NSDocument` app: LogViewer never saves changes back to source files and keeps only one active import.

## Architecture

### Persistence

Add an injected `PersistenceController` around `NSPersistentContainer`:

- Production uses SQLite in the app's Application Support container.
- Tests use an isolated in-memory store built from the same managed object model.
- The main-queue `viewContext` serves SwiftUI fetches only.
- A named private-queue import context performs row deletion and insertion.
- `viewContext.automaticallyMergesChangesFromParent` updates visible results after import saves.
- No Core Data managed object crosses a context or concurrency boundary.

Use a standard versioned `.xcdatamodeld` model containing:

`LogSession`

- `id: UUID`
- `fileName: String`
- `importedAt: Date`
- to-many `entries`, cascade delete

`StoredLogEntry`

- `id: UUID`
- `lineNumber: Int64`
- `levelCode: String?`
- `levelRank: Int16` (`-1` for unrecognized lines)
- `subsystem: String`
- `category: String`
- `timestamp: Date?`
- `message: String`
- `rawLine: String`
- required inverse relationship to `session`

Rows sort by `lineNumber`, preserving file order. A single session exists after each successful import.

### Parsing and Import

Keep parsing independent from Core Data. `LogParser` produces immutable, `Sendable` parsed values. `LogImportService` owns this pipeline:

1. Balance security-scoped file access with `startAccessingSecurityScopedResource()` and `stopAccessingSecurityScopedResource()`.
2. Read file data and decode UTF-8 away from main actor.
3. Parse MiniFileLogger lines, including multiline messages and unrecognized raw lines.
4. Enter import context and delete old session through its cascade relationship.
5. Insert new session and parsed rows, then save once.
6. Roll back on any insertion or save error, leaving previous persisted data intact.
7. Return imported file metadata to main actor.

The default MiniFileLogger maximum file size is 5 MB, so one background-context transaction gives atomic replacement without adding batch-operation merge machinery. Fetches use a batch size to bound UI memory.

### App State

`LogViewerState` coordinates current file metadata, import progress, presented errors, search text, minimum level, and open-panel presentation. Views depend on this state and the injected persistence controller rather than loading files themselves.

Search text is transient and clears after a successful new import. Minimum level persists through `AppStorage`, because it is a user viewing preference. Current imported Core Data rows and file name survive relaunch.

## Input Paths

Every input path calls the same `LogViewerState.importFile(at:)` method:

- File > Open… with Command-O.
- Always-visible toolbar open button.
- Empty-state Open Log File button.
- Dragging one supported file onto the window.

A focus-aware command coordinator lets File > Open and Edit > Find target the active LogViewer window without global notifications. The focused value stores a coordinator object, not a closure. The open panel accepts `.log` and plain-text UTTypes and allows one file. Drops reject unsupported items and refuse a second import while one is active.

## Filtering

Toolbar contains:

- Native `.searchable(text:isPresented:placement:prompt:)` toolbar search field bound to `searchText` and command-coordinator focus state.
- Minimum-level menu with All Levels, Verbose+, Debug+, Info+, Warning+, Error+, and Critical.

`StoredLogEntry.fetchRequest(searchText:minimumLevel:)` builds one Core Data predicate:

- Nonempty search: `rawLine CONTAINS[cd] searchText`.
- Selected minimum: `levelRank >= selected.sortOrder`.
- All Levels: no level predicate, so unrecognized raw lines remain visible.

Selecting Verbose+ or higher hides unrecognized rows because their rank is `-1`. Warning+ therefore displays Warning, Error, and Critical rows. Search and minimum predicates combine with logical AND.

`LogEntriesView` recreates its `@FetchRequest` when toolbar filters change and uses `fetchBatchSize`. Detail selection is stored as an `NSManagedObjectID`; the view resolves it only in `viewContext`.

## Affordance Map

| Element | Native control/API | Selection | Keyboard | Drag/drop | State | Accessibility |
|---|---|---|---|---|---|---|
| Open command | `Commands`, `fileImporter` | N/A | Command-O | N/A | Transient panel | Named “Open Log File” command |
| Toolbar open | `Button` in `ToolbarItem` | N/A | Full Keyboard Access | Accepts window-level drop | Always available unless importing | Label and help text |
| Search | `.searchable` with toolbar placement | Standard text selection | Command-F focuses it; Escape clears | Text editing conventions | Clears after import | Native search-field role |
| Minimum level | `Menu` and `Picker` | One value | Menu keyboard navigation | N/A | Persisted preference | Current choice announced |
| Log rows | SwiftUI `Table` | One row | Arrows move selection; Space/Return remain native | Window accepts file URL above rows | Selected object ID transient | Table with labelled columns |
| Detail pane | Native selectable `Text` | Text selection | Standard copy | N/A | Split position restored by system | Label/value structure |
| Empty state | `ContentUnavailableView` | N/A | Open button focusable | File drop | Derived from store | Clear title, description, action |

## Commands and Window Behavior

- Replace disabled New command with File > Open… and Command-O.
- Keep standard Close, Window, and Help behavior.
- Add Edit > Find > Find… with Command-F; it sets search presentation through the active window's command coordinator.
- Disable Open while an import is committing to avoid overlapping replacement transactions.
- Keep one window model for this scope; opening another file replaces current content after successful import.
- Window title shows imported file name. Relaunch shows last imported session without needing original file access.
- Toolbar button and menu items expose text labels to toolbar customization and accessibility even when rendered as symbols.

## Interoperability and Error Handling

Supported input is one local `.log` or plain-text file URL from the open panel or Finder drag. LogViewer reads but never modifies the source file. It does not retain a security-scoped URL after import; persisted parsed data is self-contained.

Cancellation is silent. Read, UTF-8 decode, Core Data load, and Core Data save failures produce a user-facing alert with a concise recovery suggestion. The old session remains visible after failed import. An empty valid file becomes an imported session with a dedicated “No Log Entries” state. A toolbar `ProgressView` replaces the open button while import runs, preventing duplicate commands without blocking row inspection.

## Accessibility

- Use native buttons, search field, menu, table/list, split view, and selectable text.
- Give symbol-only toolbar rendering explicit labels and help.
- Preserve system focus rings and keyboard navigation.
- Do not rely on log-level color alone; every row shows the textual level code.
- Verify contrast in light, dark, increased-contrast, and Differentiate Without Color modes.
- Announce import failure through alert focus and expose progress text to VoiceOver.

## Testing

Add a `LogViewerTests` unit-test target. Follow test-driven development for each behavior:

- Parser: known levels, timestamps with and without fractional seconds, multiline messages, unrecognized lines, and line numbering.
- Persistence: production model loads; test controller uses same model in memory.
- Import: parsed fields map correctly, background save merges into view context, a second successful import replaces first, empty files import, and failed import preserves previous rows.
- Filtering: case/diacritic-insensitive raw-line search, minimum rank behavior, All Levels includes unrecognized rows, and combined predicates.
- State: successful import resets search; failure does not replace title or rows; minimum level round-trips through its persisted raw value.

Fresh verification before completion:

- Run all `LogViewerTests` through `xcodebuild test`.
- Build LogViewer Debug with code signing disabled.
- Inspect built app metadata and source wiring for File > Open, toolbar open, file drop, Core Data injection, toolbar search, and minimum-level menu.
- Manually verify open-panel import, Command-O, toolbar import, Finder drop, Warning+ results, search results, failure alert, relaunch persistence, keyboard navigation, VoiceOver labels, light/dark appearance, and a representative large log. Any manual item not executable in the environment remains explicitly reported as unverified.

## Out of Scope

- Multiple saved import sessions or sidebar library.
- Multiple concurrent document windows.
- Editing or writing back to source log files.
- Live file watching or automatic reload.
- Importing multiple files in one operation.
- Custom log formats beyond MiniFileLogger lines and preserved raw fallback lines.
