//
//  MiniFileLoggerTests.swift
//  MiniFileLogger
//
//  Created by Joel Fischer on 11/30/24.
//

import Foundation
import Testing
@testable import MiniFileLogger

@Suite("Default File Logger", .serialized) class WriteLogTests {
    let fileLogger: FileLogger
    
    init() throws {
        fileLogger = FileLogger()
        try clearDirectory(for: fileLogger)
    }
    
    deinit {
        try? clearDirectory(for: fileLogger)
    }
    
    @Test func testDefaultInitialization() async throws {
        #expect(fileLogger != nil)
    }
    
    @Test func testWriteLog() async throws {
        fileLogger.writeLog("Test log", level: .debug, subsystem: "Test", category: "Test")
        try checkDirectory(for: fileLogger, expectedNumLogFiles: 1)
    }

    @Test func testWriteFiveLog() async throws {
        for _ in 0..<5 {
            fileLogger.writeLog("Test log", level: .debug, subsystem: "Test", category: "Test")
        }
        try checkDirectory(for: fileLogger, expectedNumLogFiles: 1)

        // TODO: Check file for correct number of lines and format of data
    }

    @Test func testWrite5000Log() async throws {
        for _ in 0..<5000 {
            fileLogger.writeLog("Test log", level: .debug, subsystem: "Test", category: "Test")
        }
        try checkDirectory(for: fileLogger, expectedNumLogFiles: 1)

        // TODO: Check file for correct number of lines and format of data
    }

    @Test func testRolloverToNewFile() async throws {
        
    }

    // MARK: Helpers
    private func checkDirectory(for fileLogger: FileLogger, expectedNumLogFiles: Int) throws {
        let baseDirectoryURL = fileLogger.baseDirectoryURL
        let contents = try FileManager.default.contentsOfDirectory(at: baseDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        
        #expect(contents.count == 1)
        
        let platformLogsDirectoryURL = contents.first!
        #expect(platformLogsDirectoryURL.lastPathComponent == FileLogger.platformName)
        
        let logs = try FileManager.default.contentsOfDirectory(at: platformLogsDirectoryURL, includingPropertiesForKeys: nil)
        #expect(logs.count == expectedNumLogFiles, "Log count: \(logs.count), expected: \(expectedNumLogFiles). All files in directory: \(logs)")
    }
    
    private func clearDirectory(for fileLogger: FileLogger) throws {
        let contents = try FileManager.default.contentsOfDirectory(at: fileLogger.directory, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
        
        for url in contents {
            try FileManager.default.removeItem(at: url)
        }
    }
}
