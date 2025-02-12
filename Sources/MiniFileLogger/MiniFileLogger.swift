import Foundation
import OSLog

open class FileLogger {
    /// Maximum file size of a log in bytes
    public let maxFileSize: UInt64

    /// Maximum number of files at rest on disk
    public let maxFileCount: Int

    /// The base file name to write logs to in the directory. For example, if this is "log", the newest log file will be
    /// `log.log`, then `log1.log`, etc.
    public let baseFileName: String

    /// The directory to store log files within. Defaults to `/Caches/logs/`. If you have a shared container, it is recommended that you use a directory within that. The directory will be created if needed. Any directory you use will be extended with additional folders for each platform, e.g. `{{baseDirectoryURL}}/watchOS/`. See `directory` for more details.
    public let baseDirectoryURL: URL

    /// Whether or not the file logger is disabled (currently only automatically disabled in previews)
    public let isDisabled: Bool

    /// If and how to log to the console. Defaults to `oslog`.
    public let consoleLogger: ConsoleLogger

    /// The directory to store log files within for this platform. Defaults to `{{baseDirectoryURL}}/logs/{{platform}}`. For example, on watchOS, the default log location will be `{{baseDirectoryURL}}/logs/watchOS/log{{n}}.log`.
    public var directory: URL {
        baseDirectoryURL.appendingPathComponent("\(Self.platformName)", isDirectory: true)
    }

    private var directoryPath: String {
        directory.path(percentEncoded: false)
    }

    private var osLoggers = [String: Logger]()

    /// Initialize a file logger with a given configuration
    /// - Parameters:
    ///   - directoryURL: The directory to store log files within. Defaults to `/Caches/logs/`. If you have a shared container, it is recommended that you use a directory within that. The directory will be created if needed. Any directory you use will be extended with additional folders for each platform, e.g. `{{baseDirectoryURL}}/watchOS/`. See `directory` for more details.
    ///   - fileName: The log name to use. Depending on the `maxFileCount`, this could result in numbers being appended to the log name. For example, if `maxFileCount` is `4` and the `fileName` is `log`, you can expect to see `log.log`, `log1.log`, `log2.log`, and `log3.log` in your folder, in decending order of time (`log.log` always being the newest).
    ///   - maxFileCount: The maximum number of files to store on disk before deleting the oldest.
    ///   - maxFileSize: The maxiumum file size before rolling to a new file (in bytes).
    ///   - isDisabled: Whether or not to disable the file logger. By default `true` only in Swift Canvas/Preview environments.
    ///   - consoleLogger: Whether and how to log to the console. Defaults to `oslog`.
    public init(
        directoryURL: URL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appending(component: "logs", directoryHint: .isDirectory),
        fileName: String = "log",
        maxFileCount: Int = 4,
        maxFileSize: UInt64 = 5 * 1024 * 1024, // 5 megabytes
        isDisabled: Bool = FileLogger._isPreview,
        consoleLogger: ConsoleLogger = .oslog
    ) {
        self.baseDirectoryURL = directoryURL
        self.baseFileName = fileName
        self.maxFileCount = maxFileCount
        self.maxFileSize = maxFileSize
        self.isDisabled = isDisabled
        self.consoleLogger = consoleLogger

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

        let string = "\(level) [\(subsystem)|\(category)] (\(Date.now.ISO8601Format(.iso8601))): \(message)\n"
        switch consoleLogger {
        case .none: break
        case .print: print(string)
        case .oslog: logToOSLog(message, level: level, subsystem: subsystem, category: category)

        }
        guard !isDisabled else { return }

        let logHandle: FileHandle
        do { logHandle = try FileHandle(forWritingTo: logURL) } catch {
            print("📜❌ FileLogger failed to get a handle for writing to \(logURL) with error: \(error)")
            return
        }

        do {
            try logHandle.seekToEnd()
            try logHandle.write(contentsOf: string.data(using: .utf8)!)
            try logHandle.close()
        } catch {
            print("📜❌ FileLogger failed to write log message: \(message) to \(logURL) with error: \(error)")
            return
        }

        do {
            let fileSizeBytes = try logURL.resourceValues(forKeys: [.totalFileSizeKey]).totalFileSize ?? 0
            if fileSizeBytes > maxFileSize { setup() }
        } catch {
            print("📜❌ FileLogger failed to get attributes of item at \(logURL) with error: \(error)")
            return
        }
    }

    public static var _isPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
        #else
        false
        #endif
    }

    // MARK: - Private
    // MARK: Lifecycle
    /// Sets up for a new log file. Renames all existing log files up one number and creates a new empty log file at `baseFileName.log`. Will `cleanup()` when finished.
    private func setup() {
        guard !isDisabled else { return }

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
            let newFileName: String
            if let currentNumber = numberFromFileURL(logURL) {
                let newNumber = (currentNumber < maxFileCount) ? (currentNumber + 1) : 1
                newFileName = "\(baseFileName)\(newNumber).log"
            } else {
                newFileName = "\(baseFileName)1.log"
            }

            // TODO: Delete old file at name if it exists
            let newURL = directory.appending(path: newFileName)
            do { try FileManager.default.moveItem(at: logURL, to: newURL) } catch {
                print("📜❌ FileLogger failed to move file at url \(logURL) to \(newURL) with error: \(error)")
            }
        }

        let success = FileManager.default.createFile(atPath: directoryPath.appending("\(baseFileName).log"), contents: nil)
        if !success {
            print("📜❌ FileLogger failed to create file at path \(directoryPath.appending("\(baseFileName).log"))")
        } else {
            cleanup()
        }
    }

    /// Gets all logs in the log directory, deleting anything that isn't a log and the oldest logs above the max file count
    private func cleanup() {
        guard !isDisabled else { return }

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

    // MARK: Utilities
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
        let numberString = String(fileName.dropFirst(3))

        return Int(numberString)
    }

    private func logToOSLog(_ message: MiniFileLog, level: Level, subsystem: String, category: String) {
        var logger: Logger
        if osLoggers["\(subsystem)|\(category)"] == nil {
            osLoggers["\(subsystem)|\(category)"] = Logger(subsystem: subsystem, category: category)
        }
        logger = osLoggers["\(subsystem)|\(category)"]!
        switch level {
        case .verbose: logger.trace("\(message.message)")
        case .debug: logger.debug("\(message.message)")
        case .info: logger.info("\(message.message)")
        case .warning: logger.warning("\(message.message)")
        case .error: logger.error("\(message.message)")
        case .critical: logger.critical("\(message.message)")
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

    public enum ConsoleLogger {
        case none, print, oslog
    }
}
