# Authentication Implementation Findings

Reviewed November 4, 2026. **Current validation: 47 core tests and all 17 current native tests passed.** The unfiltered native rerun covers the expanded suite. Earlier 14-, 9-, and 10-test runs are historical scopes identified below. These are simulator/application-level results; hardware authentication and privacy-surface checks remain unverified.

## Implemented Boundary

- Normal Debug/Release use LocalAuthentication `deviceOwnerAuthentication` with device biometrics and system device-passcode fallback. No app PIN, biometric template, or successful authentication grant is persisted.
- The locked UI exposes aggregate counts only. Names, photos, notes, measurements, certificates, saved-result details, edits, and all data-bearing tabs require authentication. Restored navigation does not bypass the gate.
- The app store boundary checks detail/attachment/mutation access. Actor-queued writes and attachment reads use a synchronously revocable lease; admitted atomic transactions may finish, but stale completions cannot republish unlocked state.
- Manual lock, app background, and protected-data-unavailable notifications revoke access, clear the public detailed state/draft, and cancel owned work. Authentication request identities reject stale successful callbacks. The session is shared across windows.
- The privacy shield is window-level and opaque while inactive; lock transitions dismiss presented controllers. Its fill now resolves `privacyCover`, matching the SwiftUI cover. Scene activity updates as well as UIKit notifications prevent an inactive attachment from leaving it stuck visible.

## Review Findings and Resolution

| Finding | Evidence and Outcome |
| --- | --- |
| Missing authentication error alert | The preserved screenshot showed no alert; the hierarchy had zero alert nodes. The added core assertion proved `operationFailure` was non-nil with the expected operation/cause while state stayed locked. Two root alert modifiers were merged into one enum-driven presenter. The original native assertion now passes. Presentation changes resolved the failure; no assertion was weakened. |
| Failure title depended on lock state | Titles now derive from the failure source/operation. Unlock failures say “Records Remain Locked”; Load Summary failures are identified as summary-load failures; draft failures retain their own title. |
| Presentation-triggered reload | `prepareForPresentation()` consumes the initial locked/unloaded request once at the shared store. Tests exercise concurrent presenters and later appearances while unlocked, verifying generation and draft preservation. These are shared-model tests, not two physical window scenes. |
| Cover differed from theme / initial inactivity | Native tests verify exact cover colors in light/dark, opaque alpha, initial inactive attachment, activation, and resign/active notifications. The cover is an accessibility modal while visible. |
| Testing archive risk | Archive action is checked as Release. A build phase actively rejects a Testing archive, including an explicit command-line configuration override. Negative archive validation produced the intended guard error and no archive Info.plist. |
| Earlier operation-failure coverage | No earlier native UI test asserted the root operation-failure alert. Previous successful functional runs did not establish alert presentation coverage. |

## Background and Draft Policy

**Immediate relocking is the policy. Soldier editor drafts are retained in protected process memory and restored after successful unlock. All other editors discard unsaved state on lock.** The in-memory calculator draft is cleared and pending autosave cancelled; committed data is preserved. No grace period is used.

Locked summary loading remains count-only at the UI/service output, but loads the private repository and can run existing journal recovery before authentication. The repository retains decrypted data internally; this is not an application-managed encrypted vault or a guarantee of memory erasure. Previously returned values cannot be retroactively revoked; future service calls are blocked and protected UI is removed.

## Verification and Durable Evidence

| Check | Result | Evidence |
| --- | --- | --- |
| Denial-state diagnostic before presentation edits | PASS; expected failure and locked state asserted | [diagnostic log](validation/authentication/review/denial-diagnostic.log) |
| Authentication baseline core suite | PASS: 43 tests | [core log](validation/authentication/review/core.log) |
| Authentication baseline native suite | PASS: 14 tests, zero failures/skips | [summary](validation/authentication/review/native-summary.json), [log](validation/authentication/review/native.log) |
| Native coverage | Six adapter/accessibility/cover tests plus eight UI workflows: denial/relock/background, CRUD/relaunch, photo/training, calculators/history, standard/accessibility previews | [attachments](validation/authentication/review/attachments/manifest.json) |
| Release build | PASS; unsigned physical-device compilation | [log](validation/authentication/review/release.log) |
| Release isolation / Face ID purpose string | PASS; no test authenticator/denial flag in strings; purpose string present | [inspection](validation/authentication/review/release-isolation.txt) |
| Testing archive rejection | PASS: expected `Testing authentication cannot be archived` error | [negative-check log](validation/authentication/review/archive-rejection.log) |

