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
- **Media:** imported files have immutable validated metadata and a bounded format envelope. Portraits additionally pass the platform image decoder. The original Quick Look presenter was replaced by the read-only certificate viewer in the November 5 privacy correction: PDFKit parses/extracts text, and Core Graphics draws pages; its accessibility trade-offs remain open. `RecordFileImport` handles security-scoped access at the Files boundary. Missing metadata is an error, not a guessed size of zero.
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

Protected Soldier edit policy update: locks remain immediate, while incomplete Soldier form state and pending photo bytes are retained in an authenticated, revocable process-memory buffer and restored after unlock. Other forms retain their prior policy. All 47 core tests, ten selected native checks, and the release gate/Release build passed. Original revisions and deleted-record conflicts prevent stale restoration from overwriting newer state. [Updated findings, coding-practices review, and Git-based file diffs](AUTHENTICATION-FINDINGS.md) document scope and limits.

Correction policy clarification: immediate locking remains required. Soldier editor drafts are retained in protected process memory; Training Record and HT/WT forms deliberately discard unsaved state on lock. This is the current scope decision, not a claim that all editor types have restoration. The owner subsequently selected system-backup eligibility with disclosure, fresh authentication for export, and one-year retention review with confirmed deletion; the November 5 section records implementation. Hardware results are recorded separately from simulator evidence; see the findings report’s run/provenance tables.

## App Store Release Audit — November 5, 2026

[Current P0–P5 release audit](APP-STORE-RELEASE-AUDIT-2026-11-05.md) identifies the absent in-app privacy-policy link and separates incomplete signed-distribution/device-validation gates from conditional metadata risks and nonblocking engineering backlog. Fresh unsigned Release archiving passes; compiled icons are opaque and test-only flags are absent. The Medium page could not be fetched; the supplied summary was checked against current Apple sources. No application code changed in this audit.


## Privacy-Control Corrections — November 5, 2026

The approved boundary changes defer all private repository opening/recovery until successful unlock, revoke stale export authorization, and clean up per-scene protected Soldier drafts on real scene disconnect. Export data is an enum of trusted notes or validated certificate files. Presentation owns cancellation and user-facing failures; the store owns authorization and the repository retains transactional deletion/cleanup. No new dependency or persistent schema was introduced.

Owner policy: keep system backup eligibility and disclose retained-copy risk; require fresh authentication before notes/certificate export; warn one calendar year after the Soldier record’s last saved update and delete only after explicit confirmation. Soldier editor drafts survive immediate lock in access-controlled process memory; Training Record and HT/WT drafts deliberately do not. Calendar-unavailable retention dates become a visible review state. In-app disclosure does not supply the still-missing published policy URL or App Store Connect metadata.

