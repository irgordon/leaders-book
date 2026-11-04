# Architectural Compliance Audit

Date: November 2, 2026. Policy: [AGENTS.md](../AGENTS.md). Scope: the approved remediation of findings F1–F6, preserving the native app, its records, and meaningful existing coverage.

**Implementation review: Pass for the six audited findings.** Functional and failure-path validation results are recorded separately below. This is a code-backed review, not a claim that a text search or successful build proves every possible runtime condition.

## Resolution Matrix

| Finding | Resolution | Verification |
| --- | --- | --- |
| F1: Persisted data bypassed domain invariants | Closed. `BookDTO`, `SoldierDTO`, `TrainingDTO`, `AttachmentDTO`, and `AFTResultDTO` are perimeter representations. Reload constructs immutable `Soldier`, `TrainingItem`, `HeightWeightRecord`, `RecordAttachment`, and fixed five-event `AFTResult` values. Invalid input is rejected before publishing a snapshot. | Malicious persistence tests reject an empty name, age band 999, and a single `[500]` score without rewriting the original file. Legacy fixtures retain identifiers, undated completions, untracked due dates, photos, certificates, and measurements. |
| F2: Parse errors and invariant violations shared sentinels | Closed. `EventPerformance`, `AgeBand`, `EventPoints`, `FitnessProfile`, and `RatioMeasurement` validate inputs. Missing input and malformed input throw distinct `FitnessInputError` cases. Draft evaluations explicitly distinguish empty, invalid, and scored fields. Published missing threshold cells remain genuine absence. Camera cancellation and capture/encoding failure are distinct. | Published scoring fixtures and every threshold/combat column remain covered. Negative parser and malicious-result tests use specific typed errors. UIKit adapter compiles; hardware capture remains a device check. |
| F3: Error provenance reduced to strings | Closed. `AppFailure` retains originating errors, context, and secondary compensation errors. `rootCause` exposes the original diagnostic error; sanitized `UserPresentableError` text is separate. UI alerts receive non-optional failure values. | Filesystem error provenance, nested causes, secondary errors, and presentation redaction are asserted. No production `errorMessage` or `loadError` string store remains. |
| F4: Attachment cleanup failures suppressed | Closed. `BookRepository` uses atomic writes, a persisted transaction journal, a root transaction marker, authoritative outcome resolution, and explicit cleanup status. Failed cleanup retains the journal and its causes; it is not reported as a fully clean save. | Real filesystem permission failure, restart replay, successful recovery, uncommitted import rollback, referenced-file protection, shared ownership, and failed-write preservation tests. No storage boundary was replaced by a mock. |
| F5: Import tasks lacked ownership | Closed. `OwnedOperation` binds its running task and ID to an enum case, cancels replacement/dismissal, checks cancellation before publishing, and retains cancellation context separately. File/photo processing uses `@concurrent`; portrait loading uses SwiftUI's structured `.task(id:)`. Certificate preview is scene-owned. | Cancellation/replacement tests prevent stale publication; provider cancellation retains its original cause; real photo and training UI workflows exercise the adapters. |
| F6: State-specific data was independent of state | Closed. Store loading is `BookLoadState`; repository state binds its loaded book and persisted bytes; operations bind task identity or diagnostic data; training completion distinguishes pending, legacy-undated, and dated completion. Completed AFT evaluations derive their fields from a valid result. Views receive a non-optional immutable snapshot from the ready case. | Pending/completed contradiction tests, fixed-result validation, cancelled-recovery state preservation, domain construction, and live UI checks. Store reads outside ready state throw rather than trap or invent empty data. |

## Directive Review

