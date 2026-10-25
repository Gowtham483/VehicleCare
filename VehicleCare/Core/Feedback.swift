import Foundation
import UniformTypeIdentifiers

enum FeedbackCategory: String, CaseIterable, Identifiable {
    case bug, idea, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .bug: return L10n.Feedback.categoryBug
        case .idea: return L10n.Feedback.categoryIdea
        case .other: return L10n.Feedback.categoryOther
        }
    }

    /// Not localized on purpose: the email is read by the developer.
    fileprivate var subjectLabel: String {
        switch self {
        case .bug: return "Bug report"
        case .idea: return "Suggestion"
        case .other: return "Feedback"
        }
    }
}

/// Non-personal facts that help reproduce a problem.
struct DeviceInfo: Equatable {
    var appVersion: String
    var build: String
    var osVersion: String
    var deviceModel: String
}

enum AttachmentCheck: Equatable {
    case ok
    case tooMany
    case tooLarge
}

enum Feedback {
    static let maxAttachments = 5
    /// 20 MB in the decimal units the size formatter shows, so the limit reads "20 MB" (not "21 MB").
    /// Most mail providers reject more than ~20-25 MB.
    static let maxTotalBytes = 20_000_000

    static func subject(_ category: FeedbackCategory) -> String { "[\(AppInfo.name)] \(category.subjectLabel)" }

    /// Not localized on purpose: the email, including its device-info lines, is read by the developer.
    static func body(message: String, includeDeviceInfo: Bool, info: DeviceInfo?) -> String {
        var text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        if includeDeviceInfo, let info {
            text += """


            ---
            App: \(AppInfo.name) \(info.appVersion) (\(info.build))
            iOS: \(info.osVersion)
            Device: \(info.deviceModel)
            """
        }
        return text
    }

    /// Whether another file of `newSize` bytes can be added to files already attached.
    static func check(existingSizes: [Int], newSize: Int) -> AttachmentCheck {
        if existingSizes.count >= maxAttachments { return .tooMany }
        if existingSizes.reduce(0, +) + newSize > maxTotalBytes { return .tooLarge }
        return .ok
    }

    static func mimeType(forFileName name: String) -> String {
        let ext = (name as NSString).pathExtension
        return UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
    }

    /// Keeps letters, digits and `. - _ space`; anything else (including path separators) becomes `_`.
    static func sanitizedFileName(_ name: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: ".-_ "))
        let cleaned = String(name.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" })
            .trimmingCharacters(in: .whitespaces)
        return cleaned.isEmpty || cleaned == "." || cleaned == ".." ? "attachment" : cleaned
    }

    static func formattedSize(_ bytes: Int) -> String {
        Int64(bytes).formatted(.byteCount(style: .file).locale(L10n.locale))
    }
}