### Run Scope and Counts

| Run | Scope | Count / Result | Evidence |
| --- | --- | --- | --- |
| Authentication core baseline | Full core | 43 passed | `validation/authentication/review/core.log` |
| Authentication native baseline | Full native suite at that revision | 14 passed | `validation/authentication/review/native-summary.json` |
| Presenter follow-up | Filtered via `-only-testing` | 9 passed | `validation/authentication/presenter-review/summary.json` |
| Protected-edit core | Full core | 47 passed | `validation/protected-edits/core.log` |
| Protected-edit native | Filtered via `-only-testing` | 10 passed | `validation/protected-edits/native-summary.json` |
| Current corrections verification | Full current native suite; no `-only-testing` filters | 17 passed; 0 failed/skipped | [summary](validation/corrections/full-native-summary.json), [log](validation/corrections/full-native.log) |

The previous stopped run and its exact failing command remain in [initial partial findings](validation/authentication/review/initial-partial-findings.txt) and the original evidence directory. The read-only diagnostic and focused core test preceded presentation edits. There were no test skips or removed assertions.

Reproduce normal native validation with `xcodebuild -project LeadersBook.xcodeproj -scheme LeadersBook -destination 'platform=iOS Simulator,id=042F1B65-E9EF-413F-B09B-9B6E3F191ABC' -derivedDataPath /private/tmp/leaders-auth-build -collect-test-diagnostics never CODE_SIGNING_ALLOWED=NO test`. Core validation: `swift test --scratch-path /private/tmp/leaders-auth-core`. Release: use `-configuration Release -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/leaders-auth-release CODE_SIGNING_ALLOWED=NO build`.

## Configuration and Remaining Device Checks

The separate **Testing** configuration substitutes only the external OS authenticator. Real store/repository/filesystem gates and UI remain under test. Normal Debug and Release use the real system adapter. The normal Run action is Debug, Archive is Release, and Testing archives are rejected. A test-double success does not establish successful real biometric/passcode interaction.

Remaining checks include nested child/parent alert routes. Hardware Face ID/passcode cancellation/fallback/no-passcode cases, protected-data lock behavior, actual multi-window transitions, Quick Look/camera/editor app-switcher snapshots, full VoiceOver privacy, and Duo poses/reserved regions. The cover's native component test does not establish every system-controller capture path. Detailed manual presenter checks and hardware availability are recorded separately in [hardware evidence](validation/hardware/evidence-2026-11-04.json). Backup, sharing, retention, and organizational authorization findings remain open in the privacy audit.

## Every Edited File and Its Diff

### Patch Provenance

| Patch set | Comparison baseline |
| --- | --- |
| `validation/authentication/authentication.patch` and its per-file patches | Pre-authentication session-start snapshot, captured while the project was untracked; historical, not Git HEAD |
| `validation/authentication/review/initial-partial.patch` | Same session-start snapshot; historical stopped implementation |
| `validation/protected-edits/protected-edits.patch` and its per-file patches | Committed baseline `9e97fca` to the protected-edit working tree, including later documentation corrections |

Generated logs, screenshots, summaries, and patches are evidence artifacts. Commit `9e97fca` established the repository baseline; the two patch sets intentionally have different provenance.

[Complete unified patch](validation/authentication/authentication.patch)

## Presenter and Baseline Review Addendum

