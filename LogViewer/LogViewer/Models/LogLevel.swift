import SwiftUI

enum LogLevel: String, CaseIterable, Identifiable, Sendable {
    case verbose = "VRB"
    case debug   = "DBG"
    case info    = "INF"
    case warning = "WRN"
    case error   = "ERR"
    case critical = "CRT"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .verbose:  "Verbose"
        case .debug:    "Debug"
        case .info:     "Info"
        case .warning:  "Warning"
        case .error:    "Error"
        case .critical: "Critical"
        }
    }

    var color: Color {
        switch self {
        case .verbose:  .secondary
        case .debug:    .blue
        case .info:     .primary
        case .warning:  .orange
        case .error:    .red
        case .critical: .purple
        }
    }

    var sortOrder: Int16 {
        switch self {
        case .verbose:  0
        case .debug:    1
        case .info:     2
        case .warning:  3
        case .error:    4
        case .critical: 5
        }
    }
}
