# Images and icons

Every image the app shows is defined in **one file**: [`VehicleCare/UI/AppImages.swift`](../VehicleCare/UI/AppImages.swift). To change an icon app-wide, change its line there.

## Using an icon

```swift
Image.app(.vehicles)                      // SwiftUI image
Label(L10n.Settings.feedback, icon: .feedback)   // text + icon
UIImage.app(.vehicles)                    // UIKit (optionally with a size/weight configuration)
Image.app(.vehicle(vehicle.type))         // bike or car icon for a vehicle
```

Views never write a symbol name themselves.

## How it is built

- `AppIcon` is an enum with one case per icon, grouped by purpose (tab bar, vehicle kinds, actions, feedback, tour, appearance picker).
- `AppIcon.symbolName` maps each case to its SF Symbol. Two cases may share a symbol (the Vehicles tab and the car icon both use `car`) so they can be changed independently later.
- Extensions on `Image`, `UIImage` and `Label` are the only way to turn an `AppIcon` into something on screen.
- All current icons are SF Symbols: they scale with Dynamic Type and follow the text colour. The asset catalog only holds the app icon and accent colour, which the system uses.

## Adding or changing an icon

1. Add a case to `AppIcon` and a line to `symbolName`.
2. Use it with `Image.app(.yourCase)`.
3. Run `swift test`.

For a bundled picture instead of a symbol, add it to `Assets.xcassets` and expose it in `AppImages.swift` the same way (for example `static var logo: Image { Image("Logo") }`), so views still never name images.

## Directional icons and right-to-left

Prefer symbols that flip automatically (`chevron.forward`, not `chevron.right`). Check anything that implies direction in the Arabic scheme (see [localization.md](localization.md)).

## What the tests check

`ImageCentralizationTests` (run with `swift test`):

- no `systemName:`, `systemImage:`, `Image("…")` or `UIImage(named:)` anywhere outside `AppImages.swift`
- every `AppIcon` case has a symbol name
- every symbol name exists in the SF Symbols catalogue and is available on iOS 17 (skipped on a machine without the catalogue)
- every icon is used by the app (bike and car are reached through `AppIcon.vehicle(_:)`)
