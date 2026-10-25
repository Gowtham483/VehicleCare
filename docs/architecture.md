# Architecture

Local-first SwiftUI app. No third-party code: SwiftUI, system SQLite3, UserNotifications, UIKit's share sheet.

```
SwiftUI views (UI/)               presentation only
        │
AppModel (Services/)              @Observable; owns store + services; bumps `revision` after writes
        │
ReminderService, Backup, Costs,   platform-independent logic (Core/)
Schedule, Retention
        │
DataStore (Core/)                 all SQL, one method per query
        │
Database (Core/)                  thin wrapper over the SQLite3 C API; migrations via PRAGMA user_version
```

## Decisions

- **SQLite via the system library** (not SwiftData or Core Data) keeps the schema, queries and backup merge rules identical to the Expo app, and makes the logic testable from the command line with an in-memory database.
- **`Core/` has no UI or UserNotifications imports.** The notification centre sits behind the `NotificationScheduler` protocol; the app supplies `SystemNotificationScheduler`, tests supply a fake.
- **Views refresh through `AppModel.revision`.** Views read it in `body`, so any write that calls `bump()` re-renders them. Data volumes are small, so queries run in `body`.
- **Theme** is a dynamic `UIColor` per token, so SwiftUI follows light/dark automatically.

## Images and appearance

All icons are defined once in `UI/AppImages.swift` and used through `Image.app(_:)`, `UIImage.app(_:)` and `Label(_:icon:)`; see [images.md](images.md). The light/dark choice (`AppSettings.appearance`) is applied at the app root with `preferredColorScheme`; see [theming.md](theming.md).

## Localization

All text goes through `Core/L10n.swift`, which reads `Resources/<language>.lproj/Localizable.strings` and `.stringsdict`. `L10n.locale` is the app's language with Western digits forced; dates, amounts and file sizes are formatted with it. Typed numbers are normalized before parsing so Arabic keyboards work. Layout is mirrored by SwiftUI for right-to-left languages. See [localization.md](localization.md).

## Keyboard handling

`UI/KeyboardDismissal.swift` installs one tap recogniser on the key window. It closes the keyboard on any tap that is not on a text input, and does not cancel the tap, so buttons still work. A per-screen SwiftUI tap gesture was rejected because it also fires when a text field is tapped and would close the keyboard as it opens. `themedForm()` (used by every form) also enables scroll-to-dismiss and adds a **Done** button above the keyboard, because number pads have no return key. The recogniser re-attaches when the key window changes.

## Support: feedback and sharing

See [support.md](support.md). Feedback logic that does not need UIKit (subject, body, attachment limits, MIME types, file-name sanitising) lives in `Core/Feedback.swift` and is unit-tested; the screen, photo picker and mail composer are in `UI/FeedbackView.swift`.

## Testing

- `swift test`: logic in `Core/` (database, costs, schedule, backup, reminders, feedback) and the localization checks (string files, placeholders, plurals, no hard-coded text, Arabic behaviour) against an in-memory database and a fake notification centre.
- `VehicleCareUITests`: UI tests run on a simulator (keyboard dismissal, Done button, feedback screen and its no-Mail fallback, Arabic right-to-left layout, and an optional screenshot tour). The app starts with an in-memory database when launched with `-uitest-reset`, so tests never touch real data.

## Startup

1. `AppModel.live()` opens `Application Support/vehicle-care.db` and runs migrations.
2. `boot()` purges records older than the retention window and runs `ReminderService.sync()`.
3. If `onboardingDone` is false the tour shows; otherwise the tab view.

## Data model

Same tables as the Expo app (`vehicle`, `service`, `service_part`, `quick_log`, `reminder`, `settings`); see its `docs/data-model.md`. Dates are local `YYYY-MM-DD` strings; reminder times are ISO-8601. Deleting a vehicle or service cascades.

## Notifications

`ReminderService` replaces the reminder of the same kind per vehicle (or service), stores the notification id, and `sync()` reconciles after launches and imports. Permission is requested the first time a reminder is set. If denied, the row is kept and scheduled later by `sync()`.

## Schema or backup changes

The database is at **schema version 2** (`Migrations.databaseVersion`). Version 2 rebuilt `quick_log` and `reminder` without the `CHECK` on `kind`, because SQLite cannot alter a `CHECK`; kinds are validated by the Swift enums (`QuickKind`, `ReminderKind`), so a new quick action needs no further table rebuild. `Migrations.migrate(_:upTo:)` lets tests build an older database and upgrade it.

Add a migration step and bump `Migrations.databaseVersion`. For the backup file, bump `BackupFile.currentSchemaVersion`, add a step to `Backup.migrate`, add a test, and keep the Expo app's format in step.
