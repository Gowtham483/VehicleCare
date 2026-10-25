# Roadmap

What is planned, and which version it belongs to. **Nothing under 1.1.0 or 1.2.0 is built yet**; items are only built when the owner says which ones go into which release.

## How releases map to versions

| Version | What it is |
| --- | --- |
| `1.0.0-beta.N` | Betas. Under 1.0.0 the only new feature is the chain-lube quick action (beta.5). |
| **1.0.0** | The first stable release, once the betas are done. No other feature work is planned before it. |
| **1.1.0** | **India-first release**: the five epics below. |
| **1.2.0** | **Global release**: units, currencies, regions, languages. A to-do. |

How version numbers are written and bumped: see [release-process.md](release-process.md).

## Decisions log

| Date | Decision |
| --- | --- |
| 2026-10-24 | The audience is **India first**. A Global release is separate and later. |
| 2026-10-24 | **Odometer: yes.** Service plans by kilometres, months, or whichever comes first. |
| 2026-10-24 | **Keep history forever by default** (the silent 24-month deletion goes away). Scheduled for 1.1.0, so **1.0.0 still deletes records older than 24 months**. |
| 2026-10-24 | Only the **chain-lube quick action** is added to the betas under 1.0.0. |
| 2026-10-24 | Chain lube means *clean and lube the chain* (not an engine oil change, which is a normal service entry). Default reminder **30 days**, editable. |
| 2026-10-24 | India-first = **1.1.0**. Global = **1.2.0**. |
| 2026-10-25 | **Siri and widgets are planned.** Quick actions become App Intents (Siri, Spotlight, Shortcuts, Action Button), and **widgets show the quick actions only**. Built in 1.1.0 (epic E6); spoken-language and unit work follows in 1.2.0. |

## 1.0.0-beta.5: chain lube quick action (done)

A **Lubed chain** button for bikes, an optional amount and note, a reminder (default 30 days, set in Settings → Reminders), "Chain last lubed" on the vehicle screen, and a "Chain lubed" history row. Adds database schema version 2 and backup file version 2 (only for files that contain chain-lube data).

## 1.1.0: India-first release (to do)

### E1. Reminders you can't miss
- A reminder that has fired becomes **overdue** instead of vanishing (today `ReminderService.sync` deactivates it, `Core/Reminders.swift`). Overdue shows on the vehicle card and list, with a badge.
- Repeat or nag until done; **snooze**; a **"Mark done"** button on the notification itself (logs the quick action).
- Several lead times (30, 7 and 1 day before), not one.
- After a service is saved, schedule the next reminder automatically from its plan (for example "every 6 months").
- Notification permission denied: a persistent banner with a button that opens iOS Settings (today the user is told once).
- iOS keeps only the **64 soonest pending local notifications**: schedule the nearest and top up on launch and when the app returns to the foreground; show anything queued but not yet scheduled.
- Quiet hours, grouped notifications, a daily digest option.
- **Edit** quick logs (today they can only be deleted, by long-press) and **undo** or a recently-deleted area for deletes.

### E2. Odometer and service plans
- Odometer on services, fuel fill-ups and quick logs; a current odometer per vehicle.
- Intervals by distance, time, or **whichever comes first**; a **predicted due date** from the average daily distance.
- Presets for bike, scooter and car (engine oil, filters, chain lube, valve clearance, brake fluid, coolant, battery, tyre rotation, timing belt), always editable and labelled "check your owner's manual".
- Severe-use switch (dust, short trips, towing) that shortens intervals. Chain items only for chain-drive bikes.
- **Mileage per fill** with the full-tank method: a "filled to full" flag, partial fills deferred to the next full fill, missed fills excluded. Cost per km.
- Sanity checks: odometer going backwards, probable typos, rollover.

### E3. Documents and renewals (India)
- Insurance, pollution certificate (PUC), registration (RC) validity, road tax, fitness certificate, permit, driving licence.
- Reminders per document, editable (competitors use about 30 and 7 days for insurance, 14 and 3 days for PUC).
- A **document vault**: photo or PDF of each document, policy number, insurer helpline.
- Warranty and extended-warranty dates, loan EMI due date and end date, FASTag recharge, annual service.
- India languages (**Hindi, Tamil**) proposed for this release, to be confirmed.

### E4. Receipts and PDF service history
- Photos and receipts attached to services, included in backups, with a size warning.
- A **shareable PDF service history** per vehicle for resale (full history raises resale value; missing history lowers it).
- Search history, and a per-item "**when did I last change X?**" (item categories instead of free-text part names).
- Workshop contacts (name, phone, address, last visit).

### E5. Data safety
- **History kept forever by default.** Optional cleanup that first exports an archive and tells the user.
- Automatic backup or **iCloud** (CloudKit, no external package), a "last backup" indicator and a nudge.
- **Import** from Fuelly, Drivvo and Simply Auto CSV, so switching apps is not a restart.

