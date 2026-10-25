import XCTest

/// Walks through every screen and saves a screenshot of each, in English, Arabic, and English with
/// doubled strings (to expose truncation). Runs only when SCREENSHOT_DIR is set:
///   TEST_RUNNER_SCREENSHOT_DIR=/some/folder xcodebuild test ...
final class ScreenTourUITests: XCTestCase {
    private var folder: URL?

    override func setUpWithError() throws {
        guard let path = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"] else { throw XCTSkip("set TEST_RUNNER_SCREENSHOT_DIR to capture screenshots") }
        folder = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: folder!, withIntermediateDirectories: true)
        continueAfterFailure = false
    }

    /// Labels to accept for `text`: as is, and the ways NSDoubleLocalizedStrings repeats it.
    private func candidates(_ text: String) -> [String] { [text, text + text, text + " " + text] }

    private func find(_ query: XCUIElementQuery, _ text: String) -> XCUIElement {
        let options = candidates(text)
        return query.matching(NSPredicate(format: "label IN %@ OR placeholderValue IN %@", options, options)).firstMatch
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        try? app.screenshot().pngRepresentation.write(to: folder!.appendingPathComponent("\(name).png"))
    }

    func testTourEnglish() { tour(.english, prefix: "en") }
    func testTourArabic() { tour(.arabic, prefix: "ar") }
    func testAppearanceEnglish() { appearance(.english, prefix: "appearance-en") }
    func testAppearanceArabic() { appearance(.arabic, prefix: "appearance-ar") }
    func testTourDoubleLength() { tour(.englishDoubleLength, prefix: "double") }

    private func tour(_ language: LaunchLanguage, prefix: String) {
        let code = language.code
        let s = { (key: String) in UIStrings.t(key, code) }
        let app = XCUIApplication()
        app.launchArguments = language.arguments
        app.launch()

        let skip = find(app.buttons, s("onboarding.skipAccessibility"))
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        shot(app, "\(prefix)-01-tour")
        skip.tap()

        XCTAssertTrue(find(app.tabBars.buttons, s("vehicles.title")).waitForExistence(timeout: 5))
        shot(app, "\(prefix)-02-vehicles-empty")

        find(app.navigationBars.buttons, s("vehicles.add")).tap()
        let name = find(app.textFields, s("vehicleForm.name"))
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        shot(app, "\(prefix)-03-vehicle-form")
        name.tap()
        name.typeText("Duke 200")
        find(app.buttons, s("common.save")).tap()

        XCTAssertTrue(app.staticTexts["Duke 200"].waitForExistence(timeout: 5))
        shot(app, "\(prefix)-04-vehicles")
        app.staticTexts["Duke 200"].tap()

        let addService = find(app.buttons, s("detail.addService"))
        XCTAssertTrue(addService.waitForExistence(timeout: 5))
        shot(app, "\(prefix)-05-detail")

        addService.tap()
        let title = find(app.textFields, s("service.titleField"))
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Oil change")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)).tap()
        shot(app, "\(prefix)-06-service-form")
        app.swipeUp()
        shot(app, "\(prefix)-07-service-form-lower")
        app.swipeUp()
        shot(app, "\(prefix)-08-service-form-bottom")
        find(app.buttons, s("common.cancel")).tap()

        find(app.buttons, s("detail.filledPetrol")).tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        shot(app, "\(prefix)-09-quick-log")
        find(app.buttons, s("common.cancel")).tap()

        find(app.buttons, s("detail.lubedChain")).tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        shot(app, "\(prefix)-09b-quick-log-lube")
        find(app.buttons, s("common.cancel")).tap()

        find(app.tabBars.buttons, s("history.title")).tap()
        shot(app, "\(prefix)-10-history")

        find(app.tabBars.buttons, s("settings.title")).tap()
        shot(app, "\(prefix)-11-settings")
        app.swipeUp()
        shot(app, "\(prefix)-12-settings-lower")
        let feedback = find(app.buttons, s("settings.feedback"))
        for _ in 0..<6 where !feedback.exists { app.swipeUp() }
        if feedback.exists {
            feedback.tap()
            sleep(1)
            shot(app, "\(prefix)-13-feedback")
        }
    }

    /// The appearance picker: following the device, then Dark chosen, then Light chosen.
    private func appearance(_ language: LaunchLanguage, prefix: String) {
        let s = { (key: String) in UIStrings.t(key, language.code) }
        let app = XCUIApplication()
        app.launchArguments = language.arguments
        app.launch()
        find(app.buttons, s("onboarding.skipAccessibility")).tap()
        find(app.tabBars.buttons, s("settings.title")).tap()
        XCTAssertTrue(find(app.buttons, s("settings.darkTheme")).waitForExistence(timeout: 5))
        shot(app, "\(prefix)-1-follow-device")
        find(app.buttons, s("settings.darkTheme")).tap()
        sleep(1)
        shot(app, "\(prefix)-2-dark")
        find(app.buttons, s("settings.lightTheme")).tap()
        sleep(1)
        shot(app, "\(prefix)-3-light")
    }
}
