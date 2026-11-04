# The Leaders Book

A native SwiftUI iOS app for managing a leader’s local soldier records, training checklists, and fitness calculations. The supplied Figma web prototype is the content reference; the native app has no Figma, web server, or third-party package dependency.

## Open and run

Open `LeadersBook.xcodeproj` in **Xcode 27.2 or later**, select the **LeadersBook** scheme, and choose an iPhone Duo simulator or physical device. The deployment target is iOS 27.0. iPad is also supported for regular-width layouts.

For a physical device, select your development team under Signing & Capabilities and use a bundle identifier assigned to your team. No signing identity or Apple account is embedded in this project.

```sh
# Build for iOS Simulator without a signing account.
./script/build_and_run.sh --build

# Build, install, and launch on an available simulator.
./script/build_and_run.sh

# Or choose a specific simulator.
SIMULATOR_UDID=<device-uuid> ./script/build_and_run.sh
```

The script prefers an available Duo, then an iPhone 18 Pro. On installations without Simulator.app, it launches through CoreSimulator in headless mode.

## Working features

- **Today:** team counts, overdue training items, last saved AFT, and direct tool shortcuts.
- **Soldiers:** add, edit, search, and delete soldiers; import a photo from Photo Library or Files, or take one with Camera; display a generic drawn placeholder for missing photos and the corresponding Army rank insignia in the roster and record. See [Rank Insignia Credits](RANK-INSIGNIA.md) for the sourced Wikimedia artwork. PVT / E-1 displays rank text without an invented emblem.
- **Training Record:** show the latest dated, linked AFT result and HT/WT measurements above alternating completed-training rows. Add training titles, one or more completion dates, and an optional PDF/image certificate. Preview certificates with the system document viewer. Existing undated checklist completions remain undated, and pending items remain visible.
- **Fitness:** five-event AFT scoring by age band and general male, general female, or combat standard; input validation; saved results optionally linked to a soldier; result history and deletion.
- **HT/WT Calculator:** positive-measurement waist-to-height ratio calculation in inches or centimeters. Switching units clears measurements to prevent accidental reinterpretation. This is not an Army body-composition compliance calculation. The saved tool identifier remains unchanged so existing calculator drafts still load.
- **Guides:** searchable offline study summaries, eight troop-leading steps, and links to official Army services.

Start with an empty roster. No sample people or fitness records are inserted into your data. To save an AFT, enter all five results, choose a soldier or Personal result, and select Save AFT Result. Calculator drafts persist automatically, including partial inputs.

## Storage and privacy

The app stores version-1 JSON at `Application Support/LeadersBook/records.json`. `BookRepository` owns filesystem work on an actor. Decoding produces boundary DTOs, then immutable validated domain values; malformed saved data blocks loading and preserves the original file. The main-actor store owns UI state and editing drafts, and ready views receive immutable snapshots.

Existing optional photo, certificate, completion-date, and HT/WT fields remain compatible. Legacy completions stay undated, and untracked due-date metadata remains intact. Soldier edits use committed revision IDs to detect stale editors; old files acquire revision metadata on a later successful save without changing record IDs or historical dates.

Attachments use UUID filenames under `Application Support/LeadersBook/Attachments`, with complete iOS file protection. Imports remain in memory until Save. Atomic writes, a persisted `pending-transaction.json` journal, and the root `lastTransaction` marker distinguish committed data from imports requiring rollback. Cleanup failures retain their causes and journal, with an explicit UI retry. An unknown commit outcome preserves the affected files; a confirmed commit accompanied by an I/O warning is shown as saved with a warning rather than inviting duplicate saves. Shared files remain until their last reference is removed. See [Architecture Audit](docs/ARCHITECTURE-AUDIT.md) for the exact consistency and retry contract.

Imports are limited to 10 MB. Portraits normalize to JPEG thumbnails; JPEG/PNG certificates retain original bytes and resolution, while other supported certificate images convert to full-resolution JPEG. A missing or invalid media file is reported in its own operation and does not block unrelated calculator work. UI-owned imports and previews cancel on dismissal/replacement and reject stale completions. Calculator input autosaves through an owned debounce, with failures visible and draft input retained.