### E6. Quick actions everywhere: Siri, Shortcuts and widgets

Goal: log tyre air, petrol and chain lube in a couple of seconds, at the petrol pump or from the lock screen, without opening the app. Everything below uses Apple frameworks only (App Intents, WidgetKit, App Group); no external package.

**Siri, Spotlight, Shortcuts, Action Button (App Intents)**
- One App Intent per quick action: **Log tyre check**, **Log petrol** (optional amount and litres), **Log chain lube** (bikes only). Each takes a **Vehicle** (an App Entity read from the database) and defaults the date to today.
- **App Shortcuts** make them work with no setup: spoken phrases such as "Log petrol in Vehicle Care" or "Lubed my chain in Vehicle Care". Siri asks "which vehicle?" when there is more than one; a **default vehicle** setting skips that question. Siri confirms out loud ("Logged petrol for Duke. Reminder set for 24 Nov").
- The same actions appear in the Shortcuts app and Spotlight, and can be bound to the **Action Button** (iPhone 15 Pro and later) and, on iOS 18, to Lock Screen and Control Center controls (guarded by an iOS version check, since the app supports iOS 17).
- Each action also sets the usual reminder (the same interval as in the app). If notifications are not allowed, the reminder is saved and scheduled later by `ReminderService.sync`, as today.
- A mistake must be fixable: a mis-heard amount needs the **edit and undo** work from E1, so E6 is built after E1.
- With the odometer from E2, the intents accept an optional odometer value.

**Widgets (quick actions only)**
- Home-screen widgets (small and medium) and **Lock Screen widgets** that show only the quick-action buttons for one vehicle: Tyre, Petrol and, for bikes, Lube. No charts, no stats, no history.
- The vehicle is chosen when the widget is added (widget configuration using the same Vehicle entity). Interactive widgets (iOS 17 and later) run the action when a button is tapped, without opening the app.
- Open question: Tyre and Lube are one tap with defaults. Petrol needs an amount, so either it opens the quick-log sheet, or it logs with no amount and the amount is added later. Decide before building.
- A double tap must not log twice: ignore a repeat of the same action, vehicle and day within a few seconds, and offer undo.
- The widget refreshes after every write (`WidgetCenter` timeline reload).

**Groundwork this needs (do it first within E6)**
- Siri and widgets run in other processes, so the database must live in a shared **App Group container**. Existing users' databases are **copied once** (the `.sqlite`, `-wal` and `-shm` files, while the database is closed), guarded by a flag, with a verified copy before the old file is removed and a fallback if anything fails.
- Sharing SQLite between processes needs: WAL mode, a busy timeout (`sqlite3_busy_timeout`), short transactions, and never holding a lock while the process may be suspended (the system kills such processes, error `0xDEAD10CC`). The current `Database` wrapper has none of these yet.
- Shared code: `Core/` is compiled into the app, the widget extension and the intents, so logic stays in one place. New targets: a Widget Extension and the App Group entitlement. Check that the App Group capability works with the signing account in use.
- The app must pick up writes made by the other processes when it returns to the foreground (`AppModel.revision` only changes on its own writes today).
- Which process runs a widget button's action has differed between iOS versions, and Control Center controls have been unreliable in some versions. Test on every supported iOS version; design the intent so it works wherever it runs.

**Privacy**
- Vehicle names will appear on the lock screen and in Spotlight, and actions can run while the phone is locked. Add a setting to require unlock for actions, and keep what Siri says short. This interacts with the Face ID lock in the backlog.

**Localization of Siri phrases (needs 1.2.0 work, see below)**
- App Shortcut phrases and titles are fixed at build time, so they cannot use the runtime `L10n` lookup; they need their own string table per language, and the "no hard-coded text" test needs a matching allowance.
- English works first. Arabic is a supported Siri language. Siri does not support Tamil as a standalone language (Apple documents Tamil only mixed with English in English (India)), so Tamil phrases may not be possible; Tamil speakers would use English (India) phrases. Verify the current list before promising any language.

**Tests:** unit tests call each intent's `perform` against an in-memory store (log created, reminder set, duplicate ignored, bikes only for lube, vehicle entity lookup); a test builds a pre-move database, runs the copy and checks all data and rollback on failure. Siri, widgets and the Action Button can only be verified on a real device, so a manual checklist is part of the release.

## After 1.1.0: unscheduled backlog
Charts and total cost of ownership (insurance, tax, tolls, parking, fines, tyres, depreciation), entry categories and budgets, Apple Watch quick log (reusing the E6 App Intents), full home-screen widgets with stats (E6 widgets show quick actions only), EV and CNG logging (kWh, home vs public charging), archive a vehicle as sold, family members and "who filled this", Face ID lock, accessibility audit (Dynamic Type at the largest sizes, VoiceOver), recall links.

