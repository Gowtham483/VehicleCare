import Foundation

/// App-wide constants you are expected to edit before release.
enum AppInfo {
    static let name = "Vehicle Care"

    /// TODO: replace with your own address. Feedback emails are sent here.
    static let feedbackEmail = "feedback@example.com"

    /// TODO: replace with your App Store link once the app is published.
    static let appStoreURL = "https://apps.apple.com/app/id0000000000"

    static var shareMessage: String { L10n.Share.message(name) }
}