- The original `testActionStyleUsesRowSelectionForRenderedLabel` was **fixed and retained**, not replaced by a role-choice test. It still renders the real style with a scene-attached window across 16 selected/enabled/appearance/contrast combinations, asserting exact RGBA and selected-label contrast. It passed again in the latest [native log](validation/authentication/presenter-review/native.log).
- Two failures from different sources are retained in their existing source slots. Operation failure has priority; the draft failure remains pending until the operation is acknowledged, then appears. Both the binding-level test and actual UI test pass this sequence. This is one slot per source, not a general FIFO for arbitrarily many failures.
- Positive archive validation passed with `xcodebuild -project LeadersBook.xcodeproj -scheme LeadersBook -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/leaders-auth-release -archivePath /private/tmp/leaders-auth-release-positive.xcarchive CODE_SIGNING_ALLOWED=NO archive`. [Archive log](validation/authentication/presenter-review/release-archive.log) and [properties/hash](validation/authentication/presenter-review/archive-summary.json) preserve evidence. This is an unsigned archive, not signing/distribution approval.
- Alert scan: ContentView, FitnessView, SoldiersView, SoldierEditor, SoldierPhotoPicker, TrainingRecordEditor, and HeightWeightEditor each own one alert. The two alerts in TrainingRecordEditor.swift belong to separate view types. No additional stacked modifiers on one view were found.
- Latest broader validation passed **nine native tests**: seven adapter/presenter/cover tests and two UI workflows. See the run table for full versus filtered coverage; this was a filtered run, not a full-suite claim. The simultaneous-error fixture exists only in Testing; its flag is absent from the Release archive.
- The Background and Draft Policy section is the single current policy statement.
- The Patch Provenance table defines each patch baseline.

| File | Diff |
| --- | --- |
| `LeadersBook/App/DeviceAuthenticator.swift` | [Unified diff](validation/authentication/patches/LeadersBook__App__DeviceAuthenticator.swift.diff) |
| `LeadersBook/App/LeadersBookApp.swift` | [Unified diff](validation/authentication/patches/LeadersBook__App__LeadersBookApp.swift.diff) |
| `LeadersBook/Core/BookRepository.swift` | [Unified diff](validation/authentication/patches/LeadersBook__Core__BookRepository.swift.diff) |
| `LeadersBook/Core/LeaderStore.swift` | [Unified diff](validation/authentication/patches/LeadersBook__Core__LeaderStore.swift.diff) |
| `LeadersBook/Core/RecordAccess.swift` | [Unified diff](validation/authentication/patches/LeadersBook__Core__RecordAccess.swift.diff) |
| `LeadersBook/Views/ContentView.swift` | [Unified diff](validation/authentication/patches/LeadersBook__Views__ContentView.swift.diff) |
| `LeadersBook/Views/LockedRecordsView.swift` | [Unified diff](validation/authentication/patches/LeadersBook__Views__LockedRecordsView.swift.diff) |
| `LeadersBook/Views/PrivacyShield.swift` | [Unified diff](validation/authentication/patches/LeadersBook__Views__PrivacyShield.swift.diff) |
| `LeadersBook/Views/SoldiersView.swift` | [Unified diff](validation/authentication/patches/LeadersBook__Views__SoldiersView.swift.diff) |
| `LeadersBook.xcodeproj/project.pbxproj` | [Unified diff](validation/authentication/patches/LeadersBook.xcodeproj__project.pbxproj.diff) |
| `LeadersBook.xcodeproj/xcshareddata/xcschemes/LeadersBook.xcscheme` | [Unified diff](validation/authentication/patches/LeadersBook.xcodeproj__xcshareddata__xcschemes__LeadersBook.xcscheme.diff) |
| `Tests/LeadersBookCoreTests/AttachmentTests.swift` | [Unified diff](validation/authentication/patches/Tests__LeadersBookCoreTests__AttachmentTests.swift.diff) |
| `Tests/LeadersBookCoreTests/GovernanceTests.swift` | [Unified diff](validation/authentication/patches/Tests__LeadersBookCoreTests__GovernanceTests.swift.diff) |
| `Tests/LeadersBookCoreTests/LeaderStoreTests.swift` | [Unified diff](validation/authentication/patches/Tests__LeadersBookCoreTests__LeaderStoreTests.swift.diff) |
| `Tests/LeadersBookCoreTests/RecordAccessTests.swift` | [Unified diff](validation/authentication/patches/Tests__LeadersBookCoreTests__RecordAccessTests.swift.diff) |
| `Tests/LeadersBookCoreTests/RecoveryTests.swift` | [Unified diff](validation/authentication/patches/Tests__LeadersBookCoreTests__RecoveryTests.swift.diff) |
| `Tests/LeadersBookCoreTests/TestSupport.swift` | [Unified diff](validation/authentication/patches/Tests__LeadersBookCoreTests__TestSupport.swift.diff) |
| `Tests/LeadersBookUITests/LeadersBookUITests.swift` | [Unified diff](validation/authentication/patches/Tests__LeadersBookUITests__LeadersBookUITests.swift.diff) |
| `Tests/ThemeAdapterTests/ThemeAdapterTests.swift` | [Unified diff](validation/authentication/patches/Tests__ThemeAdapterTests__ThemeAdapterTests.swift.diff) |
| `docs/ARCHITECTURE-AUDIT.md` | [Unified diff](validation/authentication/patches/docs__ARCHITECTURE-AUDIT.md.diff) |
| `docs/AUTHENTICATION-FINDINGS.md` | [Unified diff](validation/authentication/patches/docs__AUTHENTICATION-FINDINGS.md.diff) |
| `docs/PRIVACY-HIG-AUDIT.md` | [Unified diff](validation/authentication/patches/docs__PRIVACY-HIG-AUDIT.md.diff) |

