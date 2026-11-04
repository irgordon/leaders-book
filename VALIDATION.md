# Native app validation

## Theme Evidence — November 3, 2026

This section records the later theme validation; earlier sections remain historical. Durable generated evidence is in [docs/validation/theme](docs/validation/theme/), with SHA-256 integrity metadata in `manifest.json`.

| Check | Result | Retained Evidence |
| --- | --- | --- |
| Contrast matrix | 30 requirements × 2 appearances × 2 contrast settings = 120 passing checks | `coverage.log`, `core.log` |
| Full core target | 35 tests passed | `core.log` |
| Native adapter and compact accessibility/preview checks | 4 passed, 0 failed | `compact-checks.json` |
| Expanded accessibility/preview checks | 2 passed, 0 failed | `expanded-checks.json` |
| Soldier CRUD, photo/training, AFT, HT/WT workflows | 4 passed, 0 failed | `functional-ui.json`, `functional-ui.log` |
| Explicit light/dark captures | Both capture runs passed | `compact-capture.json`, `expanded-capture.json` |
| Release gate | Contrast tests, adapter tests, unsigned Release build passed | `release-gate.log` |
| Final Release confirmation | Build passed; preview flag literals absent from executable | `release.log`, `release-flags.txt` |

The prior 36 count was 18 requirements × 2 appearances; all remain in the current 30-requirement matrix. Exact selected, alternating-row, disabled, and privacy coverage is documented in [Theme Validation](docs/THEME-VALIDATION.md). Accent text on the selected fill is unsupported; selected labels use `textOnSelected` instead.

