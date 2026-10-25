# Vehicle Care (native iOS)

> **Status: beta** (`1.0.0-beta.N`). See the [changelog](CHANGELOG.md) for what changed in each beta.

A personal app to track everything your **bike** and **car** need: service history, parts replaced, costs, and reminders for tyre air and petrol. Data stays **on your iPhone**; there is no account and no server.

This is the native SwiftUI version of the Expo app. It has the same features, the same database schema and the same backup file format, so a backup exported from either app imports into the other.

**No external dependencies.** Only Apple frameworks: SwiftUI, the system SQLite3 library, UserNotifications, and `UIActivityViewController` for sharing. No Swift packages, no CocoaPods.

## Features

- Multiple vehicles (bike or car)
- Service log: date, title, notes, labour charge, a parts table (name, price, quantity) and a live total
- Next-service reminder (pick a date or "in 3 / 6 / 12 months")
- Quick logs: "Inflated tyre", "Filled petrol" and, for bikes, "Lubed chain", each with a configurable "remind me again after N days"
- History with monthly and yearly totals, filterable by vehicle
- Settings for reminder intervals, lead time, notification hour and currency
- Backup to a single JSON file and import (merge or replace); read-only CSV export
- Light and dark mode driven by one theme file, with a **Device theme** switch and two boxes (Light / Dark) to choose the look yourself
- All icons defined in one file (`AppImages.swift`)
- English and Arabic (right-to-left), following the iPhone's language; all strings live in separate files
- Skippable first-launch tour, replayable from Settings
- Records older than 24 months are removed automatically
- Reset all data
- Send feedback by email with photo, video or file attachments; share the app with friends
- Tap outside a field (or scroll, or press Done) to close the keyboard

## Requirements

- Xcode 16 or later (built with Xcode 26)
- iOS 17.0 or later

## Run it

1. Open `VehicleCare.xcodeproj` in Xcode.
2. Pick an iPhone simulator running iOS 17+ (or your iPhone), then press **Run (▶)**.
3. For a real device: select your Team under **Signing & Capabilities** and change the bundle ID `com.example.vehiclecare.native` to your own.

Use **Settings → Send test notification** to check reminders on your device.

## Roadmap

What is planned after the betas (1.0.0, then the India-first 1.1.0 and the Global 1.2.0) is in [docs/roadmap.md](docs/roadmap.md).

## Languages

English (base) and Arabic (right-to-left). The app follows the iPhone's language; iOS also lets users pick a language for this app in Settings → Vehicle Care → Language. To try Arabic, choose the **VehicleCare-Arabic** scheme in Xcode. Arabic text should be reviewed by a native speaker before release. Details: [docs/localization.md](docs/localization.md).

## Before you publish

Edit the two placeholders in [`VehicleCare/Core/AppInfo.swift`](VehicleCare/Core/AppInfo.swift):

- `feedbackEmail`: where feedback emails are sent
- `appStoreURL`: the link shared by "Share this app with friends"

## Tests

The logic in `VehicleCare/Core` is plain Swift and is tested from the command line:

```bash
swift test
```

UI tests (keyboard behaviour, feedback screen) run through Xcode (Product → Test) or:

```bash
xcodebuild test -project VehicleCare.xcodeproj -scheme VehicleCare \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' CODE_SIGNING_ALLOWED=NO
```

`Package.swift` exists only for the logic tests; the app is built by the Xcode project and has no package dependencies.

## Project structure

```
VehicleCare/Core/       Platform-independent logic: SQLite wrapper and migrations, DataStore (all SQL),
                        costs, scheduling, backup/import/CSV, ReminderService
VehicleCare/Services/   AppModel (observable state), notification centre adapter, backup file helpers
VehicleCare/Resources/  Localizable.strings and .stringsdict per language (en, ar)
VehicleCare/UI/         SwiftUI screens, shared components, Theme.swift (all colours), AppImages.swift (all icons), keyboard handling
VehicleCareUITests/     UI tests (keyboard, feedback screen)
Tests/CoreTests/        Unit tests for Core
docs/                   Design notes
```

See [docs/architecture.md](docs/architecture.md), [docs/support.md](docs/support.md) (feedback and sharing), [docs/localization.md](docs/localization.md) (languages, RTL, adding strings), [docs/images.md](docs/images.md) (central icon control) and [docs/theming.md](docs/theming.md) (colours and appearance).

## Moving between phones (or from the Expo app)

**Settings → Export data** on the old device, send the file to yourself, then **Settings → Import data** on the new one. Choose **Merge** (skips duplicates) or **Replace all**. Reminders are re-created automatically. Format details: [docs/backup-format.md](docs/backup-format.md).

## Theming

Every colour lives in [`VehicleCare/UI/Theme.swift`](VehicleCare/UI/Theme.swift) as a dynamic colour for light and dark. A palette can change only the brand colours (top bar, bottom bar, accent). See [docs/theming.md](docs/theming.md).

## Roadmap

Cloud backup (iCloud), theme picker, odometer-based reminders, automatic backups.

See the [changelog](CHANGELOG.md) for release history.
