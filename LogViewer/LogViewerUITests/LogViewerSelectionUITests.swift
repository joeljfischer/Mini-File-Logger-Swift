import XCTest

final class LogViewerSelectionUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFilteringReplacesEverySelectedEntryDetailField() throws {
        let fixtureURL = try makeFixture()
        addTeardownBlock {
            try? FileManager.default.removeItem(
                at: fixtureURL.deletingLastPathComponent()
            )
        }

        let app = XCUIApplication()
        app.launch()
        importFixture(at: fixtureURL, into: app)

        let levelPicker = app.descendants(matching: .any)["minimumLogLevelPicker"]
        XCTAssertTrue(levelPicker.waitForExistence(timeout: 5))
        levelPicker.click()
        let allLevels = app.menuItems["All Levels"]
        XCTAssertTrue(allLevels.waitForExistence(timeout: 2))
        allLevels.click()

        let table = app.tables["logTable"]
        XCTAssertTrue(table.waitForExistence(timeout: 5))
        let debugRow = table.descendants(matching: .tableRow).containing(
            .staticText,
            identifier: "logRowLevel-1"
        ).firstMatch
        XCTAssertTrue(debugRow.waitForExistence(timeout: 2))
        debugRow.click()

        app.typeKey("f", modifierFlags: .command)
        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 2))
        searchField.typeText("database")

        let infoRow = table.descendants(matching: .tableRow).containing(
            .staticText,
            identifier: "logRowLevel-2"
        ).firstMatch
        XCTAssertTrue(infoRow.waitForExistence(timeout: 5))
        XCTAssertTrue(infoRow.isSelected)

        assertLabel("INF", for: "detailLevelCode", in: app)
        assertLabel("database", for: "detailCategory", in: app)
        assertLabel("2", for: "detailLine", in: app)
        assertLabel("database connected", for: "detailMessage", in: app)
        assertLabel(
            "INF [app|database] (2026-07-19T12:00:01Z): database connected",
            for: "detailRawLine",
            in: app
        )
        XCTAssertNotEqual(app.staticTexts["detailMessage"].label, "debug request")
        XCTAssertFalse(app.staticTexts["detailRawLine"].label.hasPrefix("DBG "))
    }

    @MainActor
    private func importFixture(at url: URL, into app: XCUIApplication) {
        let openControl = app.descendants(matching: .any)["openLogFileButton"]
        XCTAssertTrue(openControl.waitForExistence(timeout: 5))
        app.typeKey("o", modifierFlags: .command)

        let openButton = app.buttons["Open"]
        XCTAssertTrue(openButton.waitForExistence(timeout: 3))
        app.typeKey("g", modifierFlags: [.command, .shift])

        let locationField = app.sheets.textFields.firstMatch
        XCTAssertTrue(locationField.waitForExistence(timeout: 3))
        locationField.typeText(url.path())
        app.typeKey(.return, modifierFlags: [])

        let enabled = NSPredicate(format: "enabled == true")
        let enabledExpectation = XCTNSPredicateExpectation(
            predicate: enabled,
            object: openButton
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [enabledExpectation], timeout: 3),
            .completed
        )
        openButton.click()
    }

    @MainActor
    private func assertLabel(
        _ expected: String,
        for identifier: String,
        in app: XCUIApplication
    ) {
        let element = app.staticTexts[identifier]
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let predicate = NSPredicate(format: "label == %@", expected)
        let expectation = XCTNSPredicateExpectation(
            predicate: predicate,
            object: element
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [expectation], timeout: 5),
            .completed
        )
    }

    private func makeFixture() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LogViewerSelectionUITests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appending(path: "selection.log")
        let contents = """
        DBG [app|network] (2026-07-19T12:00:00Z): debug request
        INF [app|database] (2026-07-19T12:00:01Z): database connected
        WRN [app|storage] (2026-07-19T12:00:02Z): disk nearly full
        ERR [app|database] (2026-07-19T12:00:03Z): database failed
        CRT [app|storage] (2026-07-19T12:00:04Z): disk unavailable
        """
        try Data(contents.utf8).write(to: url, options: .atomic)
        return url
    }
}