| AGENTS.md Directive | Result and Evidence |
| --- | --- |
| 1. Visible, contained, typed, recoverable failures | Pass in reviewed paths: typed expected failures, visible failed/pending states, owned recovery controls. |
| 2. Strict boundaries | Pass: DTO decoding and draft parsing establish domain invariants; filesystem bytes are validated again when read. UI drafts remain explicitly incomplete input, not trusted business values. |
| 3. Illegal states | Pass: immutable domain construction, sealed aggregate evaluation, fixed five-event points, private completion state, and enum-owned task/load state. |
| 4. Optionals | Pass: optional photos/certificates, absent legacy dates, no assignment, no initial persisted file, and no pending journal are genuine absence. Malformed input is an error. |
| 5. Error handling | Pass: input, storage, conflict, cancellation, recovery, and rendering failures have typed paths. Remaining preconditions concern a pure parser returning an undocumented error or a guarded complete-evaluation branch losing an event; they do not handle ordinary input failure. |
| 6. Provenance | Pass: primary and secondary errors remain available separately from display text. Bootstrap's stored Result also retains its cause. |
| 7. Recovery ownership | Pass: repository classifies authoritative storage outcome; UI owns reload, explicit cleanup retry, replacement/removal, cancellation, and presentation. |
| 8. Concurrency | Pass in reviewed paths: actor-owned persistence, main-actor UI state, Sendable values, explicitly concurrent import work, actor-isolated task cleanup, no detached tasks or unchecked Sendable conformance. |
| 9. Containment and recoverability | Pass for the defined single-writer/process-interruption contract below. File availability failures stay in the media operation rather than blocking unrelated calculator work. Physical power-loss durability is not claimed. |
| 10. Runtime invariants | Pass: authoritative factories validate domain values, repository validates cross-record references and conflicts, and protected internal construction exposes trusted snapshots. |
| 11. Pipeline | Pass: raw DTO/draft → parse/factory → immutable domain → typed mutation/outcome → owning recovery boundary. |
| 12. Pattern matrix | Pass in reviewed production code. No meaningful `try?`, fallible-operation `try!`, erased error strings, detached tasks, unchecked Sendable, or loose service payloads remain. The required UIKit delegate dictionary is adapted at its perimeter. |

## Boundary and Ownership Inventory

- **Persistence:** [BookRepository.swift](../LeadersBook/Core/BookRepository.swift) decodes concrete DTOs and constructs [Soldier.swift](../LeadersBook/Core/Soldier.swift), [RecordAttachment.swift](../LeadersBook/Core/RecordAttachment.swift), and [Fitness.swift](../LeadersBook/Core/Fitness.swift) domain values. Unknown schema/table versions and invalid records preserve the file and stop loading.
- **Editing:** `SoldierDraft`, `TrainingDraft`, and `FitnessDraft` explicitly allow incomplete user entry. Drafts must pass the construction boundary before committed records or scoring logic receive them. Calculator drafts intentionally retain invalid performance text, with explicit field errors; profile structure and selected identities remain constrained.
- **Scoring:** table shape, points, metadata, age labels, and required events are checked at table construction. Core scoring receives `EventPerformance` and `AgeBand`. Completed persisted results must match all five computed points and their known table version.
- **Media:** imported files have immutable validated metadata and a bounded format envelope. Portraits additionally pass the platform image decoder; Quick Look owns full document rendering. `RecordFileImport` handles security-scoped access at the Files boundary. Missing metadata is an error, not a guessed size of zero.
- **UI:** [LeaderStore.swift](../LeadersBook/Core/LeaderStore.swift) owns UI state and app-lifetime mutation tasks. [AppFailure.swift](../LeadersBook/Core/AppFailure.swift) owns cancellable UI operations. Imports and certificate preview are presentation-owned and cancel on dismissal/replacement. Root views pass validated snapshots to descendants, avoiding unavailable-store reads during a reload.
- **UIKit:** the camera dictionary stays inside the delegate adapter and immediately becomes a typed captured/cancelled/failed outcome. No raw dictionary enters a service.

## Persistence and Retry Contract

