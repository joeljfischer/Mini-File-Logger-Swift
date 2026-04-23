import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let logFile = UTType(filenameExtension: "log") ?? .plainText
}

struct ContentView: View {
    @State private var document: LogDocument?
    @State private var selectedEntryID: LogEntry.ID?
    @State private var filterState = FilterState()
    @State private var isFileImporterPresented = false
    @State private var isDropTargeted = false

    private var filteredEntries: [LogEntry] {
        document?.entries.filter { filterState.matches($0) } ?? []
    }

    var body: some View {
        Group {
            if document != nil {
                loaded
            } else {
                empty
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.logFile, .plainText],
            allowsMultipleSelection: false
        ) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            open(url: url)
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleDrop(providers: providers)
        }
    }

    private var empty: some View {
        ContentUnavailableView {
            Label("No Log File Open", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Drop a MiniFileLogger .log file here, or click below to open one.")
        } actions: {
            Button("Open Log File") { isFileImporterPresented = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(isDropTargeted ? Color.accentColor.opacity(0.1) : .clear)
    }

    @ViewBuilder
    private var loaded: some View {
        if let doc = document {
            VSplitView {
                VStack(spacing: 0) {
                    FilterBar(filterState: filterState)
                    Divider()
                    LogTableView(entries: filteredEntries, selectedEntryID: $selectedEntryID)
                }
                .frame(minHeight: 200)

                Group {
                    if let entry = doc.entries.first(where: { $0.id == selectedEntryID }) {
                        LogDetailView(entry: entry)
                    } else {
                        Color.clear
                    }
                }
                .frame(minHeight: 140, idealHeight: 240)
                .onChange(of: filteredEntries.map(\.id), initial: true) { _, ids in
                    if selectedEntryID == nil || !ids.contains(where: { $0 == selectedEntryID }) {
                        selectedEntryID = ids.first
                    }
                }
            }
            .navigationTitle(doc.fileName)
            .toolbar {
                ToolbarItem {
                    Button("Reload", systemImage: "arrow.clockwise") { doc.load() }
                        .help("Reload log file from disk")
                }
                ToolbarItem {
                    TextField("Search", text: $filterState.searchText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }
            }
        }
    }

    private func open(url: URL) {
        _ = url.startAccessingSecurityScopedResource()
        document = LogDocument(url: url)
        selectedEntryID = nil
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            guard let url else { return }
            Task { @MainActor in open(url: url) }
        }
        return true
    }
}
