import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let logFile = UTType(filenameExtension: "log") ?? .plainText
}

struct ContentView: View {
    @State private var documents: [LogDocument] = []
    @State private var selectedDocumentID: LogDocument.ID?
    @State private var selectedEntryID: LogEntry.ID?
    @State private var filterState = FilterState()
    @State private var isFileImporterPresented = false

    private var selectedDocument: LogDocument? {
        documents.first { $0.id == selectedDocumentID }
    }

    private var filteredEntries: [LogEntry] {
        selectedDocument?.entries.filter { filterState.matches($0) } ?? []
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 220)
        } detail: {
            detail
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.logFile, .plainText],
            allowsMultipleSelection: true
        ) { result in
            guard case .success(let urls) = result else { return }
            for url in urls {
                _ = url.startAccessingSecurityScopedResource()
                let doc = LogDocument(url: url)
                documents.append(doc)
                selectedDocumentID = doc.id
                selectedEntryID = nil
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        List(documents, selection: $selectedDocumentID) { doc in
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(doc.fileName).font(.body)
                    Text("\(doc.entries.count) entries")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: doc.isWatching
                      ? "antenna.radiowaves.left.and.right"
                      : "doc.text")
                .foregroundStyle(doc.isWatching ? .green : .secondary)
            }
            .tag(doc.id)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { isFileImporterPresented = true } label: {
                    Label("Open Log File", systemImage: "plus")
                }
            }
        }
        .onChange(of: selectedDocumentID) { selectedEntryID = nil }
    }

    // MARK: Detail

    @ViewBuilder
    private var detail: some View {
        if let doc = selectedDocument {
            VSplitView {
                VStack(spacing: 0) {
                    FilterBar(filterState: filterState)
                    Divider()
                    LogTableView(entries: filteredEntries, selectedEntryID: $selectedEntryID)
                }
                .frame(minHeight: 200)

                Group {
                    if let entry = selectedDocument?.entries.first(where: { $0.id == selectedEntryID }) {
                        LogDetailView(entry: entry)
                    } else {
                        ContentUnavailableView(
                            "Select a Log Entry",
                            systemImage: "text.alignleft",
                            description: Text("Select an entry above to see its details.")
                        )
                    }
                }
                .frame(minHeight: 140, idealHeight: 240)
            }
            .toolbar {
                ToolbarItem {
                    Button(doc.isWatching ? "Stop Watching" : "Watch File") {
                        if doc.isWatching { doc.stopWatching() } else { doc.startWatching() }
                    }
                    .help(doc.isWatching ? "Stop watching for new log entries" : "Watch file for new log entries")
                }
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
        } else {
            ContentUnavailableView(
                "No Log File Open",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Click + to open a MiniFileLogger .log file.")
            )
        }
    }
}
