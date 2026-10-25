# Release process

Version numbers are explained [below](#version-numbers).

## Steps

1. `swift test` and the UI tests pass (Product → Test in Xcode) and the app builds.
   Check every language has all strings (`swift test` fails if not) and that new text was reviewed by a native speaker for each language (see [localization.md](localization.md)).
   Check `AppInfo.feedbackEmail` and `AppInfo.appStoreURL` are no longer placeholders.
2. In `CHANGELOG.md`, rename **Unreleased** to `## [1.0.0-beta.N] - YYYY-MM-DD` and add a new empty **Unreleased**.
3. Set the version in the app target's build settings: `MARKETING_VERSION` (for example `1.0.0-beta.6`) and `CURRENT_PROJECT_VERSION` (the build number, same as the beta number). Settings → Version and the feedback email read it.
4. Commit `chore(release): v1.0.0-beta.N`, then `git tag v1.0.0-beta.N`.
5. Archive in Xcode and upload to App Store Connect / TestFlight.

## Version numbers

**While in beta**, every release is `1.0.0-beta.N`: only `N` goes up, for fixes and features alike. The `1.0.0` part stays put until the first stable release. In `CHANGELOG.md` the heading is `## [1.0.0-beta.N] - YYYY-MM-DD`.

**After the first stable release** (`1.0.0`), use Semantic Versioning: PATCH for bug fixes, MINOR for features that keep data and backups working, MAJOR for breaking changes such as a backup format older versions cannot read.

**App Store / TestFlight:** Apple only accepts numeric versions (`1.0.0`) as the marketing version, so a version containing `-beta.N` can be built and run but not uploaded. Before the first TestFlight or App Store upload, change `MARKETING_VERSION` to `1.0.0` and use the build number (`CURRENT_PROJECT_VERSION`, which must increase with every upload) to tell beta builds apart. Keep the `1.0.0-beta.N` label in the changelog and tags (`v1.0.0-beta.N`).

## Keep docs and changelog current

Every change that users or developers can notice updates, in the same commit: `CHANGELOG.md` (under **Unreleased**), `README.md` if features or setup changed, and the relevant file in `docs/`.
