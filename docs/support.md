# Support: feedback and sharing

Both live in **Settings → Support**.

## Placeholders to edit before release

In `VehicleCare/Core/AppInfo.swift`:

| Constant | Used for |
| --- | --- |
| `feedbackEmail` | recipient of feedback emails (currently `feedback@example.com`) |
| `appStoreURL` | link in "Share this app with friends" (currently a placeholder App Store URL) |
| `shareMessage` | text sent with the share link |

## Send feedback

`UI/FeedbackView.swift`, logic in `Core/Feedback.swift`.

1. The user picks a category (broken / idea / other), writes a message, and optionally attaches files. **Send** in the top bar stays disabled until there is a message.
2. **Attachments**: photos and videos via `PhotosPicker`, other files via the system file importer. Each is copied into a temporary folder (`feedback-attachments`, one sub-folder per file so equal names never collide) and file names are sanitised. Limits: 5 files and 20 MB in total (`Feedback.maxAttachments`, `Feedback.maxTotalBytes`); anything over is refused with a message. Temporary files are removed when the screen closes.
3. **Send** opens the system mail composer (`MFMailComposeViewController`) addressed to `AppInfo.feedbackEmail`, subject `[Vehicle Care] Bug report | Suggestion | Feedback`, with the attachments added using their MIME types.
4. If Mail is not set up (`canSendMail() == false`), a dialog offers **Share with another app** (text plus the attachments in the system share sheet, so Gmail and others work) or **Copy email address**.
5. **Device info** (app version, build, iOS version, device model identifier) is appended to the message only when the toggle is on (default on). No personal data is included.

The email itself is **not localized** on purpose (subject, device-info lines): it is read by the developer. The screens, dialogs and the share-app message are localized.

The attachment limit is **20 MB** (`Feedback.maxTotalBytes = 20_000_000`, decimal, so it reads "20 MB").

Nothing is sent by the app itself: the user always reviews and sends the email.

## Share this app

A `ShareLink` with `AppInfo.appStoreURL` and `AppInfo.shareMessage`, which opens the system share sheet.

## Tests

Unit tests (`Tests/CoreTests/FeedbackTests.swift`) cover the subject, body, attachment limits, MIME types, file-name sanitising and placeholder format. UI tests cover the Settings rows, the disabled Send button, and the no-Mail fallback dialog. The mail composer itself, the photo picker and the share sheet are system UI and need a manual check on a real device.
