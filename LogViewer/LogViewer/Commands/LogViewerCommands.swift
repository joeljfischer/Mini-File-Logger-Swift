import SwiftUI

@MainActor
final class LogViewerCommandCoordinator {
    private let state: LogViewerState

    init(state: LogViewerState) {
        self.state = state
    }

    var isImporting: Bool { state.isImporting }

    func presentImporter() {
        state.presentImporter()
    }

    func focusSearch() {
        state.focusSearch()
    }
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
            Button("Open…") {
                coordinator?.presentImporter()
            }
            .keyboardShortcut("o")
            .disabled(coordinator == nil || coordinator?.isImporting == true)
        }

        CommandGroup(after: .textEditing) {
            Button("Find…") {
                coordinator?.focusSearch()
            }
            .keyboardShortcut("f")
            .disabled(coordinator == nil)
        }
    }
}
