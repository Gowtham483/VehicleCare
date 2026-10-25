import XCTest
@testable import Core

/// Points `L10n` at one language's `.lproj` folder straight from the source tree, so logic tests
/// run without building the app.
enum TestLocalization {
    static let resources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("VehicleCare/Resources")

    static func folder(_ language: String) -> URL { resources.appendingPathComponent("\(language).lproj") }

    static func use(_ language: String) {
        L10n.bundle = Bundle(path: folder(language).path)!
        L10n.localeOverride = Locale(identifier: language)
    }
}

/// Base class: every logic test runs in English unless it switches language itself.
class CoreTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        TestLocalization.use("en")
    }

    override func tearDown() {
        TestLocalization.use("en")
        super.tearDown()
    }
}
