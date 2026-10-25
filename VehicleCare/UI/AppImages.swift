import SwiftUI
import UIKit

// Single place that decides which image every part of the app uses.
//
// Views never write a symbol name: they ask for an `AppIcon`, through
//   SwiftUI:  Image.app(.vehicles)      Label(title, icon: .settings)
//   UIKit:    UIImage.app(.vehicles)
// To change an icon app-wide, change its line below. To add one, add a case and its name.
// (LocalizationTests fails if a symbol name appears anywhere else, and checks every name below is a real SF Symbol.)
//
// All icons are SF Symbols, which follow Dynamic Type and flip for right-to-left languages where it makes sense.
// For a bundled picture instead, add it to Assets.xcassets and expose it here the same way.

enum AppIcon: CaseIterable {
    // tab bar
    case vehicles, history, settings
    // vehicle kinds
    case bike, car
    // actions
    case add, forward, removeCircle, selected
    // feedback and sharing
    case feedback, share, attachment, addPhoto, addFile
    // first-run tour
    case tourServices, tourQuickLog, tourReminders, tourTransfer, tourStart
    // appearance picker
    case lightTheme, darkTheme

    /// The SF Symbol behind each icon.
    var symbolName: String {
        switch self {
        case .vehicles: return "car"
        case .history: return "clock"
        case .settings: return "gearshape"
        case .bike: return "bicycle"
        case .car: return "car"
        case .add: return "plus"
        case .forward: return "chevron.forward"
        case .removeCircle: return "xmark.circle.fill"
        case .selected: return "checkmark.circle.fill"
        case .feedback: return "envelope"
        case .share: return "square.and.arrow.up"
        case .attachment: return "paperclip"
        case .addPhoto: return "photo.on.rectangle"
        case .addFile: return "doc"
        case .tourServices: return "wrench.and.screwdriver"
        case .tourQuickLog: return "gauge.with.dots.needle.67percent"
        case .tourReminders: return "bell"
        case .tourTransfer: return "arrow.left.arrow.right"
        case .tourStart: return "flag"
        case .lightTheme: return "sun.max"
        case .darkTheme: return "moon.fill"
        }
    }

    /// The icon for a kind of vehicle.
    static func vehicle(_ type: VehicleType) -> AppIcon { type == .bike ? .bike : .car }
}

extension Image {
    /// `Image.app(.vehicles)`
    static func app(_ icon: AppIcon) -> Image { Image(systemName: icon.symbolName) }
}

extension UIImage {
    /// `UIImage.app(.vehicles)`, for UIKit code. Optionally pass a size/weight configuration.
    static func app(_ icon: AppIcon, configuration: UIImage.Configuration? = nil) -> UIImage {
        guard let image = UIImage(systemName: icon.symbolName, withConfiguration: configuration) else {
            assertionFailure("\(icon.symbolName) is not an SF Symbol available on this iOS version")
            return UIImage()
        }
        return image
    }
}

extension Label where Title == Text, Icon == Image {
    /// `Label(L10n.Settings.feedback, icon: .feedback)`
    init(_ title: String, icon: AppIcon) {
        self.init { Text(title) } icon: { Image.app(icon) }
    }
}
