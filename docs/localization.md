# Localization and right-to-left (RTL)

The app is fully localized in **English** (`en`, the base language) and **Arabic** (`ar`, a right-to-left language that also proves RTL layout works). It follows the iPhone's language. iOS also offers a per-app language under *Settings → Vehicle Care → Language* now that the app has two languages, so there is no language picker in the app.

> **Arabic review status:** the Arabic text was written by the developer assistant, not a native speaker. Have a native speaker review it before promoting Arabic. It is covered by automated checks for structure (keys, placeholders, plural forms), not for wording.

## Where everything lives

| What | Where |
| --- | --- |
| All user-visible text | `VehicleCare/Resources/<language>.lproj/Localizable.strings` |
| Plurals ("1 day" / "3 days") | `VehicleCare/Resources/<language>.lproj/Localizable.stringsdict` |
| Typed access to all of it | `VehicleCare/Core/L10n.swift` (`L10n.Settings.title`, `L10n.Plural.days(3)`, …) |

Plain `.strings` files are used (instead of an `.xcstrings` catalog) because Foundation can read them directly in `swift test`, which lets the checks below run from the command line. `L10n` depends only on Foundation, so `Core/` stays testable.

## Rules for code

1. **No text literals** for anything the user reads. Add a key and an accessor in `L10n`. A test scans the views and fails on `Text("…")`, `Button("…")`, `.navigationTitle("…")` and similar; symbols and numbers such as `×` or `0` are allowed.
2. **Positional placeholders** (`%1$@`, `%2$d`) in any string with more than one, so translators can reorder them. A test enforces this and checks that every language has the same placeholders as English.
3. **Counts that change the wording** go through `L10n.Plural` (stringsdict), never "item(s)". English needs *one* and *other*; **Arabic needs all six** categories (*zero, one, two, few, many, other*). Tests check both.
4. **Join sentences with a format string**, not with `+`, because word order differs between languages.
5. User-supplied text (vehicle names, titles) inserted with `%@` is isolated from the surrounding sentence automatically by Foundation in RTL languages. If you must join strings by hand, wrap the user text in `L10n.isolate(_:)`; wrap an amount in `L10n.ltr(_:)` (`Costs.format` already does).

## What is deliberately not localized

- Database values and enum raw values (`bike`, `tyre_air`), JSON backup keys and the backup format (it must stay readable by older versions and by the Expo app).
- CSV column headers (for spreadsheets).
- The **feedback email** subject and device-info lines: they are read by the developer, so they stay English (the user's own message is whatever they type).
- The brand name "Vehicle Care" (also the home-screen name).
- Technical field names quoted in backup error messages (for example `labour_cost`), since they refer to the file's contents.

## Numbers, dates and digits

- Arabic shows **Western digits (0-9)** everywhere: `L10n.locale` forces the Latin numbering system for every language.
- Dates, month titles and the reminder-hour picker use the locale's own order and names (`DateUtil.pretty`, `monthTitle`, `L10n.hourLabel`), so English shows "Oct 24, 2026" or "24 Oct 2026" depending on the region. The stored `yyyy-MM-dd` format never changes.
- **Typed numbers** are normalized before parsing (`Costs.normalizeDigits`): Arabic-Indic (٠-٩) and Persian (۰-۹) digits, `٫` as the decimal separator and `٬` as the thousands separator all work, so an Arabic keyboard cannot silently turn "١٢" into 0.
- Text fields are pre-filled with `Costs.editableText`, always plain digits with a `.` decimal.

## Right-to-left layout checklist

SwiftUI mirrors layout automatically when the language is RTL (stack order, `leading`/`trailing`, navigation, tab order, paging). To keep it that way:

- Use `.leading` / `.trailing`, never `.left` / `.right`.
- Use directional symbols that flip: `chevron.forward` (not `chevron.right`).
- Do not hard-code horizontal offsets or fixed left/right padding.
- Check new SF Symbols that imply direction.
- Put the screen in Arabic and look at it (see below).

## Testing

- **Logic and string files:** `swift test` runs `LocalizationTests`: same keys in every language, no empty values, matching placeholders, every key used by `L10n` and every accessor used by the app, complete plural categories, Arabic plural output (0, 1, 2, 5, 11, 100), Western digits in Arabic output, typed Arabic digits, no hard-coded text in views, developer-facing email still English.
- **In the app:** `ArabicRTLUITests` launches in Arabic and checks the layout is mirrored (the tour's Skip button moves to the left; the first tab is on the right), that translated plurals appear (14 → "14 يومًا", 7 → "7 أيام"), that keyboard dismissal works, and that the feedback fallback is Arabic. Run all UI tests with Product → Test, or `xcodebuild test`.
- **Look at it:** choose the **VehicleCare-Arabic** scheme in Xcode (Run starts the app in Arabic), or run the screen tour, which saves a screenshot of every screen in English, Arabic and double-length English:

  ```bash
  TEST_RUNNER_SCREENSHOT_DIR=/tmp/shots xcodebuild test -project VehicleCare.xcodeproj -scheme VehicleCare \
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO \
    -only-testing:VehicleCareUITests/ScreenTourUITests
  ```

  The double-length run (`-NSDoubleLocalizedStrings YES`) is for spotting truncation. It also doubles format placeholders, so strings with counts look garbled (`@`, `#@count@`); that is the pseudo-locale, not a bug.

## Adding a string

1. Add the key to `en.lproj/Localizable.strings` and the translation to every other language folder (same key).
2. Add a typed accessor to `L10n.swift` (the key is `<namespace>.<name>`).
3. Use it. Run `swift test`; it tells you if anything is missing, unused or inconsistent.
4. Counts: add a `plural.<name>` entry to every `.stringsdict` and an accessor in `L10n.Plural` instead.

## Adding a language

1. Copy `en.lproj` to `<code>.lproj` and translate both files. Include every plural category the language needs (see the CLDR plural rules).
2. Add the language to `Files.languages` and the `needed` plural map in `Tests/CoreTests/LocalizationTests.swift`.
3. If it is right-to-left, add UI tests like `ArabicRTLUITests`. If its digits differ, check parsing in `Costs.normalizeDigits`.
4. Xcode registers the region in the project automatically on the next build.
5. Have it reviewed by a native speaker, and record that here.

## Known limitations

- **Reminder text language:** the notification body is composed when the reminder is scheduled and stored in the `reminder.label` column (the schema is shared with the Expo app). After the user changes the phone's language, reminders already scheduled keep the old language until they are set again.
- The system mail composer, photo picker, file picker and share sheet are iOS screens and follow the phone's language and direction by themselves; they were not checked under RTL on a real device.
- The Expo app is not localized yet.
