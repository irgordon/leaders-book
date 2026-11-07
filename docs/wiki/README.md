# The Leaders Book Wiki

[App Overview](../../README.md) · [Installation](../../INSTALL.md) · [Current Screenshots](../../Previews/Current-Walkthrough-2026-11-06/README.md)

## Features and Definitions

- **Today:** team counts, overdue training, latest saved Army Fitness Test (AFT), and tool shortcuts.
- **Soldiers:** create, edit, search, and delete profiles; import photos from Photo Library/Files or take one with Camera. Missing photos use a drawn placeholder. [Rank Insignia Credits](../../RANK-INSIGNIA.md) cover the sourced SVG/PNG artwork; PVT/E-1 has no worn emblem.
- **Training:** current linked AFT and height/weight records, alternating completed-training rows, completion dates, and optional PDF/image certificates. Legacy completions remain undated. Certificates use a read-only app viewer with a separately authenticated export action.
- **Fitness:** five-event AFT reference scoring by age and standard, saved results, optional Soldier assignment, and history. Each event is Go/No Go; the overall result is Meets Standard/Does Not Meet Standard.
- **HT/WT Calculator:** waist-to-height ratio in inches or centimeters, not a body-fat percentage or Army body-composition compliance determination. Changing units clears measurements. Recorded height/weight measurements are separate from this ratio tool.
- **Guides:** searchable offline study summaries, eight troop-leading steps, and links to official Army services. Verify current doctrine with the official source.

A normal installation starts with an empty roster. Previews use fictional fixtures in separate simulator storage. Calculator drafts persist automatically; saving an AFT requires all five events and a Soldier or Personal Result assignment.

## Privacy and Data Lifecycle

Current deployment policy is **personal devices with synthetic data pending organizational approval**. This is an operating policy, not an app-enforced synthetic-data mode.

Details and attachments require system device authentication. Locking is immediate on manual lock, backgrounding, or protected-data unavailability; the cold locked screen opens no private repository. Subsequent locks can show cached aggregate counts. Soldier editor drafts survive locks in access-controlled process memory until Save, Discard, scene disconnect, or process exit. Other editors discard unsaved entries on lock.

Each notes/certificate export requires fresh authentication. Saved notes are nonselectable; editor copy/cut, drag, and Writing Tools are restricted. Screenshots, recording, mirroring, and already-exported copies remain outside these controls. [Threat Model](<../Army App - Leaders Book-threat-model.md>) and [Authentication Findings](../AUTHENTICATION-FINDINGS.md) describe the boundaries and open checks.

System backups remain eligible and may retain deleted data. One calendar year after a Soldier’s last saved update, retention warnings request review; deletion requires confirmation. Deleting a Soldier removes linked results, the calculator assignment, and unshared attachments from the app. Personal results, imported originals, exports, and backups are outside that deletion scope.

There is no app account, cloud sync, advertising, analytics, or app-owned record upload. Photo Library uses selected-item access; Files uses security-scoped import; Camera handles unavailable hardware/permissions. Official-service links open separately and require connectivity.

## Storage and Architecture

Version-1 JSON is stored at `Application Support/LeadersBook/records.json`; attachments use UUID filenames in `Attachments`. `BookRepository` owns filesystem work on an actor; decoded DTOs become validated domain values. Malformed saved data blocks loading while preserving the original. Revision IDs detect conflicting edits; optional legacy media/date/measurement fields remain compatible.

Atomic protected writes, `pending-transaction.json`, and the root transaction marker coordinate records and attachments. Cleanup failures preserve causes and journal state for explicit recovery; unknown commit outcomes preserve affected files. Shared attachments remain until their last reference is removed. [Architecture Audit](../ARCHITECTURE-AUDIT.md) defines consistency, recovery, and retry contracts.

Imports are limited to 10 MB. Portraits become JPEG thumbnails; JPEG/PNG certificates retain original bytes, while other supported certificate images convert to full-resolution JPEG. Imports remain in memory until Save. UI operations own cancellation and stale-result checks; calculator autosave uses an owned debounce with visible errors.

## Scoring Data

[`aft-scales.json`](../../LeadersBook/Resources/aft-scales.json) records the [Army scoring PDF](https://www.army.mil/e2/downloads/rv7/aft/AFT_Scoring_Scales_250601.pdf), effective June 1, 2025, with SHA-256 `572ee5afe149add73e951c404ee2f120cd98a2746b2888746a6012009a7c366d`. This documents the bundled data, not a fresh verification of current Army policy.

The lookup awards the highest achieved published threshold without interpolating blank cells. Faster sprint–drag–carry/run times and higher plank/push-up/deadlift results score better. The bundled combat standard uses M|C columns and 350 total; general standards use 300 total. Both require at least 60 per event. Policy updates require reviewing the data and tests.

## Apple Design and Project Reference

Built using [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/), targeting [iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo). System tabs, navigation, forms, sheets, semantic text styles, and adaptive themes support compact/regular layouts; Soldiers and Guides use sidebar/detail navigation at regular widths. No simulated clock, camera clearance, or hinge is drawn. Actual Duo behavior and full accessibility compliance remain unverified.

The app uses SwiftUI, Observation, Swift 6 language mode, strict concurrency, a main-actor UI store, actor-owned persistence, and Sendable values. Scene storage retains selected tab/Soldier; calculator drafts persist through the repository. `LeadersBook/App`, `Core`, `Views`, and `Resources` contain entry points, domain/storage/scoring, UI, and assets/data; `Tests` contains core and native checks against the real app/filesystem.

[Governance](../GOVERNANCE.md) · [Theme Validation](../THEME-VALIDATION.md) · [App Store Audit](../APP-STORE-RELEASE-AUDIT-2026-11-05.md) · [Historical Validation](../../VALIDATION.md) · [Original Prototype Review](../../IOS-REVIEW.md). Dated reports describe their own snapshots; the newer audit sections record subsequent corrections.
