# Backup format

Identical to the Expo app. One JSON file, `vehicle-care-backup-YYYY-MM-DD.json`:

```jsonc
{
  "app": "vehicle-care",
  "schemaVersion": 1,        // 2 only when the file contains a chain-lube entry (see Versioning)
  "exportedAt": "2026-10-24T10:00:00.000Z",
  "vehicles":     [{ "id": 1, "type": "bike", "name": "Duke", "make": "", "model": "", "reg_no": "", "created_at": "…" }],
  "services":     [{ "id": 1, "vehicle_id": 1, "date": "2026-05-01", "title": "…", "notes": "…", "labour_cost": 300, "total_cost": 940, "next_due_date": null, "created_at": "…" }],
  "serviceParts": [{ "id": 1, "service_id": 1, "name": "Oil", "price": 400, "qty": 1 }],
  "quickLogs":    [{ "id": 1, "vehicle_id": 1, "kind": "petrol", "date": "2026-10-01", "cost": 500, "litres": 5.2, "note": "" }],
  "reminders":    [{ "id": 1, "vehicle_id": 1, "service_id": null, "kind": "tyre_air", "fire_at": "…", "label": "…", "active": 1 }],
  "settings":     { "tyreIntervalDays": "14", "currency": "₹" }
}
```

Optional values are written as explicit `null` (the Expo importer requires the key to be present). Notification ids, `onboardingDone` and `appearance` (the light/dark choice) are not exported: they are per-device.

## Import

1. Validate before writing: app id, `schemaVersion` not newer than the app, all tables present, field types and enum values, date formats, and that every reference exists. Errors name the field and entry.
2. The user chooses **Merge** or **Replace all** (replace asks twice).
3. One transaction; any error rolls back and leaves existing data untouched.
4. Ids are regenerated and relations remapped.
5. Afterwards: settings reload, retention purge, `ReminderService.sync()` re-creates notifications for future reminders.

Merge treats these as duplicates and skips them: vehicles with the same type, name and registration; services with the same vehicle, date, title and total; quick logs with the same vehicle, kind, date, cost and litres; reminders with the same vehicle, kind, service and time.

Versioning: older files go through `Backup.migrate`; newer files are refused with a message to update the app.

- **Version 1** is the original layout, shared with the Expo app. Quick-log kinds: `tyre_air`, `petrol`. Reminder kinds: `tyre_air`, `petrol`, `service`.
- **Version 2** adds the `lube` kind (chain lube, bikes only) to quick logs and reminders. `Backup.build` writes version 2 **only when** the data contains a `lube` quick log or reminder; otherwise it writes version 1, so files without chain-lube data keep working in the Expo app and in older builds. An older app refuses a version 2 file with its "newer version" message.
- This app imports both versions. The `lubeIntervalDays` setting is included in `settings`; older apps ignore settings keys they do not know.