1. One `BookRepository` actor is the app session's filesystem authority. The app's windows share that store. This is not a cross-process database or a filesystem locking protocol for arbitrary external writers.
2. A mutation compares the current serialized file with its known persisted bytes before writing. External changes or disappearance of a known dataset produce a conflict/read error; they do not silently reset the book. First open of a nonexistent dataset is explicitly permitted absence.
3. Soldier edits carry the revision from their editing snapshot. The repository issues a fresh revision and timestamp on commit. Stale editors cannot overwrite newer records; legacy files without revisions acquire in-memory revisions and persist them on a later successful mutation without changing record IDs or historical dates.
4. Before writing new attachment files, the repository atomically writes `pending-transaction.json`, including the intended new and removed file references. Imported bytes are not written when an editor is cancelled.
5. Attachment files are written before the atomic root-record write. `lastTransaction` on the root file identifies a confirmed commit. If an I/O call reports failure, the repository rereads and validates the authoritative file before deciding between committed success, rollback, and unknown outcome. Unknown outcome preserves the journal/files and exposes failure; it never guesses that imported files are safe to delete.
6. Committed records can coexist with cleanup pending. The journal and diagnostic causes survive cleanup failure. The UI says cleanup remains pending and offers an explicit retry; it does not invite a duplicate save of an already committed result. A confirmed commit after a reported storage error also retains a visible storage warning.
7. Recovery only deletes journal candidates that are unreferenced by the authoritative snapshot. Equivalent shared references remain valid, and a file remains until its final owner is removed. Missing files during idempotent deletion mean the desired cleanup is already satisfied; other deletion errors remain failures.
8. Startup performs one contracted journal-recovery attempt. The user can explicitly request cleanup retry or reload. These operations are idempotent. There is no arbitrary failure retry loop. Recovery uses the storage contract's authoritative root marker and applies to process interruption; no broader physical-media/power-loss guarantee is asserted.
9. Save intents are not automatically retried. A repeated result UUID is rejected as a conflict; the UI also prevents a second active save. Deletes allow already-absent identities as an explicit idempotent outcome. Calculator autosave coalesces user edits through an owned, cancellable debounce; failure remains visible and input remains a draft.
10. JSON and attachment writes use complete iOS file protection. Referenced media may become unavailable later; a failed media read is visible in that component and does not block unrelated calculator saves.

## Verification

The original 15 core tests retain their meaningful coverage. Assertions changed only for authorized typed-error, async, and state contracts; nil-return expectations became explicit error expectations, and save/edit tests now use committed revisions. New tests cover malformed persisted domains, result identity, true legacy compatibility, shared files, filesystem failures, cancellation provenance, stale completion protection, and restart recovery.

Commands:

```sh
swift test --scratch-path /private/tmp/leaders-book-remediation --filter FitnessTests
swift test --scratch-path /private/tmp/leaders-book-remediation --filter 'GovernanceTests|AttachmentTests|RecoveryTests'
swift test --scratch-path /private/tmp/leaders-book-remediation
xcodebuild -project LeadersBook.xcodeproj -scheme LeadersBook \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /private/tmp/leaders-book-governance-build \
  CODE_SIGNING_ALLOWED=NO build
```

Native UI validation uses the existing `LeadersBookUITests` target with an iOS 27 simulator. An initial delete UI test exposed a confirmation payload disappearing during dismissal; the action now receives its typed `presenting` value, and the test waits for commit acknowledgement before terminating the app. That test and the photo/training workflow then passed in a clean simulator. AFT history and HT/WT draft/relaunch checks also passed after the async refactor.

Final combined test, UI-target, and Release results are recorded in [VALIDATION.md](../VALIDATION.md). Temporary logs and xcresult paths there make the scope of each claim explicit. Earlier compiler/test failures were diagnosed before changes: actor-isolated deinitialization, a shadowed metadata variable, nested error-wrapper assertions, and the typed confirmation-message closure. No failing test was disabled or weakened.

## Baseline Retained for Context

Before remediation, the audit result was **Fail**, with F1–F6 open. The synthetic probe reported:

```text
reloadAcceptedEmptyName=true
reloadAcceptedAgeBand999=true
single500PointEventMeetsStandard=true
malformedAndAbsentInputBothNil=true
```

`GovernanceTests.maliciousPersistenceIsRejectedAndPreserved` now rejects the first three representations without rewriting them. `incompleteAndMalformedInputHaveDistinctTypedErrors` proves that missing and malformed input are distinct errors. The old temporary probe is not reused as a certification tool because its old API no longer exists.

## Limits

