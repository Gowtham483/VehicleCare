import SwiftUI
import UIKit

// Single source of truth for every colour in the app.
// Views read colours through `@Environment(\.theme)`; there are no colour literals outside this file.
// Every colour is a dynamic UIColor, so it follows light/dark mode (the trait collection) automatically.

struct ColorPair {
    let light: String
    let dark: String
}

/// Tokens a palette is allowed to change (bars + accent).
struct BrandPalette {
    let topBar: ColorPair
    let topBarText: ColorPair
    let bottomBar: ColorPair
    let bottomBarActive: ColorPair
    let bottomBarInactive: ColorPair
    let accent: ColorPair
    let onAccent: ColorPair
}

enum Themes {
    static let defaultId = "default"

    /// Add new palettes here; a palette only overrides brand tokens.
    static let all: [String: BrandPalette] = [
        "default": BrandPalette(
            topBar: ColorPair(light: "#1F4E8C", dark: "#14233B"),
            topBarText: ColorPair(light: "#FFFFFF", dark: "#F2F3F5"),
            bottomBar: ColorPair(light: "#FFFFFF", dark: "#14161A"),
            bottomBarActive: ColorPair(light: "#1F4E8C", dark: "#7FB0F2"),
            bottomBarInactive: ColorPair(light: "#7B8290", dark: "#8A909C"),
            accent: ColorPair(light: "#1F4E8C", dark: "#7FB0F2"),
            onAccent: ColorPair(light: "#FFFFFF", dark: "#0E0F12")
        ),
    ]
}

/// Tokens shared by every theme.
private enum Fixed {
    static let background = ColorPair(light: "#F5F6F8", dark: "#0E0F12")
    static let surface = ColorPair(light: "#FFFFFF", dark: "#1A1C21")
    static let surfaceAlt = ColorPair(light: "#ECEEF2", dark: "#262930")
    static let textPrimary = ColorPair(light: "#14161A", dark: "#F2F3F5")
    static let textSecondary = ColorPair(light: "#5E6572", dark: "#A4AAB5")
    static let border = ColorPair(light: "#D9DCE3", dark: "#32353D")
    static let success = ColorPair(light: "#1E8E4E", dark: "#4CC585")
    static let warning = ColorPair(light: "#B26A00", dark: "#F0B04B")
    static let danger = ColorPair(light: "#C62828", dark: "#EF6B6B")
}

extension UIColor {
    convenience init(hex: String) {
        let value = UInt32(hex.replacingOccurrences(of: "#", with: ""), radix: 16) ?? 0
        self.init(red: CGFloat((value >> 16) & 0xFF) / 255, green: CGFloat((value >> 8) & 0xFF) / 255,
                  blue: CGFloat(value & 0xFF) / 255, alpha: 1)
    }

    static func dynamic(_ pair: ColorPair) -> UIColor {
        UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: pair.dark) : UIColor(hex: pair.light) }
    }

    var luminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: nil)
        return 0.299 * r + 0.587 * g + 0.114 * b
    }
}

struct Theme {
    // brand
    let topBar: Color
    let topBarText: Color
    let bottomBar: Color
    let bottomBarActive: Color
    let bottomBarInactive: Color
    let accent: Color
    let onAccent: Color
    // fixed
    let background = Color(uiColor: .dynamic(Fixed.background))
    let surface = Color(uiColor: .dynamic(Fixed.surface))
    let surfaceAlt = Color(uiColor: .dynamic(Fixed.surfaceAlt))
    let textPrimary = Color(uiColor: .dynamic(Fixed.textPrimary))
    let textSecondary = Color(uiColor: .dynamic(Fixed.textSecondary))
    let border = Color(uiColor: .dynamic(Fixed.border))
    let success = Color(uiColor: .dynamic(Fixed.success))
    let warning = Color(uiColor: .dynamic(Fixed.warning))
    let danger = Color(uiColor: .dynamic(Fixed.danger))

    // UIKit-only needs (tab bar inactive tint, deciding bar content colour)
    let topBarUIColor: UIColor
    let bottomBarInactiveUIColor: UIColor

    static func resolve(_ id: String) -> Theme {
        let p = Themes.all[id] ?? Themes.all[Themes.defaultId]!
        func c(_ pair: ColorPair) -> Color { Color(uiColor: .dynamic(pair)) }
        return Theme(topBar: c(p.topBar), topBarText: c(p.topBarText), bottomBar: c(p.bottomBar),
                     bottomBarActive: c(p.bottomBarActive), bottomBarInactive: c(p.bottomBarInactive),
                     accent: c(p.accent), onAccent: c(p.onAccent),
                     topBarUIColor: .dynamic(p.topBar), bottomBarInactiveUIColor: .dynamic(p.bottomBarInactive))
    }

    /// `.dark` makes the status bar and bar buttons light, for dark bar colours.
    func barContentScheme(_ scheme: ColorScheme) -> ColorScheme {
        let style: UIUserInterfaceStyle = scheme == .dark ? .dark : .light
        let resolved = topBarUIColor.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        return resolved.luminance < 0.6 ? .dark : .light
    }
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.resolve(Themes.defaultId)
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// Applies the top-bar colours to a navigation stack's content.
private struct ThemedBars: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .toolbarBackground(theme.topBar, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(theme.barContentScheme(scheme), for: .navigationBar)
    }
}

extension View {
    func themedBars() -> some View { modifier(ThemedBars()) }
}

/// Fixed colours for the two preview boxes in the appearance picker. They show what Light and Dark look like,
/// so they must not change with the current theme or with the mode the app is in.
enum AppearanceSwatch {
    static let lightFill = Color(uiColor: UIColor(hex: "#FFFFFF"))
    static let lightText = Color(uiColor: UIColor(hex: "#14161A"))
    static let darkFill = Color(uiColor: UIColor(hex: "#1A1C21"))
    static let darkText = Color(uiColor: UIColor(hex: "#F2F3F5"))
}

extension AppearanceChoice {
    /// What to hand to `preferredColorScheme`: `nil` means follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
