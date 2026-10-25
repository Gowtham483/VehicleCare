import SwiftUI

/// "Device theme" switch plus two preview boxes (white = Light, dark = Dark).
/// - Switch on: the app follows the iPhone's light/dark setting; the boxes are dimmed.
/// - Tapping a box (or turning the switch off) picks that look explicitly.
struct AppearancePicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var currentScheme

    private var appearance: AppearanceChoice { model.settings.appearance }
    private var followsDevice: Bool { appearance == .system }

    var body: some View {
        Toggle(L10n.Settings.deviceTheme, isOn: Binding(
            get: { followsDevice },
            // turning it off keeps the look the user is seeing right now, so nothing flips unexpectedly
            set: { on in model.update { $0.appearance = on ? .system : (currentScheme == .dark ? .dark : .light) } }))
        HStack(spacing: 12) {
            box(.light)
            box(.dark)
        }
        .padding(.vertical, 4)
    }

    private func box(_ choice: AppearanceChoice) -> some View {
        let isLight = choice == .light
        let selected = appearance == choice
        let title = isLight ? L10n.Settings.lightTheme : L10n.Settings.darkTheme
        let fill = isLight ? AppearanceSwatch.lightFill : AppearanceSwatch.darkFill
        let ink = isLight ? AppearanceSwatch.lightText : AppearanceSwatch.darkText

        return VStack(spacing: 8) {
            Image.app(isLight ? .lightTheme : .darkTheme).font(.title2)
            Text(title).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, minHeight: 84)
        .background(fill, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? theme.accent : theme.border, lineWidth: selected ? 3 : 1))
        .overlay(alignment: .topTrailing) {
            if selected { Image.app(.selected).foregroundStyle(theme.accent).background(Circle().fill(fill)).padding(6) }
        }
        .opacity(followsDevice ? 0.55 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 12))
        // a tap gesture, not a Button: two buttons in one Form row would both fire on any tap
        .onTapGesture { model.update { $0.appearance = choice } }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
