import SwiftUI

@main
@MainActor
struct LogViewerApp: App {
    @State private var persistenceController: PersistenceController
    @State private var importService: LogImportService
    @State private var state: LogViewerState
    @State private var commandCoordinator: LogViewerCommandCoordinator

    init() {
        let persistenceController = PersistenceController()
        let importer = LogImportService(persistenceController: persistenceController)
        let state = LogViewerState(importer: importer)

        _persistenceController = State(initialValue: persistenceController)
        _importService = State(initialValue: importer)
        _state = State(initialValue: state)
        _commandCoordinator = State(
            initialValue: LogViewerCommandCoordinator(state: state)
        )
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if persistenceController.isLoaded {
                    ContentView(state: state, commandCoordinator: commandCoordinator)
                        .environment(persistenceController)
                        .environment(
                            \.managedObjectContext,
                            persistenceController.viewContext
                        )
                } else if let error = persistenceController.loadError {
                    ContentUnavailableView {
                        Label("Log Database Unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    }
                } else {
                    ProgressView("Loading Logs")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            await persistenceController.load()
                        }
                }
            }
            .frame(minWidth: 760, minHeight: 520)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            LogViewerCommands()
        }
    }
}