The Camera button handles missing hardware and denied permission. Photo Library uses the system Photos picker with access to selected items only. Files uses the system importer. These features do not upload records to a server.

Deleting a soldier also deletes their linked AFT history and removes their calculator assignment. Personal results remain. Destructive actions require confirmation. Editing a soldier uses a separate draft; Cancel does not modify the record.

There is no app account, cloud sync, analytics, advertising, or network data submission. System device backups may include app data according to the device’s backup settings. Official-service links open separately and require connectivity. The app obscures its content when its scene becomes inactive. Device protection does not establish authorization to store organizational information; use the app within your organization’s permitted data handling rules.

## Apple platform implementation

System `TabView`, `NavigationSplitView`, `NavigationStack`, `Form`, `List`, sheets, alerts, menus, and semantic toolbar placements provide adaptive navigation. The system owns status indicators, safe areas, bar positioning, and standard container behavior. The app draws no simulated clock, camera clearance, hinge, or custom navigation rail. Text uses semantic Dynamic Type styles and system symbols, with adaptive light/dark colors.

Soldiers and Guides expand into sidebar/detail navigation at regular widths and collapse at compact widths. Selected soldier and tab use scene storage; calculator drafts are UI-owned and asynchronously persisted through the repository rather than being tied to a destination view. The code uses Swift 6 language mode, complete strict concurrency checking, main-actor isolation for the observable store, and Sendable value models. No Xcode 27.2-only API has been presumed available from the 27.0 build host.

References: [Duo HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), [Preparing your app for Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo).

## Scoring data

`LeadersBook/Resources/aft-scales.json` preserves the scoring data from the supplied archive. All threshold cells were independently compared with the [official Army PDF](https://www.army.mil/e2/downloads/rv7/aft/AFT_Scoring_Scales_250601.pdf), effective June 1, 2025. The downloaded PDF SHA-256 matches the hash recorded in the JSON: `572ee5afe149add73e951c404ee2f120cd98a2746b2888746a6012009a7c366d`.

Scoring awards the highest achieved published threshold without interpolation across blank cells. Sprint–drag–carry and run award points for faster times; plank, push-ups, and deadlift award points for larger results. Combat uses the M|C columns and requires 350 total; general standards require 300. Both require at least 60 per event. The app labels this as a reference calculation and links the official source. Updating Army policy requires reviewing and updating the bundled data and tests.

## Tests

```sh
swift test --scratch-path /private/tmp/leaders-book-tests --filter FitnessTests
swift test --scratch-path /private/tmp/leaders-book-tests --filter LeaderStoreTests
swift test --scratch-path /private/tmp/leaders-book-tests

# Run real-interface iOS tests on your selected simulator.
xcodebuild -project LeadersBook.xcodeproj -scheme LeadersBook \
  -destination 'platform=iOS Simulator,name=iPhone Duo' test
```

The Swift package compiles the same Core files and scoring resource used by the iOS target. Tests exercise real filesystem storage rather than replacing it with a mock, covering relaunch, edit, deletion, partial drafts, linked results, corrupt data, failed writes, scoring boundaries, parsing, and ratio math. The UI test target exercises the real application.

## Layout of the source

- `LeadersBook/App`: application entry point.
- `LeadersBook/Core`: models, persistence, scoring, and offline reference content.
- `LeadersBook/Views`: native destination and editing views.
- `LeadersBook/Resources`: scoring data, app assets, and privacy manifest.
- `Tests`: core and iOS UI tests.

## Validation limits on this machine

The installed toolchain is **Xcode 27.0 / iOS 27 SDK**, with Swift 6.4. Xcode 27.2 is not installed, and no Duo simulator device type is available. Native simulator builds and the expanded core regression target passed; current counts and commands are in `VALIDATION.md`. See `VALIDATION.md` for final device-build and UI-test results. Physical-device signing, Duo folding/pose transitions, reserved-region behavior, Split View placement, VoiceOver, and Xcode 27.2 execution must be checked with the appropriate toolchain and hardware before release.

[Validation results and native screenshots](VALIDATION.md)

[Labeled Compact and Expanded Cover/Record Previews](Previews/README.md)
