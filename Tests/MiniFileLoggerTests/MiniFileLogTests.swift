//
//  MiniFileLogTests.swift
//  MiniFileLogger
//
//  Created by Joel Fischer on 11/30/24.
//

import Testing
@testable import MiniFileLogger

struct MiniFileLogTests {
    @Test func testStringInterpolationDefault() async throws {
        let testLog: MiniFileLog = "Testing \(100)"
        #expect(testLog.message == "Testing 100")
    }

    @Test func testStringInterpolationPublic() async throws {
        let testLog: MiniFileLog = "Testing \(100, privacy: .public)"
        #expect(testLog.message == "Testing 100")
    }

    @Test func testStringInterpolationPrivate() async throws {
        let testLog: MiniFileLog = "Testing \(100, privacy: .private)"
        #expect(testLog.message == "Testing [REDACTED]")
    }
}