- Code review and tests address the six findings; they do not constitute formal verification or exhaustive crash injection at every I/O instruction.
- Recovery tests exercise actual files, permissions, and persisted interrupted-transaction fixtures, not a mocked repository. Whole-process termination at every possible instruction and physical power-loss durability are not tested.
- Xcode 27.0 / Swift 6.4 is installed. Xcode 27.2+, physical signing, locked-device data-protection behavior, camera hardware, Duo folding/reserved-region transitions, and complete VoiceOver coverage remain separate device/toolchain checks.
- Existing iOS 27 simulator `Invalid frame dimension` keyboard warnings occur in pre-remediation logs as well. They are reported separately; no unrelated layout assertions or tests were changed to hide them.
- There is no automated architectural linter that can certify these semantic requirements. Pattern search is a discovery aid, followed by source review and the listed boundary tests.

## Theme Adoption — November 3, 2026

The approved theme change adds immutable Foundation-only RGB/role values to the core and a UI-isolated SwiftUI/UIKit adapter to the app. It introduces no persistence or calculator domain changes and no dependencies. The adapter resolves interface style and accessibility contrast; actions read the enabled environment rather than assigning a fixed color to disabled controls. Native system dialogs, swipe actions, and toolbar controls retain platform ownership.

[Theme Validation](THEME-VALIDATION.md) records the contrast matrix, actual-target adapter tests, rendered evidence, release-gate command, diagnosed build/test setup failures, and remaining platform/UI limits. The expanded matrix passes in standard and increased contrast, and all 35 core tests pass. This is a scoped presentation review, not a new certification of every application boundary or all accessibility behavior. Existing F1–F6 persistence/error/concurrency contracts remain unchanged.

November 4 follow-up: selection-aware action styling is now validated by 16 native rendered configurations. The empty-image failure was contained to the test host; a scene-attached visible window with a bounded asynchronous render wait fixed capture without weakening color/contrast assertions. All three adapter tests and the unsigned Release build passed. Before/after PNGs, alpha counts, trait metadata, and logs are preserved under `docs/validation/theme`; the theme report distinguishes tested outcomes from unisolated fixture causes. No persistence or domain boundary changed.

## Status Roles — November 4, 2026

The approved status implementation adds `statusSuccess`, `statusWarning`, and `statusFailure` palette roles, using contrast-tested colors and their increased-contrast variants. All 12 new role/surface requirements are explicit: three roles on canvas, surface, raised surface, and alternating rows. The matrix now has 42 requirements × two appearances × two contrast settings = 168 combinations; the original 30 requirements remain.

`LBStatusLabel` always presents distinct symbols plus explicit text. It reads SwiftUI's `accessibilityDifferentiateWithoutColor`: when enabled, status text becomes neutral and semibold while retaining the symbols and words. Selected rows always use `textOnSelected`. This also prevents status colors from introducing a new contrast failure on selection. [Apple's setting contract](https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilitydifferentiatewithoutcolor) requires information beyond color; icons/text are available even when the preference is off.

Today, soldier rows, pending/completed training, current AFT summaries, calculator events, and saved AFT results use the new cues. Pending training distinguishes overdue dates, future/today deadlines, and untracked deadlines. Existing `TrainingItem.isOverdue(on:)` remains authoritative: completed items and untracked deadlines are never overdue; a deadline today is not overdue.

`EventPoints` owns the 60-point minimum and event shortfall. `AFTResult` exposes typed failed events and the total shortfall; the overall pass calculation uses those same values. The calculator and saved-result summary identify each failing event by name, score, and deficit. A total below the selected standard is explained separately. Existing reference scoring tables and persistence representations are unchanged.

Validation: 37 core tests passed. Focused tests cover 0/59/60/100 event boundaries, a failing event despite a passing total, and a combat result with all five events at 60 but a 50-point total shortfall. Native checks cover overdue date boundaries and both Differentiate Without Color/selection policy branches. The actual UI workflow produces a 400/500 total with a failed deadlift and asserts the visible explanation. The native adapter resolves all 23 roles across 8 trait combinations (184 resolutions). The unsigned physical-device Release build passed.

Durable evidence: [status validation directory](validation/status/), including raw logs, Xcode summaries, SHA-256 manifest, and the [rendered AFT failure](validation/status/native-attachments/FBF9E3C4-E010-433E-AAC4-8A2443F565D6.png). The native run completed 6 tests with 0 failures and 0 skips; Xcode's optional 600-second simulator diagnostic collector was interrupted after the tests passed, allowing the successful result bundle to finalize. No assertions or tests were removed or weakened. A separate targeted symbol test checks that all three SF Symbols exist on iOS.

