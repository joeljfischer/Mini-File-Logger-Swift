import CoreData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let logFile = UTType(filenameExtension: "log") ?? .plainText
}

struct ContentView: View {
    @Bindable var state: LogViewerState

    let commandCoordinator: LogViewerCommandCoordinator

    @FetchRequest private var sessions: FetchedResults<LogSession>
    @State private var selectedEntryID: NSManagedObjectID?
    @State private var isDropTargeted = false

    init(
        state: LogViewerState,
        commandCoordinator: LogViewerCommandCoordinator
    ) {
        self.state = state
        self.commandCoordinator = commandCoordinator

        let request = LogSession.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "importedAt", ascending: false)
        ]
        request.fetchLimit = 1
        _sessions = FetchRequest(fetchRequest: request, animation: .default)
    }

    private var currentSession: LogSession? {
        sessions.first
    }

    var body: some View {
        Group {
            if let session = currentSession {
                LogTableView(
                    session: session,
                    searchText: state.searchText,
                    minimumLevel: state.minimumLevel,
                    selectedEntryID: $selectedEntryID
                )
            } else {
                noFileView
            }
        }
        .background(isDropTargeted ? Color.accentColor.opacity(0.08) : .clear)
        .navigationTitle(currentSession?.fileName ?? "LogViewer")
        .focusedSceneValue(\.logViewerCommandCoordinator, commandCoordinator)
        .fileImporter(
            isPresented: $state.isImporterPresented,
            allowedContentTypes: [.logFile, .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                Task { await state.importFile(at: url) }
            case .failure(let error):
                guard (error as? CocoaError)?.code != .userCancelled else { return }
                state.presentedError = .openFailed(error.localizedDescription)
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            guard let url = urls.first else { return false }
            Task { await state.importFile(at: url) }
            return true
        } isTargeted: { isTargeted in
            isDropTargeted = isTargeted
        }
        .alert("Could Not Open Log File", isPresented: isErrorPresented) {
            Button("OK") {
                state.presentedError = nil
            }
        } message: {
            Text(state.presentedError?.localizedDescription ?? "An unknown error occurred.")
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if state.isImporting {
                    ProgressView()
                        .accessibilityLabel("Importing Log File")
                } else {
                    Button("Open Log File", systemImage: "folder") {
                        state.presentImporter()
                    }
                    .accessibilityIdentifier("openLogFileButton")
                }
            }

            ToolbarItem {
                Picker("Minimum Log Level", selection: $state.minimumLevel) {
                    ForEach(MinimumLogLevel.allCases) { level in
                        Text(level.displayName).tag(level)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("minimumLogLevelPicker")
            }
        }
        .searchable(
            text: $state.searchText,
            isPresented: $state.isSearchPresented,
            placement: .toolbar,
            prompt: "Search Logs"
        )
    }

    private var noFileView: some View {
        ContentUnavailableView {
            Label("No Log File Open", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Drop a MiniFileLogger .log file here, or open one from the toolbar.")
        } actions: {
            Button("Open Log File") {
                state.presentImporter()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var isErrorPresented: Binding<Bool> {
        Binding(
            get: { state.presentedError != nil },
            set: { isPresented in
                if !isPresented {
                    state.presentedError = nil
                }
            }
        )
    }
}
