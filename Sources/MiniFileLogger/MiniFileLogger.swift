import Foundation

open class FileLogger {
    /// Maximum file size of a log in kilobytes
    public let maxFileSize: UInt64

    /// Maximum number of files at rest on disk
    public let maxFileCount: Int

    /// The base file name to write logs to in the directory. For example, if this is "log", the newest log file will be
    /// `log.log`, then `log1.log`, etc.
    public let baseFileName: String

    /// The directory to store log files within. Defaults to `/Caches/`. Any directory you enter will automatically be extended to include `/logs/{{platform}}` in case you'd like to store this in a shared container (recommended). For example, on watchOS, the default log location will be `/Caches/logs/watchOS/log.log`.
    public let baseDirectoryURL: URL

    /// The date format to use in the log string. Defaults to `.abbreviated`.
    public let dateFormat: Date.FormatStyle.DateStyle

    /// The time format to use in the log string. Defaults to `.standard`.
    public let timeFormat: Date.FormatStyle.TimeStyle

    /// Whether or not the file logger is disabled (currently only automatically disabled in previews)
    public let isDisabled: Bool

    public var directory: URL {
        baseDirectoryURL.appendingPathComponent("logs/\(Self.platformName)")
    }

    private var directoryPath: String {
        directory.path(percentEncoded: false)
    }
    
    /// Initialize a file logger with a given configuration
    /// - Parameters:
    ///   - directoryURL: The directory to add the log folder to. Defaults to `/Caches/`. Any directory you enter will automatically be extended to include `/logs/{{platform}}` in case you'd like to store this in a shared container (recommended). For example, on watchOS, the default log location will be `/Caches/logs/watchOS/log.log`.
    ///   - fileName: The log name to use. Depending on the `maxFileCount`, this could result in numbers being appended to the log name. For example, if `maxFileCount` is `4` and the `fileName` is `log`, you can expect to see `log.log`, `log1.log`, `log2.log`, and `log3.log` in your folder, in decending order of time (`log.log` always being the newest).
    ///   - maxFileCount: The maximum number of files to store on disk before deleting the oldest.
    ///   - maxFileSize: The maxiumum file size before rolling to a new file.
    ///   - dateFormat: The date format to use when writing a log to the file. Defaults to `.abbreviated`.
    ///   - timeFormat: The time format to use when writing a log to the file. Defaults to `.standard`.
    public init(
        directoryURL: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!,
        fileName: String = "log",
        maxFileCount: Int = 4,
        maxFileSize: UInt64 = 1024 * 5,
        dateFormat: Date.FormatStyle.DateStyle = .abbreviated,
        timeFormat: Date.FormatStyle.TimeStyle = .standard,
        isDisabled: Bool = FileLogger._isPreview
    ) {
        self.baseDirectoryURL = directoryURL
        self.baseFileName = fileName
        self.maxFileCount = maxFileCount
        self.maxFileSize = maxFileSize
        self.dateFormat = dateFormat
        self.timeFormat = timeFormat
        self.isDisabled = isDisabled
        // TODO: Add an option to print or log to OSLog automatically

        createDirectoryIfNeeded()
    }

    /// Deletes all files in the current directory
    public func deleteAll() throws {
        for filePath in try FileManager.default.contentsOfDirectory(atPath: directoryPath) {
            do { try FileManager.default.removeItem(atPath: filePath) } catch {
                print("📜❌ FileLogger failed to delete item at path \(filePath) with error: \(error)")
                continue
            }
        }
    }

    /// Write a log with a given message, level, and subsystem / category
    public func writeLog(_ message: MiniFileLog, level: Level, subsystem: String, category: String) {
        let logURL = directory.appendingPathComponent("\(baseFileName).log")
        if !FileManager.default.fileExists(atPath: logURL.path(percentEncoded: false)) { setup() }

        let logHandle: FileHandle
        do { logHandle = try FileHandle(forWritingTo: logURL) } catch {
            print("📜❌ FileLogger failed to get a handle for writing to \(logURL) with error: \(error)")
            return
        }

        do {
            try logHandle.seekToEnd()
            let string = "\(level) [\(subsystem)\\\(category)] \(Date.now.formatted(date: dateFormat, time: timeFormat)): \(message)\n"
            try logHandle.write(contentsOf: string.data(using: .utf8)!)
            try logHandle.close()
        } catch {
            print("📜❌ FileLogger failed to write log message: \(message) to \(logURL) with error: \(error)")
            return
        }

        do {
            let attrs = try FileManager.default.attributesOfItem(atPath: logURL.path(percentEncoded: false))
            guard let fileSizeBytes = attrs[.size] as? UInt64 else {
                print("📜❌ FileLogger failed to get file size of \(logURL)")
                return
            }

            let fileSizeKB = fileSizeBytes * 1024
            if fileSizeKB > maxFileSize { setup() }
        } catch {
            print("📜❌ FileLogger failed to get attributes of item at \(logURL) with error: \(error)")
            return
        }
    }