Commands: `swift test --scratch-path /private/tmp/leaders-status-core --filter 'FitnessTests|ThemeContrastTests'`, then the full same core target; `xcodebuild -project LeadersBook.xcodeproj -scheme LeadersBook -destination 'platform=iOS Simulator,id=042F1B65-E9EF-413F-B09B-9B6E3F191ABC' -derivedDataPath /private/tmp/leaders-theme-adopted-build -only-testing:ThemeAdapterTests -only-testing:LeadersBookUITests/LeadersBookUITests/testAFTEventFailureExplanation CODE_SIGNING_ALLOWED=NO test`; final Release uses `-configuration Release -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/leaders-theme-release-final CODE_SIGNING_ALLOWED=NO build`.

Limits: Differentiate Without Color policy branches are tested, but toggling the OS setting end to end on hardware and a full VoiceOver pass remain unverified. This validation does not close existing Duo folding/reserved-region or automatic hardware appearance checks. Regular-width Fitness layout and HT/WT Cancel confirmation remain separate follow-ups.

AFT wording/color refinement: overall results now say “Meets Standard” or “Does Not Meet Standard”; event rows say “Go” at 60–100 and “No Go” below 60. Failure summaries retain the event name and point deficit. Success now uses explicit green (`#245C35` light / `#9ED5A8` dark; increased contrast `#163D22` / `#C0E8C7`); failures retain the tested red role. Differentiate Without Color and selected-row contrast overrides remain active. Fresh evidence is preserved under `docs/validation/status/go-no-go/`.

## Privacy and Duo Audit — November 4, 2026

[Privacy, data controls, accessibility, and Duo audit](PRIVACY-HIG-AUDIT.md) records the new P1–P9 findings. The summary/detail authentication boundary is missing; backup policy and presentation privacy are incomplete; no tracking implementation was found within static scope. These are additional findings, not a reopening of the earlier six data-integrity fixes. No application code changed during the audit.

## Authentication Implementation — Partial Verification

The approved authentication work adds a fail-closed store boundary, revocable storage permits, a system LocalAuthentication adapter, aggregate-only locked UI, and a window privacy shield. All 41 core tests and the unsigned Release build pass, but the denied-authentication alert test failed twice consecutively. Implementation changes stopped under the circuit breaker. The feature is **not marked complete**. See [Authentication Findings and All File Diffs](AUTHENTICATION-FINDINGS.md) for the exact failure, test-double isolation, remaining verification, and per-file patches.

## Authentication Review Follow-Up

Read-only evidence showed no alert in the failed capture/hierarchy; a focused core assertion confirmed failure publication and the locked state. A single root presenter now owns operation/draft alerts and derives titles from failure operations. The unchanged denial-alert assertion passes. Presentation-triggered summary loading is guarded at the shared store; two concurrent presenters and later unlocked presentations do not reload the editing session. The themed window cover passes color, inactive-attachment, and active/resign notification checks. Archive action remains Release, and a Testing archive is actively rejected by a build phase. See [Authentication Findings and All File Diffs](AUTHENTICATION-FINDINGS.md) for final results and policy/device limits.

Final authentication review validation: **43 core tests and all 14 native tests passed**, with no skips or weakened assertions. The Release build passed; explicit Testing archive validation was rejected by the intended build guard. The findings report now includes all 22 edited source/test/configuration/documentation files and regenerated individual/combined diffs. Real-device authentication and full privacy-surface verification remain separate acceptance checks; immediate background locking and unsaved-editor discard remain the stated policy.

Presenter review follow-up: the retained 16-configuration action render test passes. Two pending failure sources are presented sequentially and verified through binding and UI tests. All nine selected native tests pass, and a normal unsigned Release archive succeeds; Testing archive rejection remains in force. No additional view with stacked alert modifiers was found. Immediate background/manual/device-lock relocking with unsaved-editor discard remains the explicit policy. See the authentication findings addendum for coverage limits and commit-baseline provenance.