## Protected Soldier Edits — Approved Update

Immediate manual/background/device locking is unchanged. `LeaderStore` privately retains one process-only editing session per window, including the original revision/baseline, incomplete form fields, checklist values, notes, and accepted pending photo bytes. Drafts are not encoded into records, UserDefaults, SceneStorage, or a draft file. This is access-controlled application memory, not cryptographic RAM protection, debugger resistance, or guaranteed secure erasure. App termination or memory-pressure termination loses the buffer.

Bindings synchronously checkpoint into the protected buffer before updating local form state, including the final keystroke. Reads, updates, save, and discard require authenticated access. A lock revokes the lease immediately; a successful unlock refreshes the retained session's lease and automatically reopens the editor for that window. Failed unlocks cannot expose the draft. Old callbacks/dismissals cannot mutate or discard the restored session through revoked handles.

Save and explicit discard clear the session; clean sessions are dropped on lock. Pending transfers are cancelled by the existing operation owners; photo bytes already accepted by the form are retained. A save failure keeps the edits. Original revisions cannot be replaced, stale saves conflict, and the repository now rejects recreation of an existing-revision record that another window deleted. Already-admitted atomic saves may finish across a lock; restored edits can then conflict instead of overwriting or duplicating committed data.

The per-window key is root-view State, not persisted identity metadata. A closed window's retained buffer can remain until process termination; this implementation adds no expiration or encrypted draft persistence. The separate Training Record and HT/WT editors are outside this Soldier-editor retention scope.

### Validation

- **47 core tests passed**, including four protected-edit tests: failed unlock retention; no disk writes/revoked access/photo bytes/process-restart absence; independent windows/save/discard; stale revision, forged revision, and deletion conflict.
- **10 filtered native adapter/UI checks passed**, covering the restored Soldier editor plus existing CRUD and photo/training workflows. The UI test backgrounds immediately after typing notes, unlocks, verifies restored values, saves, and separately verifies Discard prevents later restoration.
- **Release build and release gate passed.** The gate now runs the entire core suite, including the new security/draft tests, rather than only the contrast selection. Authentication dependency substitution remains confined to Testing.
- [Core log](validation/protected-edits/core.log), [targeted log](validation/protected-edits/targeted.log), [native summary](validation/protected-edits/native-summary.json), [native log](validation/protected-edits/native.log), [Release](validation/protected-edits/release.log), and [gate](validation/protected-edits/release-gate.log) preserve the evidence. No assertion or test was weakened, removed, or skipped.
- Compile correction during iteration: throwing `restoreSoldierEdit` calls inside `#require` required their own `try`; application behavior was not changed to accommodate a failing assertion. Hardware authentication/privacy-surface, actual multi-window, and Duo verification remain open.