[Current findings, exact commands, evidence and all edited-file diffs](AUTHENTICATION-FINDINGS.md#november-5--approved-privacy-control-corrections) distinguish real-filesystem core checks, native simulator checks and unavailable hardware checks. Two actual simulator UIWindowScenes now verify disconnect cleanup; physical-device multi-window editing is not inferred. Signed distribution, real authentication/protected-data behavior, provider snapshot routes, certificate accessibility and Duo-specific layout remain unverified.

Fresh validation: **50 core tests, all 20 native tests, and one separate real-scene simulator test passed**. The unsigned Release archive passed and excludes test-authentication/preview flags. Authorization/data-lifecycle corrections pass the exercised boundaries; overall privacy/HIG/release compliance remains **Partial** pending the explicit hardware, provider-route and distribution checks above.


## Coding-Practices Detail Review — November 6, 2026

Scope: source/configuration inspection and re-reading the November 5 evidence. No application code changed and no build/test/profiling was re-run. Earlier 50-core/20-native results remain dated evidence. This documentation-only update touches one tracked file and stays below 100 added lines.

| Theme | Refined Assessment | Acceptance Evidence Still Needed |
| --- | --- | --- |
| Native UI | Partial. SwiftUI navigation and system authentication are appropriate. `PrivacyControls.swift:56` customizes UITextView editing and `:90` implements custom PDF/image presentation; system frameworks do not establish complete accessibility for those controls. | Physical authentication, VoiceOver reading/focus, accessible zoom/navigation, scanned-certificate fallback, Dynamic Type/material bars and actual Duo layouts. |
| Coding style | Partial. `AppFailure.swift:35` preserves originating errors, and `:59` models operation phases with owned task identity. Dense statements in `PrivacyControls.swift:125` and indentation in `ThemeAdapterTests.swift:12` make boundary review harder. | Small, behavior-preserving readability changes with unchanged targeted assertions; adopt formatting rules deliberately rather than a repository-wide rewrite. |
| Version control | Partial. Local baseline `9e97fca` and feature branch exist. Current source/test changes and new files remain uncommitted; `git remote -v` returns no configured remote. Evidence patches fingerprint the newer tree, but HEAD alone does not reproduce it. | Reviewed checkpoint of the current tree; remote/provider configuration and independently verified required checks/review before claiming hosted protection. |
| Tooling | Partial. Existing tests and archive safeguards are useful; the release script's `--validate` branch runs core plus ThemeAdapterTests and an unsigned Release build, omitting LeadersBookUITests (`script/build_and_run.sh:32`). | Include the 11 UI workflows in a release gate. Keep fast filtered iteration checks separate. Signed export/upload and measured performance still need evidence. |
| Observation/concurrency | Appropriate design in the inspected paths. `LeaderStore.swift:11` owns UI state; repository is an actor. `OwnedOperation` owns UI tasks, cancellation and request identity. Lease/epoch checks after suspension protect authorization freshness. | Continue lock-during-await, cancellation, stale-completion and scene-disconnect tests. Observation does not itself enforce these contracts. |

### Newly Explicit Findings

- **P2, observed runtime diagnostics:** the full native result is Passed with 20 tests and zero failures/skips, but contains four “Invalid frame dimension (negative or non-finite)” warnings. See [summary](validation/privacy-controls/full-native-summary.json) and [log](validation/privacy-controls/full-native.log), lines 896, 1135, 1829 and 2506. They occur in AFT saving/history, AFT event failure, photo/training/HT-WT and ratio/relaunch tests. The responsible view and user-visible impact are not established. Preserve those tests and inspect warning stacks/layout geometry before changing code; do not silence warnings or guess the culprit.
- **P2, release-process coverage:** local `--validate` can pass without running any LeadersBookUITests. The separate full run supplies historical UI evidence but does not close this script gap. Exit: the release command actually executes and fails on failures in core, adapter and UI targets.
- **P3, reproducibility/process:** current work is beyond the single committed baseline and has no configured remote. Exit: reproducible reviewed commit plus provider-side evidence for any claimed hosted protection. No Git mutation or external publication was performed.
- **P3, readability:** use normal indentation and separate multi-step statements in directly touched auth/import/preview code. Preserve parsing, cancellation and recovery ownership; avoid speculative abstractions or broad formatting churn. Swift's API Design Guidelines prioritize clarity over brevity: https://www.swift.org/documentation/api-design-guidelines/.
- **Not Verified, profiling:** PDF parsing/page-text extraction and image decoding occur in the preview task; that is a workload to measure, not a demonstrated hang. Profile representative documents/large photos, roster scrolling, repeated preview/edit/lock/unlock and scene closure with synthetic records. Inspect Time Profiler, hangs and retained allocations before deciding whether to move work or change retention.

Discovery commands: `git status --short`; `git log -3 --oneline`; `git remote -v`; `rg --files --hidden -g '!.git/**' -g '!build/**' -g '!docs/validation/**' -g '*yml' -g '*yaml' -g '*swiftlint*' -g '*swiftformat*' -g '*Fastfile*'`; numbered source reads; inspection of `validation/privacy-controls/full-native-summary.json` and `full-native.log`. No matching lint/CI/Fastlane configuration was found in the searched repository scope. Hosted provider settings were not accessible through this repository inspection; absence here does not establish account-wide absence.

Apple's Observation guidance supports property-driven SwiftUI updates, while the app remains responsible for domain validation and authorization: https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro. Retain delegates for UIKit editing and LocalAuthentication callbacks where appropriate; adding a reactive library has no demonstrated benefit for this task.

Overall assessment remains **Partial**, with no new P0/P1 application defect established by this limited review. The runtime warnings and omitted UI release checks deserve investigation before cosmetic cleanup. [This review's documentation diff](validation/coding-practices-review-2026-11-06/architecture-audit.diff) compares against the November 5 audit text. Earlier evidence manifests remain historical snapshots and were not regenerated.


## Release-Review Follow-Up — November 6, 2026

Checkpoint first: `6ba0176` records the application/tests and `3da6f45` records existing audits/evidence before new gate changes. No remote is configured. Connected-repository discovery found no matching Leaders Book destination; the remote URL is requested. No repository was created or published. Source relocation is not performed; the active Documents path is retained and build products remain outside Documents. A source-directory move needs a chosen destination and workspace handoff; this review does not establish whether Documents is synced.

### Gate and Diagnostic Results

The `--validate` branch now uses Testing and the scheme's complete native test selection, followed by the independent Release build. Testing substitutes only the external authenticator; Release still uses LocalAuthentication. Fast iteration continues through `swift test --filter` or `xcodebuild -only-testing`; the release command omits those filters. **Fresh gate PASS:** 50 core tests, all 20 native tests (9 adapter/component and 11 UI workflows, zero failures/skips), then unsigned Release build. The four pre-existing native invalid-frame warnings remain explicit diagnostics. [Gate log](validation/release-review-2026-11-06/release-gate.log) and [native summary](validation/release-review-2026-11-06/gate-native-summary.json) preserve the results.

Warnings are pre-existing: the November 3 theme log already records them, and fresh baseline `9e97fca` runs reproduce the diagnostic in AFT, photo/training/HT-WT and ratio workflows. AFT and ratio pass; the first photo run was interrupted when diagnostic runners overlapped on a simulator, and its isolated retry fails on duplicate `PVT Jordan Morgan` buttons from retained synthetic fixtures. Those runs are not counted as a full baseline pass; the current gate's photo workflow passes. No baseline assertion was edited to accommodate this failure.

Matched AFT experiment: source `6ba0176`, same simulator DCD3DC92-18FE-4B88-AF4F-A37178C2848C and unchanged workflow assertions. Moving only the Done toolbar group's placement from `.keyboard` to `.topBarTrailing` passes with zero invalid-frame warnings; restoring `.keyboard` passes with one warning. This supports the keyboard-accessory hypothesis for that workflow, without proving the internal framework cause or every warning's origin. Production layout is unchanged. These are disposable source copies, not a theme/authentication fix or a completed historical bisect.

### Private Notes and Export Control Rationale — Deployment Context Pending

Assets are private Soldier notes/certificates and retained edits. The scoped objective is to prevent implicit app-provided transfers of notes/certificates to the clipboard, drag destinations, Writing Tools or sharing services without a deliberate fresh-authenticated export. It is not a guarantee against an authorized device owner copying visible information, screenshots, recording, mirroring, a compromised OS, imported originals, backups or already-exported copies. Deployment/device-management assumptions have been requested; this is a preliminary control rationale, not a finalized organizational threat assessment.

- `DeviceAuthenticator.authenticateForExport` creates a new LAContext; `LeaderStore.authenticateExport` checks readiness, request identity, cancellation and epoch after suspension. The returned original lease is checked before export and again after certificate reading. `RecordExportSheet` receives typed notes or certificate bytes. No app-created export file is used; the OS/recipient can retain an authorized copy.
- `AuthenticatedExportButton` owns its task, disables duplicate actions and clears its presented payload on disappearance. Existing tests verify denied export, successful notes Copy, fresh authentication per store export, and stale completion after lock. Physical prompts, certificate destinations and cancellation during provider transfer remain unverified.
- `ProtectedNotesTextView` disables copy/cut commands, text drag and Writing Tools, but those restrictions are only app-route controls. VoiceOver/keyboard editing still need device testing. Current `SoldiersView` notes are nonselectable; the sole remaining `.textSelection(.enabled)` is public guide paragraphs in `GuidesView.swift:65`. That exception follows data sensitivity; it is not an unchecked private-note copy route.
- Quick Look was replaced to remove implicit sharing/selection/link routes that bypass the explicit export action. The viewer still parses PDFs with PDFKit, so it does not remove the PDF decoder attack surface. Page-level text labels and pinch zoom do not establish equivalent PDFView/Quick Look accessibility. Large/many-page PDFs and eager text extraction merit profiling.
- PDFView is a candidate for a narrowly scoped prototype. Public headers expose responder copy/selection and URL/remote-action delegate hooks, but `PDFDocument.allowsCopying` is readonly document permission metadata, not an application policy switch. A replacement must demonstrate that copy, drag, link actions and share menus remain gated while VoiceOver/zoom/navigation improve; no such prototype or replacement was made here. [PDFView](https://developer.apple.com/documentation/pdfkit/pdfview), [link delegate](https://developer.apple.com/documentation/pdfkit/pdfviewdelegate/pdfviewwillclick%28onlink%3Awith%3A%29).

Organizational authorization for real Soldier data remains an unresolved deployment decision for an authorized owner; local authentication and App Store acceptance cannot grant that authorization. Backup eligibility and fresh-auth export are the owner's selected application policies, not evidence that an organization permits them.

The installed `xcrun swift-format` was inspected without installing anything. Strict lint of `PrivacyControls.swift` reports 230 formatting diagnostics; adding a blocking check now would fail the existing baseline. Formatting that sensitive file and agreeing a formatting baseline should precede enforcement; no broad reformat or new dependency/configuration was introduced.

[Source bundle for review](validation/release-review-2026-11-06/privacy-export-review.zip) contains nine relevant app/test files from `6ba0176` and their hashes. [Commands and diagnostic caveats](validation/release-review-2026-11-06/commands.txt), gate/diagnostic logs, result summaries and [all current edited-file diffs](validation/release-review-2026-11-06/follow-up.patch) are retained alongside it. Historical evidence manifests remain dated snapshots.
