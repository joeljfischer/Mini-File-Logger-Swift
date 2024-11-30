import Testing
@testable import MiniFileLogger

@Test func testInitialization() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    let fileLogger = FileLogger()
    #expect(fileLogger != nil)
}
