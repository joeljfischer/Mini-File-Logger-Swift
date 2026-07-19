import Foundation
import Observation

@MainActor
@Observable
final class LogViewerState {
    var searchText = ""
    var minimumLevel: MinimumLogLevel {
        didSet {
            defaults.set(minimumLevel.rawValue, forKey: Self.minimumLevelKey)
        }
    }
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

        do {
            _ = try await importer.importFile(at: url)
            searchText = ""
        } catch {
            presentedError = LogViewerError(error)
        }
    }

    private static let minimumLevelKey = "minimumLogLevel"
}
