# App Store Release Audit — November 5, 2026

**Decision: not yet demonstrated ready for submission.** One confirmed in-app policy defect and two incomplete release gates are identified below. No P0 defect was reproduced. This is an audit, not a change to application code or an App Review decision.

Scope: current working tree on `mothra/protected-soldier-edits`, including uncommitted corrections beyond baseline `9e97fca`; a fresh unsigned Release archive; source/configuration/privacy scans; retained 47-core/17-full-native results; and current Apple documentation. App Store Connect, signed export/upload validation, physical-device execution, and external resource availability were not tested. The source hashes and archive evidence are retained in [the audit evidence directory](validation/app-store-audit-2026-11-05/).

The requested [Medium article](https://medium.com/programming-with-pierre/discussing-best-practices-for-ios-app-development-1e4ffbe8e320) timed out on two retrieval attempts. The supplied summary was assessed against the code and Apple’s rules; no claim is made to have verified that Medium copy line by line. The earlier same-author DEV article provides general engineering context, not release authority.

## Priority Meaning

P0 = verified catastrophic stop-ship defect; P1 = mandatory policy correction or incomplete submission gate; P2 = conditional rejection/submission risk needing evidence; P3 = important engineering/product backlog; P4 = maintainability improvement; P5 = informational. Apple does not define this severity scale. A low-priority recommendation is not automatically a release blocker.

## Direct Blockers and Required Gates

| ID | Priority / Classification | Evidence | Exit Criterion |
| --- | --- | --- | --- |
| R1 | **P1 — confirmed code/policy blocker** | No privacy-policy URL or accessible policy link exists in the app UI. `LockedRecordsView.swift:7` offers only unlock; `GuidesView.swift:109` offers Army resource links. A privacy manifest is not a privacy policy. Apple 5.1.1(i) requires accessible in-app and metadata policy links. | Publish the real policy and expose it from the locked screen and normal UI; configure its App Store Connect URL. Explain actual local storage, backup possibilities, imported files, sharing, retention/deletion, and protected-draft lifetime. |
| R2 | **P1 — incomplete distribution gate, not a source-code signing defect** | Fresh archive succeeds, but `SigningIdentity` and `Team` are empty because validation used `CODE_SIGNING_ALLOWED=NO`. No signed App Store export or successful App Store Connect validation is available in the reviewed evidence. | Use the correct registered bundle/app record and team to distribute/sign through Xcode, then validate/upload successfully. An unsigned archive can be an intermediate artifact; it is not proof of upload readiness. |
| R3 | **P1 — incomplete device-validation gate, not a demonstrated auth bug** | No physical iOS device is connected. Real Release Face ID/passcode, cancellation/fallback/no-passcode, protected-data locking, and system-presenter privacy have no device results. Testing substitutes the external authenticator. Apple 2.1(a) calls for on-device testing before submission. | Test a signed production build on representative devices; document system authentication, camera/import/preview, background recovery, and stability. Provide accurate review instructions for local device authentication; there is no app account requiring demo credentials. |

Sources for the mandatory gates: [App Review Guidelines 5.1.1 and 2.1](https://developer.apple.com/app-store/review/guidelines/), [Apple distribution workflow](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

## P2 Conditional Submission Risks

| ID | Finding | What Is Known / What Must Be Verified |
| --- | --- | --- |
| R4 | App Store Connect metadata is outside the reviewed scope | Privacy answers, age questionnaire, support/policy URLs, review notes, territories, and exported-build processing must be complete. They were not inspected, so this audit does not assert that they are absent. Missing required metadata would block submission. [Apple privacy details](https://developer.apple.com/app-store/app-privacy-details/). |
| R5 | Privacy wording/policy needs reconciliation | `SoldierEditor.swift:75` says records stay on the device, but repository backup exclusion is absent. Clarify app-local storage versus system/provider backups and exported copies. Backup exclusion is not itself a universal App Store requirement, and this audit does not accept the associated risks for the owner. Resolve this within R1’s policy work. |
| R6 | Internal demos must not be mistaken for store assets or verified Duo support | The GIF is a labeled compact simulator walkthrough with Testing authentication; iPad captures are expanded-layout previews. No submitted listing was available. If used for distribution, prepare supported store media and accurate device/functionality descriptions. Do not claim unverified Duo behavior or accessibility support. [Metadata guidance](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata). |

## P0 and P3–P5: No Additional Direct Blocker Established

- **P0:** no reproduced launch crash, authentication bypass in Release, destructive migration, credential disclosure, or malicious behavior found in this pass. This is a bounded finding, not proof such defects cannot exist.
- **P3:** pre-auth repository reads/recovery, closed-window draft lifetime, sharing/retention decisions, real scene transitions, and expanded accessibility/privacy-surface coverage remain product/security work. Their existence alone does not demonstrate an App Store rule violation. A reproduced leak or crash would change severity.
- **P4:** mixed formatting, dense closures, lack of hosted CI/lint configuration, and missing Instruments evidence affect maintainability/release confidence. Apple does not require SwiftLint, GitFlow, RxSwift, or Fastlane by name. No new tooling was installed.
- **P5:** the minimum iOS 27 deployment target restricts the audience but is not inherently invalid. Uncommitted changes affect reproducibility, not App Store eligibility; this audit fingerprints the actual working tree.

## Confirmed Positives and Ruled-Out Suspicions

- Fresh `xcodebuild ... -configuration Release ... CODE_SIGNING_ALLOWED=NO archive` passed. Face ID/camera purpose strings are present. Release strings contain no test authenticator, denial/simultaneous-error flags, or forced-preview flags. Testing remains a separate configuration and its archive guard has retained negative evidence.
- The source AppIcon PNG reports an alpha channel, but both compiled 1024×1024 icon renditions are `Opaque=true`; the generated 120×120 icon PNG has no alpha. This is **not a confirmed icon rejection**. Final upload validation remains authoritative. [Apple icon configuration](https://developer.apple.com/documentation/xcode/configuring-your-app-icon).
- Xcode 27.0/iOS 27 SDK exceed the currently published minimum of Xcode 26/iOS 26 SDK. Xcode 27.2 is a project/device-testing objective, not a current universal upload minimum. [Apple requirements](https://developer.apple.com/news/upcoming-requirements/).
- Privacy manifest syntax passes. No app-owned networking/ads/analytics SDK or IDFA access was found. Local-only processing is not automatically “collection” for Apple’s privacy labels; declaring no collected data is not disproved merely by storing local records. This does not replace accurate disclosures or runtime review. [Apple definitions](https://developer.apple.com/app-store/app-privacy-details/).
- Typed domain parsing, actor-owned persistence, journal recovery, auth leases, cancellation, real-filesystem tests, and native controls are positive engineering evidence. The retained full native result is 17 passing tests; no fresh functional suite was run for this documentation-only pass.

## Applying the Supplied Checklist Correctly

- No public UGC/chat service, account creation, backend, or IAP exists in the reviewed source. Community moderation, account deletion, backend/demo-account availability, and StoreKit setup are not missing implementations for those absent features. Local notes/imported certificates do not create a public moderation service.
- The “only active code” formulation is too broad: unused helpers are not automatically hidden features. The controlled test paths are excluded from Release; production functionality must still match review disclosures.
- Purchase/link rules have storefront-specific exceptions; “exclusively IAP unless entitled” is not universally accurate. No payment implementation needs remediation here. Rival-platform metadata language also has qualified exceptions; no submitted metadata was inspected. [Current rules](https://developer.apple.com/app-store/review/guidelines/).
- Native controls and symbols help accessibility, but do not certify VoiceOver, Dynamic Type, contrast, or material bars. Existing component tests are not full accessibility conformance. Rank artwork can remain appropriate custom imagery.
- Current `@Observable`, async/await, actors, and narrow UIKit callbacks are reasonable choices. Reactive streams do not remove state or cancellation obligations. A small feature-branch workflow and measured profiling are preferable to adding frameworks merely to satisfy a generic checklist.

## Dated Content-Descriptor Correction

Apple announced Shared Location and Dating/Relationships descriptors on November 2, 2026. They become available November 16, 2026; declarations are required with applicable submissions/questionnaire changes, and all apps must complete them by January 12, 2027. They are **upcoming as of this audit**, not a current November 5 rejection. This app has neither capability in source; answer the questionnaire accurately rather than omitting it. [Apple announcement](https://developer.apple.com/news/?id=yxkh08us).

## Release Decision

First close R1, then produce signed/exported/validated distribution evidence for R2 and signed-device results for R3. Verify the conditional metadata items R4–R6 in the actual App Store Connect record. Do not turn P3–P5 engineering preferences into invented rejection rules, or claim the closed-source/store-side checks passed without evidence. No policy, signing, backup, or sharing settings were changed by this audit.
