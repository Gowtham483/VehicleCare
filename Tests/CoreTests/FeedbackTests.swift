import XCTest
@testable import Core

final class FeedbackTests: CoreTestCase {
    private let info = DeviceInfo(appVersion: "1.0.0-beta.5", build: "1", osVersion: "18.6", deviceModel: "iPhone17,1")

    func testSubjectNamesTheCategory() {
        XCTAssertEqual(Feedback.subject(.bug), "[Vehicle Care] Bug report")
        XCTAssertEqual(Feedback.subject(.idea), "[Vehicle Care] Suggestion")
        XCTAssertEqual(Feedback.subject(.other), "[Vehicle Care] Feedback")
    }

    func testBodyTrimsMessageAndAppendsDeviceInfoOnlyWhenAsked() {
        let plain = Feedback.body(message: "  It crashes\n ", includeDeviceInfo: false, info: info)
        XCTAssertEqual(plain, "It crashes")

        let withInfo = Feedback.body(message: "It crashes", includeDeviceInfo: true, info: info)
        XCTAssertTrue(withInfo.hasPrefix("It crashes"))
        XCTAssertTrue(withInfo.contains("App: Vehicle Care 1.0.0-beta.5 (1)"))
        XCTAssertTrue(withInfo.contains("iOS: 18.6"))
        XCTAssertTrue(withInfo.contains("Device: iPhone17,1"))
    }

    func testAttachmentLimits() {
        XCTAssertEqual(Feedback.check(existingSizes: [], newSize: 1_000), .ok)
        XCTAssertEqual(Feedback.check(existingSizes: Array(repeating: 1, count: 5), newSize: 1), .tooMany)
        XCTAssertEqual(Feedback.check(existingSizes: [15_000_000], newSize: 6_000_000), .tooLarge)
        XCTAssertEqual(Feedback.check(existingSizes: [15_000_000], newSize: 5_000_000), .ok)
        XCTAssertEqual(Feedback.formattedSize(Feedback.maxTotalBytes).filter(\.isNumber), "20", "the limit shown to the user is 20 MB")
    }

    func testMimeTypes() {
        XCTAssertEqual(Feedback.mimeType(forFileName: "shot.png"), "image/png")
        XCTAssertEqual(Feedback.mimeType(forFileName: "clip.mov"), "video/quicktime")
        XCTAssertEqual(Feedback.mimeType(forFileName: "notes.pdf"), "application/pdf")
        XCTAssertEqual(Feedback.mimeType(forFileName: "mystery.zzzunknown"), "application/octet-stream")
        XCTAssertEqual(Feedback.mimeType(forFileName: "noextension"), "application/octet-stream")
    }

    func testFileNameSanitising() {
        XCTAssertEqual(Feedback.sanitizedFileName("my photo-1.jpg"), "my photo-1.jpg")
        XCTAssertEqual(Feedback.sanitizedFileName("../../etc/passwd"), ".._.._etc_passwd")
        XCTAssertEqual(Feedback.sanitizedFileName("a/b\\c.png"), "a_b_c.png")
        XCTAssertEqual(Feedback.sanitizedFileName("   "), "attachment")
        XCTAssertEqual(Feedback.sanitizedFileName(".."), "attachment")
    }

    func testPlaceholdersAreWellFormed() {
        XCTAssertNotNil(URL(string: AppInfo.appStoreURL))
        XCTAssertTrue(AppInfo.feedbackEmail.contains("@"))
    }
}
