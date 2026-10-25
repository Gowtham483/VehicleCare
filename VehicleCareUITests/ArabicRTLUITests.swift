import XCTest

/// The app launched in Arabic, a right-to-left language. Positions are compared against English
/// so a layout that is not mirrored fails.
final class ArabicRTLUITests: XCTestCase {
    private let ar = UIStrings.table("ar")

    private func launch(_ language: LaunchLanguage) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = language.arguments
        app.launch()
        return app
    }

    private func skipTour(_ app: XCUIApplication, _ language: LaunchLanguage) {
        let skip = app.buttons[UIStrings.t("onboarding.skipAccessibility", language.code)]
        XCTAssertTrue(skip.waitForExistence(timeout: 10))
        skip.tap()
    }

    func testTourIsMirrored() {
        let width = { (app: XCUIApplication) in app.windows.firstMatch.frame.width }

        let english = launch(.english)
        let enSkip = english.buttons[UIStrings.t("onboarding.skipAccessibility", "en")]
        XCTAssertTrue(enSkip.waitForExistence(timeout: 10))
        XCTAssertGreaterThan(enSkip.frame.midX, width(english) / 2, "English: Skip is on the right")
        english.terminate()

        let arabic = launch(.arabic)
        let arSkip = arabic.buttons[ar["onboarding.skipAccessibility"]!]
        XCTAssertTrue(arSkip.waitForExistence(timeout: 10))
        XCTAssertLessThan(arSkip.frame.midX, width(arabic) / 2, "Arabic: Skip moves to the left")
        XCTAssertTrue(arabic.staticTexts[ar["onboarding.servicesTitle"]!].exists, "slide text is Arabic")
    }

    func testTabsAreMirrored() {
        let app = launch(.arabic)
        skipTour(app, .arabic)
        let vehicles = app.tabBars.buttons[ar["vehicles.title"]!]
        let settings = app.tabBars.buttons[ar["settings.title"]!]
        XCTAssertTrue(vehicles.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(vehicles.frame.midX, settings.frame.midX, "first tab is on the right in RTL")
        XCTAssertTrue(app.staticTexts[ar["vehicles.emptyTitle"]!].exists)
    }

    func testPluralsAndFormsAreTranslatedInTheApp() {
        let app = launch(.arabic)
        skipTour(app, .arabic)
        app.tabBars.buttons[ar["settings.title"]!].tap()
        // 14 days must use the "many" form (14 يومًا), proving the stringsdict is bundled and applied.
        let interval = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "14 يومًا")).firstMatch
        XCTAssertTrue(interval.waitForExistence(timeout: 5), "expected the Arabic plural form for 14 days")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "7 أيام")).firstMatch.exists,
                      "7 days uses the 'few' form")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "30 يومًا")).firstMatch.exists,
                      "the chain-lube interval (30 days) is shown with the Arabic plural")
    }

    func testKeyboardStillDismissesInArabic() {
        let app = launch(.arabic)
        skipTour(app, .arabic)
        app.navigationBars.buttons[ar["vehicles.add"]!].tap()
        let name = app.textFields[ar["vehicleForm.name"]!]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        if !app.keyboards.firstMatch.waitForExistence(timeout: 5) { name.tap() } // the soft keyboard can lag behind the sheet animation
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 5)
    }

    func testFeedbackScreenIsArabicAndFallbackWorks() {
        let app = launch(.arabic)
        skipTour(app, .arabic)
        app.tabBars.buttons[ar["settings.title"]!].tap()
        let feedback = app.buttons[ar["settings.feedback"]!]
        for _ in 0..<8 where !feedback.exists { app.swipeUp() }
        XCTAssertTrue(feedback.exists)
        feedback.tap()
        XCTAssertTrue(app.navigationBars[ar["feedback.title"]!].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[ar["feedback.addMedia"]!].exists)
        let message = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        message.tap()
        message.typeText("Hello")
        app.navigationBars[ar["feedback.title"]!].tap()
        app.navigationBars[ar["feedback.title"]!].buttons[ar["feedback.send"]!].tap()
        XCTAssertTrue(app.staticTexts[ar["feedback.noMailTitle"]!].waitForExistence(timeout: 5), "Mail fallback dialog is Arabic")
    }
}
