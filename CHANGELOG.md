# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## Versioning

The app is in **beta**. Releases are numbered `1.0.0-beta.1`, `1.0.0-beta.2`, `1.0.0-beta.3`, … (a [Semantic Versioning](https://semver.org/spec/v2.0.0.html) pre-release). The `1.0.0` part does not change during the beta, whatever the size of the change; only the beta number goes up. Once the first stable release ships as `1.0.0`, normal Semantic Versioning starts: MAJOR for breaking changes such as an incompatible backup format, MINOR for features, PATCH for bug fixes.

The Xcode project's marketing version is the full string (for example `1.0.0-beta.3`) and the build number matches the beta number. The Settings screen and the feedback email show it.

Entries below were numbered 1.0.0, 1.1.0 and 1.2.0 before the beta scheme was adopted; they were renumbered 1.0.0-beta.1, -beta.2 and -beta.3 with their content unchanged.

## [Unreleased]

### Changed
- Documentation only: `docs/roadmap.md` now plans **Siri, Shortcuts and quick-action widgets** (epic E6 in 1.1.0, with Siri-language and unit follow-ups in 1.2.0), including the shared-database groundwork they need. Nothing is built yet.

## [1.0.0-beta.5] - 2026-10-24

### Added
- **Chain lube quick action for bikes.** A **Lubed chain** button next to *Inflated tyre* and *Filled petrol* (bikes only; cars do not get it). The sheet records the date, an optional amount and a note, and sets a reminder, by default **30 days** later. The vehicle screen shows "Chain last lubed", and history shows "Chain lubed". Strings are in English and Arabic.
- **Chain lube reminder interval** in Settings → Reminders (1-365 days, default 30), included in backups like the other intervals.
- `docs/roadmap.md`: what comes after the betas. The India-first release is planned as 1.1.0 and Global as 1.2.0, with the cases collected from competitor research. Nothing in it is built yet.
- Tests for the new action, the database upgrade, and backup versions.

### Changed
- **Database schema version 2.** The `quick_log` and `reminder` tables are rebuilt without the fixed list of allowed `kind` values, so existing data is kept and future quick actions need no further rebuild. The upgrade runs automatically on first launch.
- **Backup file version.** A backup is written as version 1 unless it contains a chain-lube entry, in which case it is version 2. Files without chain-lube data stay importable by the Expo app and older builds; a version 2 file is refused by an older app with the usual "newer version" message. This app imports both.
- The Settings backup note no longer mentions the Expo app.

## [1.0.0-beta.4] - 2026-10-24

### Added
- **Appearance setting** in Settings: a **Device theme** switch that follows the iPhone's light/dark setting, plus two preview boxes (white = Light, dark = Dark) to choose a look yourself. Turning the switch off keeps the look you are seeing; tapping a box picks it. The choice applies everywhere, including sheets, and is saved on the device (it is not part of backups, so importing a backup never changes the look). Strings are in English and Arabic.
- Central image control: every icon is defined once in `VehicleCare/UI/AppImages.swift` (`AppIcon`) and used through `Image.app(_:)`, `UIImage.app(_:)` and `Label(_:icon:)`.
- Checks that fail if a symbol name is written outside `AppImages.swift`, if an icon name is not a real SF Symbol or needs a newer iOS than 17, or if an icon is unused.
- UI tests that prove the look really changes (sampling the screen, including inside a sheet), and that turning the switch off does not flip the look.

### Changed
- Icons are no longer written as symbol-name strings in the views; the first-run tour slides refer to `AppIcon`.

## [1.0.0-beta.3] - 2026-10-24

### Added
- **Localization.** Every user-visible string now lives in `Resources/<language>.lproj/Localizable.strings` (and `.stringsdict` for plurals), accessed through the typed `L10n` layer. English is the base language.
- **Arabic**, with full **right-to-left** support: mirrored layout, tabs, navigation, paging and symbols, correct Arabic plural forms (zero, one, two, few, many, other), Western digits (0-9) in numbers and dates, and bidi-safe amounts and names. The Arabic text still needs review by a native speaker.
- Typed numbers are understood on any keyboard: Arabic-Indic and Persian digits and Arabic decimal and thousands separators.
- `VehicleCare-Arabic` scheme (Run opens the app in Arabic), Arabic UI tests, a screen-tour test that saves screenshots in English, Arabic and double-length English, and automated checks that fail on missing, unused or inconsistent strings and on hard-coded text.
- `docs/localization.md`.

### Changed
- Dates, month titles, the reminder-hour picker, amounts and file sizes follow the app's language and region. For example English may show "Oct 24, 2026" instead of "24 Oct 2026". Stored data and backup files are unchanged.
- Notification text, validation messages and notices are localized.
- UI tests now pass explicit language launch arguments.

### Fixed
- The attachment limit was shown as "21 MB" although it is 20 MB; it is now exactly 20 MB (20,000,000 bytes).

## [1.0.0-beta.2] - 2026-10-24

### Added
- **Send feedback** in Settings: choose a category, write a message and attach photos, videos or files (up to 5 files, 20 MB in total). Opens the system mail composer addressed to `AppInfo.feedbackEmail`; if Mail isn't set up, the user can share the feedback and attachments with another app or copy the address. Optional app version, iOS version and device model are included only when the user leaves the toggle on.
- **Share this app with friends** in Settings, using the system share sheet.
- A **Done** button above the keyboard, so number pads (which have no return key) can be closed.
- UI tests (`VehicleCareUITests`) covering keyboard behaviour and the new Support screens.

### Fixed
- The keyboard now closes when tapping outside a text field, and when scrolling a form.

### Changed
- Before release, set `AppInfo.feedbackEmail` and `AppInfo.appStoreURL` in `VehicleCare/Core/AppInfo.swift` (they are placeholders).

## [1.0.0-beta.1] - 2026-10-24

First beta of the native iOS app, with feature parity with the Expo version.

### Added
- Multiple vehicles; service log with notes, labour charge, parts table and automatic total.
- Next-service reminders; quick logs for tyre air and petrol with configurable reminders.
- History with monthly and yearly totals and a vehicle filter.
- Settings: reminder intervals, service lead time, notification hour, currency.
- JSON backup export/import (merge or replace, validated and all-or-nothing), compatible with the Expo app; read-only CSV export.
- Light and dark mode from a single theme file.
- Skippable first-launch tour, replayable from Settings.
- Automatic removal of records older than 24 months; reset all data.
- Unit tests for the core logic (`swift test`).