Reproduce with `swift test --scratch-path /private/tmp/leaders-edit-core --filter SoldierEditTests`, then the broader core suite; native selection uses `-only-testing:ThemeAdapterTests` plus `LeadersBookUITests/LeadersBookUITests/testSoldierEditsRestoreAfterUnlockAndClearAfterSaveOrDiscard`, `LeadersBookUITests/LeadersBookUITests/testSoldierCreationEditingRelaunchAndDeletion`, and `LeadersBookUITests/LeadersBookUITests/testPhotoTrainingAndHeightWeightWorkflow`. The approval covered 8–12 source/config/test/document files and 350–550 added lines. The patch baseline is defined in Patch Provenance; the working branch is `mothra/protected-soldier-edits`.

## Coding-Practices Review

Reviewed [Pierre Janineh's article](https://dev.to/pierrejanineh/discussing-best-practices-for-ios-app-development-56ln) as guidance, not project instructions.

| Theme | Assessment of This App |
| --- | --- |
| Native UI | SwiftUI navigation, forms, pickers, system authentication, and SF Symbols align. Army rank assets remain appropriate domain artwork. Native controls still need accessibility/device testing. |
| Coding style | Descriptive types, typed errors, validated domains, actor isolation, and value semantics are strengths. Dense closures and inconsistent test indentation remain readability debt. |
| Version control | A committed baseline and feature branch now support reproducible diffs. Peer review and hosted branch checks remain process gaps. |
| Tooling | Core/native tests, archive isolation, a Release gate, and durable evidence exist. Hosted CI, signing/distribution automation, and Instruments memory/performance profiling remain unverified. |
| Observables | `@Observable`, bindings, and async/await fit this app. Native delegate/callback boundaries remain useful; adding RxSwift solely to replace them is unwarranted. |

Reactive abstractions do not remove state, cancellation, or race obligations. The explicit leases and session identities remain necessary. [Apple's Observation guidance](https://developer.apple.com/documentation/swiftui/migrating-from-the-observable-object-protocol-to-the-observable-macro) supports the current data-flow approach. No linter, analytics SDK, reactive library, or CI service was installed during this review.

### Protected-Edit File Diffs

The protected-edit patch set is defined in Patch Provenance; generated evidence is indexed by its manifest.




| Protected-Edit File | Git Diff |
| --- | --- |
| `LeadersBook.xcodeproj/project.pbxproj` | [Unified diff](validation/protected-edits/patches/LeadersBook.xcodeproj__project.pbxproj.diff) |
| `LeadersBook/Core/BookRepository.swift` | [Unified diff](validation/protected-edits/patches/LeadersBook__Core__BookRepository.swift.diff) |
| `LeadersBook/Core/LeaderStore.swift` | [Unified diff](validation/protected-edits/patches/LeadersBook__Core__LeaderStore.swift.diff) |
| `LeadersBook/Core/SoldierEditSession.swift` | [Unified diff](validation/protected-edits/patches/LeadersBook__Core__SoldierEditSession.swift.diff) |
| `LeadersBook/Views/ContentView.swift` | [Unified diff](validation/protected-edits/patches/LeadersBook__Views__ContentView.swift.diff) |
| `LeadersBook/Views/SoldierEditor.swift` | [Unified diff](validation/protected-edits/patches/LeadersBook__Views__SoldierEditor.swift.diff) |
| `LeadersBook/Views/SoldiersView.swift` | [Unified diff](validation/protected-edits/patches/LeadersBook__Views__SoldiersView.swift.diff) |
| `Tests/LeadersBookCoreTests/SoldierEditTests.swift` | [Unified diff](validation/protected-edits/patches/Tests__LeadersBookCoreTests__SoldierEditTests.swift.diff) |
| `Tests/LeadersBookUITests/LeadersBookUITests.swift` | [Unified diff](validation/protected-edits/patches/Tests__LeadersBookUITests__LeadersBookUITests.swift.diff) |
| `docs/ARCHITECTURE-AUDIT.md` | [Unified diff](validation/protected-edits/patches/docs__ARCHITECTURE-AUDIT.md.diff) |
| `docs/AUTHENTICATION-FINDINGS.md` | [Unified diff](validation/protected-edits/patches/docs__AUTHENTICATION-FINDINGS.md.diff) |
| `script/build_and_run.sh` | [Unified diff](validation/protected-edits/patches/script__build_and_run.sh.diff) |

[Complete protected-edit patch](validation/protected-edits/protected-edits.patch) · [Integrity manifest](validation/protected-edits/manifest.json)