    static let platformName: String = {
        var platformName: String
        #if os(iOS)
        platformName = "iOS"
        #elseif os(watchOS)
        platformName = "watchOS"
        #elseif os(macOS)
        platformName = "macOS"
        #elseif os(visionOS)
        platformName = "visionOS"
        #elseif os(tvOS)
        platformName = "tvOS"
        #else
        platformName = "unknown"
        #endif

        #if targetEnvironment(simulator)
        platformName.append("-simulator")
        #elseif targetEnvironment(macCatalyst)
        platformName.append("-macCatalyst")
        #endif

        if let extensionData = Bundle.main.infoDictionary?["NSExtension"] as? [String: String],
           let extensionId = extensionData["NSExtensionPointIdentifier"],
           extensionId == "com.apple.widgetkit-extension" {
            platformName.append("-widget")
        }

        return platformName
    }()

    public static var _isPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        false
        #endif
    }

    /// Sets up for a new log file. Renames all existing log files up one number and creates a new empty log file at `baseFileName.log`.
    private func setup() {
        let logURLs: [URL]
        do {
            logURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).filter {
                $0.lastPathComponent.contains(baseFileName)
            }.sorted(using: KeyPathComparator(\.lastPathComponent, order: .reverse))
        } catch {
            print("📜❌ FileLogger failed to get files in directory: \(directory) with error: \(error)")
            return
        }

        for logURL in logURLs {
            let currentNumber = numberFromFileURL(logURL)
            let newNumber = (currentNumber != nil) ? (currentNumber! + 1) : 1
            let newURL = logURL.deletingLastPathComponent().appending(path: "\(baseFileName)\(newNumber).log")
            do { try FileManager.default.moveItem(at: logURL, to: newURL) } catch {
                print("📜❌ FileLogger failed to move file at url \(logURL) to \(newURL) with error: \(error)")
            }
        }

        let success = FileManager.default.createFile(atPath: directoryPath.appending("\(baseFileName).log"), contents: nil)
        if !success {
            print("📜❌ FileLogger failed to create file at path \(directoryPath.appending("\(baseFileName).log"))")
        }
    }

    /// Gets all logs in the log directory, deleting anything that isn't a log and all logs that are above the max file count
    private func cleanup() {
        let directoryURLs: [URL]
        do { directoryURLs = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) } catch {
            print("📜❌ FileLogger failed to get files in directory: \(directory) with error: \(error)")
            return
        }

        for fileURL in directoryURLs {
            guard let fileName = fileURL.lastPathComponent.split(separator: ".").first else {
                print("📜❌ FileLogger failed to get file name for file url \(fileURL)")
                continue
            }

            if !(fileURL.pathExtension == "log") || !fileName.localizedCaseInsensitiveContains(baseFileName) {
                do { try FileManager.default.removeItem(at: fileURL) } catch {
                    print("📜❌ FileLogger failed to delete item at url \(fileURL) with error: \(error)")
                }
            }

            if let fileNumber = numberFromFileURL(fileURL), fileNumber > (maxFileCount - 1) {
                do { try FileManager.default.removeItem(at: fileURL) } catch {
                    print("📜❌ FileLogger failed to delete item at url \(fileURL) with error: \(error)")
                }
            }
        }
    }

    private func createDirectoryIfNeeded() {
        guard !FileManager.default.fileExists(atPath: directoryPath) else { return }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            print("📜✅ Created file log directory at \(directory)")
        } catch {
            print("📜❌ FileLogger failed to create directory at \(directory)")
        }
    }

    private func numberFromFileURL(_ fileURL: URL) -> Int? {
        guard let fileName = fileURL.lastPathComponent.split(separator: ".").first else { return nil }
        return Int(String(fileName.suffix(1)))
    }

    // MARK: - Level Enum
    public enum Level: CustomStringConvertible {
        case verbose, debug, info, warning, error, critical

        public var description: String {
            switch self {
            case .verbose: "VRB"
            case .debug: "DBG"
            case .info: "INF"
            case .warning: "WRN"
            case .error: "ERR"
            case .critical: "CRT"
            }
        }
    }
}
