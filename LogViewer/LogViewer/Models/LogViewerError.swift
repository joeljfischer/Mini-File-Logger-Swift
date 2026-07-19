import Foundation

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
        case .storeLoadFailed(let detail):
            "Could not load log database: \(detail)"
        case .readFailed(let detail):
            "Could not read log file: \(detail)"
        case .invalidUTF8:
            "Log file is not valid UTF-8 text."
        case .storeSaveFailed(let detail):
            "Could not save imported log: \(detail)"
        }
    }
}
