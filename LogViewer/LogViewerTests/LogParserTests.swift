import Foundation
import Testing
@testable import LogViewer

struct LogParserTests {
    @Test func keepsPhysicalLineNumbersAndMultilineMessages() throws {
        let text = """

        WRN [com.example|network] (2026-07-19T12:00:00Z): First line
        continuation
        ERR [com.example|storage] (2026-07-19T12:00:01.125Z): Disk full
        """
        let entries = LogParser.parse(fileContents: text)
        #expect(entries.map(\.lineNumber) == [2, 4])
        #expect(entries[0].message == "First line\ncontinuation")
        #expect(entries[0].level == .warning)
        #expect(entries[1].timestamp != nil)
    }

    @Test func preservesFirstUnrecognizedLine() {
        let entries = LogParser.parse(fileContents: "not MiniFileLogger output")
        #expect(entries.count == 1)
        #expect(entries[0].level == nil)
        #expect(entries[0].rawLine == "not MiniFileLogger output")
    }
}
