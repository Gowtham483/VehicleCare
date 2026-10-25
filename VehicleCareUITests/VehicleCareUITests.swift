import XCTest

/// End-to-end checks that need a real UI: keyboard behaviour, and the new Support screens.
final class VehicleCareUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = LaunchLanguage.english.arguments
        app.launch()
        // Skip the first-run tour.
        XCTAssertTrue(app.buttons["Skip tour"].waitForExistence(timeout: 10))
        app.buttons["Skip tour"].tap()
        XCTAssertTrue(app.tabBars.buttons["Settings"].waitForExistence(timeout: 5))
    }

    /// Brightness (0...1) of the page background, sampled in the left margin where only the background shows.
    private func backgroundBrightness() -> Double {
        guard let image = app.screenshot().image.cgImage else { return -1 }
        var pixel = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return -1 }
        let x = 6, y = Int(Double(image.height) * 0.6)
        context.draw(image, in: CGRect(x: -x, y: -(image.height - 1 - y), width: image.width, height: image.height))
        return (0.299 * Double(pixel[0]) + 0.587 * Double(pixel[1]) + 0.114 * Double(pixel[2])) / 255
    }

    /// A Form row's switch only responds on the switch itself (the trailing edge), not on the label.
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    private func waitForBackground(dark: Bool, _ message: String, file: StaticString = #filePath, line: UInt = #line) {
        var brightness = backgroundBrightness()
        for _ in 0..<10 where dark ? brightness > 0.25 : brightness < 0.75 {
            sleep(1)
            brightness = backgroundBrightness()
        }
        if dark { XCTAssertLessThan(brightness, 0.25, message, file: file, line: line) }
        else { XCTAssertGreaterThan(brightness, 0.75, message, file: file, line: line) }
    }

    /// Settings is a lazily rendered list, so rows below the fold only exist once scrolled into view.
    private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        var attempts = 0
        while !element.exists && attempts < 8 {
            app.swipeUp()
            attempts += 1
        }
        XCTAssertTrue(element.exists, "\(element) never appeared", file: file, line: line)
    }

    private func openAddVehicleForm() {
        app.navigationBars.buttons["Add vehicle"].tap()
        XCTAssertTrue(app.textFields["Name (e.g. My Duke)"].waitForExistence(timeout: 5))
    }

    func testTappingOutsideDismissesKeyboard() {
        openAddVehicleForm()
        let name = app.textFields["Name (e.g. My Duke)"]
        name.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "keyboard should open")

        // Tap a blank spot of the form (below the fields).
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.62)).tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 5)
    }

    func testTappingAnotherFieldKeepsTheKeyboardOpen() {
        openAddVehicleForm()
        app.textFields["Name (e.g. My Duke)"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.textFields["Make (optional)"].tap()
        // The keyboard must still be there: the dismissal tap must not fire on text inputs.
        sleep(1)
        XCTAssertTrue(app.keyboards.firstMatch.exists)
        XCTAssertEqual(app.textFields["Make (optional)"].value as? String, "Make (optional)") // placeholder shown, field is focused
    }

    func testNumberPadHasDoneButton() {
        // Settings has no number-pad field, so use the quick-log sheet via a vehicle.
        openAddVehicleForm()
        app.textFields["Name (e.g. My Duke)"].tap()
        app.textFields["Name (e.g. My Duke)"].typeText("Test bike")
        app.buttons["Save"].tap()
        app.staticTexts["Test bike"].tap()
        app.buttons["Filled petrol"].tap()
        let amount = app.textFields["optional"].firstMatch
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5), "decimal pad needs a Done button")
        app.buttons["Done"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 5)
    }

    func testSettingsHasFeedbackAndShare() {
        app.tabBars.buttons["Settings"].tap()
        let feedback = app.buttons["Send feedback"]
        reveal(feedback)
        reveal(app.descendants(matching: .any)["Share this app with friends"].firstMatch)

        feedback.tap()
        XCTAssertTrue(app.navigationBars["Send feedback"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Add photo or video"].exists)
        XCTAssertTrue(app.buttons["Add file"].exists)

        // Send stays disabled until a message is typed.
        let send = app.navigationBars["Send feedback"].buttons["Send"]
        XCTAssertFalse(send.isEnabled)
        let message = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        message.tap()
        message.typeText("The tyre reminder did not fire")
        XCTAssertTrue(send.isEnabled)

        // Tapping outside closes the keyboard here too.
        app.navigationBars["Send feedback"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 5)
    }

    func testFeedbackWithoutMailAccountOffersFallback() throws {
        app.tabBars.buttons["Settings"].tap()
        let feedback = app.buttons["Send feedback"]
        reveal(feedback)
        feedback.tap()
        let message = app.textViews.firstMatch.exists ? app.textViews.firstMatch : app.textFields.firstMatch
        message.tap()
        message.typeText("Hello")
        app.navigationBars["Send feedback"].tap()
        app.navigationBars["Send feedback"].buttons["Send"].tap()
        // The simulator has no Mail account, so the fallback dialog should appear.
        XCTAssertTrue(app.staticTexts["Mail isn't set up on this device"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share with another app"].exists)
        XCTAssertTrue(app.buttons["Copy email address"].exists)
    }

    func testAppearancePickerSwitchesTheLook() {
        app.tabBars.buttons["Settings"].tap()
        let followDevice = app.switches["Device theme"]
        XCTAssertTrue(followDevice.waitForExistence(timeout: 5))
        XCTAssertEqual(followDevice.value as? String, "1", "follows the device by default")
        waitForBackground(dark: false, "the simulator is in light mode, so the app should be light")

        app.buttons["Dark"].tap()
        XCTAssertEqual(followDevice.value as? String, "0", "choosing a box turns off 'Device theme'")
        waitForBackground(dark: true, "Dark should make the app dark even though the device is light")

        app.buttons["Light"].tap()
        waitForBackground(dark: false, "Light should make the app light")

        app.buttons["Dark"].tap()
        waitForBackground(dark: true, "dark again")
        // the choice must also apply to sheets
        let feedback = app.buttons["Send feedback"]
        reveal(feedback)
        feedback.tap()
        XCTAssertTrue(app.navigationBars["Send feedback"].waitForExistence(timeout: 5))
        waitForBackground(dark: true, "sheets follow the chosen look")
        app.navigationBars["Send feedback"].buttons["Cancel"].tap()

        // back to following the device (light in the simulator)
        app.swipeDown(); app.swipeDown(); app.swipeDown()
        XCTAssertTrue(followDevice.waitForExistence(timeout: 5))
        flip(followDevice)
        XCTAssertEqual(followDevice.value as? String, "1")
        waitForBackground(dark: false, "back to following the device")
    }

    func testTurningOffDeviceThemeKeepsTheCurrentLook() {
        app.tabBars.buttons["Settings"].tap()
        let followDevice = app.switches["Device theme"]
        XCTAssertTrue(followDevice.waitForExistence(timeout: 5))
        flip(followDevice) // off: should stay light, not flip
        XCTAssertEqual(followDevice.value as? String, "0")
        waitForBackground(dark: false, "nothing should flip when the switch is turned off")
        XCTAssertTrue(app.buttons["Light"].isSelected, "the box matching the current look is selected")
    }

    // MARK: Chain lube (bikes only)

    private func addVehicle(named name: String, car: Bool = false) {
        app.navigationBars.buttons["Add vehicle"].tap()
        let field = app.textFields["Name (e.g. My Duke)"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        if car { app.segmentedControls.buttons["Car"].tap() }
        field.tap()
        field.typeText(name)
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
    }

    func testChainLubeActionIsOnlyForBikes() {
        addVehicle(named: "Duke")
        addVehicle(named: "Swift", car: true)

        app.staticTexts["Duke"].tap()
        XCTAssertTrue(app.buttons["Lubed chain"].waitForExistence(timeout: 5), "a bike gets the chain-lube action")
        XCTAssertTrue(app.buttons["Inflated tyre"].exists && app.buttons["Filled petrol"].exists)
        XCTAssertTrue(app.staticTexts["Chain last lubed: never"].exists)
        app.navigationBars.buttons.firstMatch.tap() // back

        app.staticTexts["Swift"].tap()
        XCTAssertTrue(app.buttons["Inflated tyre"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Lubed chain"].exists, "a car does not")
        XCTAssertFalse(app.staticTexts["Chain last lubed: never"].exists)
    }

    func testLoggingAChainLubeAddsAHistoryRow() {
        addVehicle(named: "Duke")
        app.staticTexts["Duke"].tap()
        app.buttons["Lubed chain"].tap()

        // the sheet: optional amount, and a reminder defaulting to 30 days
        let amount = app.textFields["optional"].firstMatch
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText("90")
        app.buttons["Done"].tap()
        let remind = app.switches["Remind me again"]
        XCTAssertEqual(remind.value as? String, "1", "reminder is on by default")
        XCTAssertTrue(app.textFields.matching(NSPredicate(format: "value == %@", "30")).firstMatch.exists, "default interval is 30 days")
        flip(remind) // off, so the system notification prompt does not appear in this test (reminders are unit-tested)
        app.buttons["Save"].tap()

        XCTAssertTrue(app.staticTexts["Chain lubed"].waitForExistence(timeout: 5), "history shows the entry")
        XCTAssertTrue(app.staticTexts["₹90"].exists, "with its amount")
        XCTAssertFalse(app.staticTexts["Chain last lubed: never"].exists, "the last-lubed line updates")
    }

    func testSettingsHasTheChainLubeInterval() {
        app.tabBars.buttons["Settings"].tap()
        let interval = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Chain lube: every 30 days")).firstMatch
        reveal(interval)
    }
}
