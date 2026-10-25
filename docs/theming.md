# Theming

All colours are defined in `VehicleCare/UI/Theme.swift`; views read them from `@Environment(\.theme)`. No colour literals elsewhere.

- **Brand tokens** (a palette may change them): `topBar`, `topBarText`, `bottomBar`, `bottomBarActive`, `bottomBarInactive`, `accent`, `onAccent`.
- **Fixed tokens** (same in every theme): `background`, `surface`, `surfaceAlt`, `textPrimary`, `textSecondary`, `border`, `success`, `warning`, `danger`.
- Each token is a `ColorPair(light:dark:)` turned into a dynamic `UIColor`, so the UI follows the system appearance live.
- `themedBars()` applies the top bar colour and picks light or dark bar content from the colour's luminance. `MainTabView` applies the bottom bar colours.

## Adding a palette

Add an entry to `Themes.all` with all seven brand `ColorPair`s. A theme picker later only needs to write `themeId` via `AppModel.update`; `VehicleCareApp` already resolves the theme from `settings.themeId`.

## Appearance: light, dark or follow the device

Separate from the colour *palette* above, the user chooses the **look** in Settings → Appearance:

- **Device theme** switch **on**: the app follows the iPhone's light/dark setting (the two preview boxes are dimmed).
- **Switch off**: the app is always Light or always Dark, picked by tapping the white (Light) or dark (Dark) box. Turning the switch off keeps the look currently shown, so nothing flips. Tapping a box while the switch is on also turns it off and picks that look.

How it works:

- The choice is `AppSettings.appearance` (`system`, `light`, `dark`), saved in the `settings` table under `appearance`. It is a per-device display preference, so it is **not** in backups and importing a backup never changes it.
- `VehicleCareApp` passes it to `.preferredColorScheme(...)` (`nil` means follow the device) on the root view, which also applies to sheets. Every colour is a dynamic light/dark pair (see Tokens), so the whole UI follows.
- The picker is `UI/AppearancePicker.swift`. The two preview boxes use fixed colours (`AppearanceSwatch` in `Theme.swift`) because they show what each look is and must not change with the current mode.

Tests: unit tests cover defaults, parsing, storage and exclusion from backups; UI tests change the look and sample the screen background (including inside a sheet) to prove it changes.
