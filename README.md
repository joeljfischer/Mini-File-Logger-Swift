# MiniFileLogger (for Swift)
Mini File Logger is an Apple platform file logging library built around the same ergonomics and design of `os_log`.

Mini File Logger has several helpful features:
* Max file size rolling logs
* Maximum number of file logs
* Custom storage location for logs
* Custom naming scheme for logs
* Writing logs with a given level, subsystem, and category (like `os_log`)
* Automatically write to console using `print` or `os_log`

This allows you to build a system that logs both to `os_log` (for console output) and to MiniFileLogger.

### Installation
Installing is accomplished through Swift Package Manager.

#### Using Xcode
Go to your project settings, select the "Package Dependencies" tab, and press the "+" button. In the "Search or Enter Package URL" field, paste:

```
https://github.com/joeljfischer/Mini-File-Logger-Swift
```

Then, select "Add Package".

#### Using a Package.swift File
Once you have your Swift package set up, adding MiniFileLogger as a dependency is as easy as adding it to the `dependencies` value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/joeljfischer/Mini-File-Logger-Swift", .upToNextMajor(from: "0.0.0"))
]
```

### Requirements
| Platform                                             | Status                   |
| ---------------------------------------------------- | ------------------------ |
| iOS 18.0+                                            | Partially Tested         |
| macOS 15.0+                                          | Partially Tested         |
| watchOS 11.0+                                        | Partially Tested         |
| tvOS 18.0+                                           | Untested                 |
| visionOS 1.0+                                        | Untested                 |

### Usage
#### Initialization
You can create a file logger using the initializer:

```swift
static let fileLogger: FileLogger = {
    return FileLogger(
        directoryURL: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "my.company.containerid")!.appending(component: "logs"),
        maxFileCount: 5
    )
}()
```

There are additional options available for initialization if you prefer not to use the defaults.

#### Writing Logs
Writing a log is then fairly simple:

```swift
    fileLogger.writeLog("message", level: .debug, subsystem: "subsystem", category: "category")
```

`os_log` allows you to mark string interpolations as potentially containing private information, and `MiniFileLog` allows you to do the same!

```swift
    fileLogger.writeLog("This is my message: \(someData, privacy: .auto)", level: .debug, subsystem: "subsystem", category: "category")
```

There are three privacy options:
* `public` - The default, no redaction
* `private` - Always redacted
* `auto` - Redacted in release builds only

#### Recommended Usage
For ease of use, I'd recommend building a small wrapper that makes using `MiniFileLogger` as simple as possible.

```swift
nonisolated struct Logger {
    let subsystem: String
    let category: String
    let logger: Logger
    let fileLogger: FileLogger

    init(subsystem: String, category: String, fileLogger: FileLogger) {
        self.subsystem = subsystem
        self.category = category
        self.fileLogger = fileLogger
        self.logger = Logger(subsystem: subsystem, category: category)
    }

    func debug(_ message: MiniFileLog) {
        fileLogger.writeLog(message, level: .debug, subsystem: subsystem, category: category)
    }

    func info(_ message: MiniFileLog) {
        fileLogger.writeLog(message, level: .info, subsystem: subsystem, category: category)
    }

    func warning(_ message: MiniFileLog) {
        fileLogger.writeLog(message, level: .warning, subsystem: subsystem, category: category)
    }

    func error(_ message: MiniFileLog) {
        fileLogger.writeLog(message, level: .error, subsystem: subsystem, category: category)
    }

    func fault(_ message: MiniFileLog) {
        fileLogger.writeLog(message, level: .critical, subsystem: subsystem, category: category)
    }
}

nonisolated enum Log {
    static private let subsystemName = Platform.platformName // Or however you want to divide up subsystems.
    static private let fileLogger: FileLogger = {
        return FileLogger(
            directoryURL: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: SharedConstants.appGroupIdentifier)!.appending(component: "logs"),
            maxFileCount: 5
        )
    }()
    static var fileLogLocation: URL { fileLogger.baseDirectoryURL }

    static let app = RSLogger(subsystem: subsystemName, category: "App", fileLogger: fileLogger)
    static let location = RSLogger(subsystem: subsystemName, category: "Location", fileLogger: fileLogger)
    static let notification = RSLogger(subsystem: subsystemName, category: "Notification", fileLogger: fileLogger)
    static let settings = RSLogger(subsystem: subsystemName, category: "Settings", fileLogger: fileLogger)
    static let subscription = RSLogger(subsystem: subsystemName, category: "Subscription", fileLogger: fileLogger)
    static let sync = RSLogger(subsystem: subsystemName, category: "Sync", fileLogger: fileLogger)
    // And so on...
}
```

### In Use
This repository is in use in production in my app [Rainy Skies](https://apps.apple.com/us/app/rainy-skies/id1637453069)