The [four labeled screenshots](Previews/README.md#new-theme--compact-and-expanded-previews) are retained in the repo. System navigation/tab materials and unselected foregrounds are outside palette certification; the report includes a bar-state screenshot checklist. Captures use Debug-only SwiftUI appearance overrides after headless automatic switching failed to update rendering. Automatic dark-mode transitions on hardware, Xcode 27.2+, and actual Duo widths, folds, and reserved regions remain unverified.

Verified November 2, 2026. Host: Xcode 27.0, Swift 6.4, iOS 27 SDK. No third-party libraries were added.

## Rank Spacing Correction

Replaced the identity card’s `Label` icon layout with a full-height rank row below the name. The gap and insignia dimensions scale with Dynamic Type; names wrap vertically without intersecting the emblem. No screen-coordinate offsets or fixed screen bounds are used. Four UI runs passed: normal and accessibility text sizes on compact iPhone and expanded iPad layouts, asserting a visible name-to-rank gap. The physical-device Release build also passed. Updated [normal header detail](Previews/Rank-Spacing-Detail.png), [compact accessibility screenshot](Previews/Compact-Accessibility-Rank.png), and [expanded accessibility screenshot](Previews/Expanded-Accessibility-Rank.png) are preserved with the refreshed preview gallery.

## Rank, Label, and Preview Corrections

- Replaced abbreviation badges with sourced Army insignia in both roster rows and soldier records. PV2, PFC, CPL, SPC, SGT, and SSG use original Wikimedia SVGs; the remaining ranks use Wikimedia's standard 500-pixel PNG renderings of the corresponding source SVGs after the original-file endpoint returned HTTP 429. The server's 600-second retry interval was respected. Sources, formats, and public-domain license declarations are listed in [Rank Insignia Credits](RANK-INSIGNIA.md).
- Verified senior enlisted distinctions against the source descriptions and artwork: MSG without a diamond, 1SG with a diamond, SGM with a star, and CSM with the command insignia. PVT / E-1 displays no invented insignia.
- Renamed the visible tool and Today shortcut to **HT/WT Calculator**. The persisted enum raw value remains `Waist / height`, preserving existing saved calculator drafts.
- Corrected system navigation links and certificate actions to Title Case. Legacy personal fitness entries display as **Personal Result** without rewriting their saved data.
- New preview captures use separate clean simulators, five ranks (PFC, SPC, CPL, SGT, PV2), clean fictional first/last names, and generic drawn person placeholders. Existing user-selected photos and records were not replaced or removed.
- `testRankAndPlaceholderPreviews` passed on the clean iPhone 18 Pro and iPad Pro 11-inch simulators. The compact test selects rank before opening the keyboard, avoiding the observed test scroll position beneath the modal toolbar.
- `testRatioShortcutCalculationAndRelaunch` passed using the renamed HT/WT Calculator shortcut. Clean-name photo/training/relaunch and soldier edit/delete regression tests both passed in `/private/tmp/leaders-clean-name-regression`.
- The corrected preview gallery supersedes earlier captures containing UUID suffixes and stock portraits. See [Compact and Expanded Previews](Previews/README.md).
- Final checks passed: all **15 core tests**, the Title Case AFT history UI test (`/private/tmp/leaders-title-case-aft`), and the final unsigned device Release build (`/private/tmp/leaders-book-rank-final-release.log`). Targeted UI runs cover the corrected roster, HT/WT Calculator, clean-name CRUD, photo/training persistence, and saved AFT navigation.

## Photo and Training Record Update

- **15 core tests passed** with `swift test --scratch-path /private/tmp/leaders-book-update-tests`. Four new tests cover loading the previous JSON schema, attachment/date/measurement persistence, attachment deletion, failed-commit rollback, invalid input, and missing files.
- **All four iPhone UI tests passed** in `/private/tmp/leaders-book-update-all-ui`. The new workflow imports the supplied stock portrait through the real system Photos picker, saves HT/WT measurements and two dated training records, and verifies them after relaunch.
- The extended workflow additionally saved a 500-point AFT assigned to the new soldier and verified that the linked score appeared on that soldier’s record after relaunch. This passed on **iPhone 18 Pro** (`/private/tmp/leaders-book-final-compact`) and **iPad Pro 11-inch** (`/private/tmp/leaders-book-expanded-final-verified`). The iPad test scrolls back to Save after its assignment picker dismisses.
- The final unsigned physical-device Release build passed using `-derivedDataPath /private/tmp/leaders-book-update-device`. The generated Info.plist includes a camera usage description, and the asset catalog compiles all 23 rank-abbreviation SVG badges.
- Photo/certificate metadata are optional additions to the existing schema. No legacy completion date is invented. File writes are protected and atomic; a failed record commit removes newly written attachments and preserves previous attachments. Cancellation leaves pending imports in memory only.
- JPEG and PNG certificates preserve original bytes and resolution. Other supported certificate images convert to full-resolution JPEG. PDFs are stored unchanged. Import size is limited to 10 MB.
- **Camera capture requires physical-device validation.** The code handles unavailable camera hardware and denied permission. Photos picker import was exercised end to end; Files importer and Quick Look certificate preview are implemented and compiled, but their system UI paths were not exercised by the automated UI tests.
- Labeled [Compact and Expanded Previews](Previews/README.md) contain actual simulator captures, including the front cover (Today), open record, and alternating completed-training rows. They do not claim Duo folding or hardware verification.
- Automatic approval review rejected removal of an empty, superseded generated badge folder. It was preserved at `/private/tmp/leaders-book-unused-empty-rank-badge` outside the asset catalog; no requested functionality remains blocked.

The sections below record the original native-app baseline validation.

## Passed

- `swift test --scratch-path /private/tmp/leaders-book-native-tests`: **11 tests passed** (5 scoring and parsing tests, 6 persistence and model tests).
- `./script/build_and_run.sh --build`: iOS Simulator app build succeeded. Subsequent UI-test builds compiled the final UI sources for iPhone and iPad.
- Final `SIMULATOR_UDID=632C8D1F-2FCB-472B-97A6-604AB9FB0262 ./script/build_and_run.sh`: rebuilt, installed, and launched the finished app successfully in headless CoreSimulator after clearing this session's fictional test data.
- `xcodebuild -project LeadersBook.xcodeproj -scheme LeadersBook -configuration Release -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/leaders-book-device CODE_SIGNING_ALLOWED=NO build`: final unsigned physical-device Release build succeeded.
- Full `LeadersBookUITests` target on an iPhone 18 Pro / iOS 27 simulator: **3 tests passed**. These exercised soldier creation, editing, relaunch, confirmed deletion; five-event AFT input, a 500-point calculation, saving and reopening history after relaunch; and the ratio shortcut, input, calculation, navigation, and relaunch persistence.
- After adding persistent measurement labels, `-only-testing:LeadersBookUITests/LeadersBookUITests/testRatioShortcutCalculationAndRelaunch` passed again on iPhone. The test also switches units through the real interface to clear its prior draft before entering new measurements.
- `-only-testing:LeadersBookUITests/LeadersBookUITests/testSoldierCreationEditingRelaunchAndDeletion` passed on an iPad Pro 11-inch (M5) / iOS 27 simulator, validating the native sidebar/detail layout and the same real filesystem-backed CRUD flow.
- Independent extraction of the official Army PDF matched **every bundled threshold cell**, including blank cells and repeated page-boundary rows. The PDF's SHA-256 matched the data resource's provenance hash.
- Project and privacy manifest passed `plutil -lint`. JSON resources parsed successfully. The run script passed `bash -n`.

The full iPhone UI run used `/private/tmp/leaders-book-final-ui-results`. Final label and iPad confirmations used `/private/tmp/leaders-book-ratio-final-results` and `/private/tmp/leaders-book-ipad-final-results`. These temporary test bundles are not needed to build the app. Verified screenshots are preserved in `Previews/`.

## Issues found and resolved during development

- Consolidated soldier add/edit sheets and delete confirmation under the stable split-view presenter after real-interface tests exposed nested presentation failures.
- Moved keyboard focus and its single Done toolbar to the Fitness navigation container, resolving missing/duplicate keyboard buttons.
- Kept Height and Waist labels visible after entry; removed reliance on low-contrast status text colors.
- Corrected the test fixture for 330 lb in the 17–21 M|C deadlift column to the official **98 points**. The calculator's threshold logic was already correct; the 99-point cell is blank.
- Updated test locators for iPad's floating tab and sidebar button accessibility types, and made the repeated ratio test setup independent of insertion-caret position. No assertions were disabled or removed to bypass application failures.
- SwiftPM's nested sandbox and workspace extended attributes initially prevented test execution. Tests ran successfully outside the filesystem sandbox using a temporary scratch directory.

## Not verified here

- **Xcode 27.2+:** only Xcode 27.0 is installed. Open and validate with the requested newer toolchain before release.
- **iPhone Duo:** no Duo simulator device type is installed. Its outer/inner display transitions, partially folded poses, camera/fold reserved regions, portrait bar placement, and Split View control placement require a Duo simulator or device.
- Physical-device installation, signing, provisioning, distribution archive, TestFlight, and App Store submission.
- A full VoiceOver pass, largest accessibility text sizes, and complete accessibility conformance. Semantic text, accessible control labels, native layouts, and light/dark colors are implemented, but implementation is not a substitute for those checks.
- Army services' CAC sign-in flows and future policy updates. The app calculates against the explicitly labeled June 2025 tables.

The host lacks Simulator.app, so the app was launched and tested through headless CoreSimulator. Screenshots and XCUITest provided actual rendered UI and interaction evidence.

## Screenshots

- [iPhone calculator with persistent labels](Previews/iPhone-Calculator.png)
- [iPad soldier sidebar and detail](Previews/iPad-Soldiers.png)

The soldier screenshot contains only fictional test-created records. The shipped app starts with an empty roster and does not seed them.

## Governance Remediation — Approved Implementation

The baseline six findings are resolved in code; [docs/ARCHITECTURE-AUDIT.md](docs/ARCHITECTURE-AUDIT.md) now records the implemented boundaries, recovery contract, verification, and remaining platform limits. This is distinct from the earlier documentation-only audit.

- Core checks: final combined target `swift test --scratch-path /private/tmp/leaders-book-remediation` passed **30 tests** across scoring, persistence, attachments, governance, and journal recovery (`/private/tmp/leaders-remediation-final-core.log`). The original behavioral coverage remains, adapted to typed errors and async operations.
- Negative persistence tests reject empty names, age band 999, malformed one-event AFT points, and contradictory training state without rewriting the source file. Input absence and invalid format are distinct typed outcomes.
- Real-filesystem tests cover failed writes, retained primary/secondary causes, failed cleanup under directory permissions, restart rollback/replay, shared reference lifetime, and protection against deleting a referenced file. A missing photo does not block calculator persistence.
- Lifecycle tests cover replacement, cancellation, provider cancellation provenance, stale editor revision conflict, duplicate result intent rejection, and cancelled recovery preserving the previous ready state.
- Focused native tests passed photo/training persistence and confirmed async edit/delete (`/private/tmp/leaders-remediation-ui-clean-2`), then AFT history and HT/WT persistence (`/private/tmp/leaders-remediation-ui-fitness-final`). The confirmation uses its typed presenting payload; the delete test waits for the commit acknowledgement before relaunch.
- Final full native UI target: **6 tests passed** with zero failures (`/private/tmp/leaders-remediation-ui-final`, log `/private/tmp/leaders-remediation-ui-final.log`). This includes clean-name CRUD, photo/training persistence, personal and linked AFT history, HT/WT draft persistence, rank/placeholder previews, and accessibility text-size rank spacing.
- Final unsigned physical-device Release build: **passed** (`/private/tmp/leaders-remediation-release.log`, DerivedData `/private/tmp/leaders-book-governance-build`) with Swift 6 complete strict concurrency. This validates compilation, not signing or on-device execution.
- No external dependency was added, no assertion was weakened to conceal a defect, no test was skipped, and no integration storage boundary was mocked.
- Pre-existing iOS 27 simulator keyboard `Invalid frame dimension` warnings also appear in older pre-remediation xcresult logs. They are kept separate from governance validation and have not been hidden by changing tests.
- Xcode 27.2+, physical device signing/data protection/camera, Duo poses/reserved regions, and complete accessibility certification remain outside this host's available verification.
