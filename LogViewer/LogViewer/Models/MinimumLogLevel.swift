enum MinimumLogLevel: String, CaseIterable, Identifiable, Sendable {
    case all
    case verbose
    case debug
    case info
    case warning
    case error
    case critical

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