## 1.2.0: Global release (to do)
- **Units:** km or miles, litres or gallons, km/L, L/100 km, mpg.
- **Currency per vehicle** (today one symbol for the whole app) and multi-currency for travel.
- Date and number format settings.
- **Region-agnostic documents:** user-defined document types or per-country templates (for example registration, inspection, road tax or low-emission zone rules elsewhere).
- **More languages**, each reviewed by a native speaker. The existing Arabic text also still needs review.
- **Siri and widgets, Global:** Siri phrases in more languages (each needs its own phrase table and a check that Siri supports the language), spoken amounts and units that follow the unit and currency settings ("5 litres" or "2 gallons"), and widget text in every supported language.
- Region-specific recall links, a privacy policy suitable for other regions, time-zone behaviour while travelling, and **parity for the Expo app**.

## Edge cases to test in every release
Time-zone and daylight-saving changes; device date changed; reinstall (OS-scheduled reminders are lost until the next launch or import); restore on a new phone; partial and missed fills; odometer typos or going backwards; very large histories; long, emoji or right-to-left vehicle names; two vehicles with the same name; deleting a vehicle that has reminders; notification permission changed while the app is running; a widget or Siri action while the app is suspended, the phone is locked, or the database is briefly locked by another process; a double tap on a widget button; a stale widget after a write; notifications not allowed when an action runs; the one-time database move interrupted halfway; the App Group database missing or unreadable.

## Research basis
Findings come from competitor listings, user reviews and forums, so feature lists are marketing claims and complaint patterns are secondhand. Treat them as direction, not proof.

- Competitors and features: [AAA, best car maintenance apps](https://www.acg.aaa.com/connect/blogs/4c/auto/best-car-maintenance-apps), [Progressive](https://progressive.com/lifelanes/?p=47221), [Rovo alternatives](https://alternativeto.net/software/rovo-car-maintenance-tracker)
- Motorcycle apps: [DirtTime](https://apps.apple.com/app/id6752694574), [Vehicle Check](https://apps.apple.com/app/id1116488662), [Strox](https://apps.apple.com/us/app/strox/id6748987198), [GeoRide interval calculator](https://eu.georide.com/blogs/georide/calculateur-entretien-moto)
- Complaints (data loss, missing export): [Auto Care Kit reviews](https://appfollow.io/ios/auto-care-kit/1453344602?country=us), [Car Maintenance Reminders reviews](https://justuseapp.com/en/app/1617869280/car-maintenance-reminders/reviews)
- Fuel economy method: [LubeLogger fuel records](https://docs.lubelogger.com/Records/Fuel%20Records), [Fuelly partial fill-ups](https://www.fuelly.com/forums/f2/when-using-partial-fill-ups-18626-post188715.html?nojs=1)
- India documents: [VahanScan](https://apps.apple.com/app/id1450485590), [Expiry Guard](https://mwm.ai/fr/apps/expiryguard-document-reminder/6777413276), [Shriram GI, essential documents](https://www.shriramgi.com/article/essential-car-documents-india)
- iOS 64-notification limit: [Apple Developer Forums](https://developer.apple.com/forums/thread/811171), [workaround thread](https://developer.apple.com/forums/thread/106829)
- Service history and resale value: [Carwow](https://www.carwow.co.uk/car-valuation/guides/does-service-history-affect-car-value), [Shriram Finance (India)](https://www.shriramfinance.in/articles/used-car-loan/2026/car-service-records-why-are-they-important-how-do-they-increase-car-resale-value)
- Service intervals: [KBB](https://www.kbb.com/car-advice/car-maintenance-service-intervals/), [Haynes](https://uk.haynes.com/de/pages/maintenance-plans-car)
- Ownership costs: [WhichCar](https://www.whichcar.com.au/advice/hidden-costs-of-car-ownership)
- EV trackers: [EV Charge Tracker](https://apps.apple.com/app/id6754165643)
- Siri and widgets: [App Shortcuts provider tutorial](https://www.createwithswift.com/performing-your-app-actions-with-siri-through-app-shortcuts-provider/), [App Intents field guide](https://api.superwall.me/blog/an-app-intents-field-guide-for-ios-developers), [which process runs a widget intent](https://defn.io/2025/04/13/performing-widget-intents-in-ios-app), [iOS 18 interactive widget forum thread](https://developer.apple.com/forums/thread/758784), [Control Center control forum thread](https://developer.apple.com/forums/thread/789371)
- Sharing a database with a widget: [moving a store into an App Group (Apple forums)](https://developer.apple.com/forums/thread/756708), [GRDB, sharing a database](https://mintlify.com/groue/GRDB.swift/guides/sharing-a-database)
- Siri languages: [Apple, using multiple languages with Siri in India](https://support.apple.com/en-ae/105012), [Arabic support in Siri](https://venturebeat.com/ai/apple-brings-arabic-language-support-to-siri)
