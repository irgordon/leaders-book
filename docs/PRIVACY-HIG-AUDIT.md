# iPhone Duo, Privacy, Data Controls, and Accessibility Audit

Reviewed November 4, 2026. **Overall: Partial; the requested summary/detail privacy boundary is not implemented.** This is a source and retained-rendering audit, not Apple certification, a penetration test, or authorization to store Army-sensitive information. Application code was not changed.

## Evidence and Method

Reviewed the repository/store, import paths, all record presentation routes, privacy manifest, package/project configuration, accessibility/status components, existing test evidence, and retained native screenshots. Fresh checks: privacy plist syntax passes; Xcode is 27.0 (27A266a); no Duo simulator type is installed. [Source hashes and negative-search inventory](validation/privacy-audit/source-inventory.json) preserve the reviewed scope. Existing successful tests are historical evidence; no new functional suite, packet capture, physical-device authentication, backup restore, or VoiceOver session was run during this audit. OS-level app locking and MDM settings were not inspected.

The reviewed [expanded dark record](../Previews/Theme-Expanded-Profile-Dark.png) demonstrates the sidebar/detail layout and readable selection; it predates the latest status wording. [Current status evidence](validation/status/go-no-go/summary.json) and its attachments cover the later Go/No Go presentation. Neither constitutes Duo hardware evidence.

## Findings by Priority

| ID | Priority / Result | Finding and Source | Required Outcome |
| --- | --- | --- | --- |
| P1 | High / Missing | **No Face ID, Touch ID, passcode, or app PIN gate.** No LocalAuthentication usage or Face ID purpose string exists. `SoldiersView.swift:76` opens detail directly; the store loads the full snapshot on launch (`ContentView.swift:40`, `LeaderStore.swift:35`). | Authenticate before exposing details or performing sensitive operations; enforce the boundary beyond one view. This is a gap against the requested product protection, not a claim that Apple mandates biometrics for every app. |
| P2 | High / Missing policy | **“Records stay on this device” overstates the storage guarantee.** Application Support is used and no backup-exclusion policy exists (`LeaderStore.swift:18`, `BookRepository.swift:98`; copy in Today/editor). | Decide and disclose backup/restore policy. Test actual restore behavior and protected files. Do not equate absence of CloudKit sync with absence of system backups. |
| P3 | High / Partial | **Inactive cover is not a security lock.** `ContentView.swift:61–73` overlays a cover and marks privacy sensitivity; it retains loaded records and restores visibility automatically. Sheets/Quick Look are presented separately (`SoldiersView.swift:95–107`). | Cover/dismiss all sensitive presentations and invalidate access on lock/background. Test app-switcher snapshots with editor, camera, certificate preview, and multiple scenes. Presented-surface leakage is a risk requiring reproduction, not a demonstrated exploit. |
| P4 | Medium / Partial | **No explicit data-loss, retention, or full-erasure policy.** Per-soldier/results deletion exists; no reset-all, retention schedule, controlled export, or restore workflow exists. Delete clears a linked draft's soldier ID but retains calculator values (`BookRepository.swift:204–206`). | Define retention and authenticated delete/export policy. Explain that app deletion does not erase original imported files or historical backups; verify journal and orphan cleanup. |
| P5 | Medium / Open | **Outbound copies are not governed.** Notes enable selection/copy (`SoldiersView.swift:173`); Quick Look receives a real file URL; certificate bytes are preserved (`RecordFileImport.swift:23–35`). | Decide permitted clipboard, preview, and sharing behavior. Test Quick Look's actual sharing affordances before claiming restrictions. Review certificate metadata; re-encoding a photo is not evidence of a comprehensive metadata-removal policy. |
| P6 | High verification gap / Not Verified | **Duo-specific compliance is unproven.** Soldiers/Guides use native split views, but actual poses, fold/camera reserved regions, side controls, resizing, and state continuity were never tested on Duo. | Validate with the requested newer Xcode toolchain and Duo simulator/device. Lack of custom ReservedRegion code alone is not a defect: native containers may adapt automatically. |
| P7 | Medium / Partial | **Accessibility coverage is component-level.** Palette, selected styles, icons/text, and rank spacing have evidence; no full VoiceOver, Switch Control, keyboard, touch-target, Reduce Transparency, or largest-type walkthrough exists. | Run end-to-end checks on all editors, pickers, errors, navigation, certificates, and authentication. Include material bars and externally supplied artwork/content. |
| P8 | Medium / Confirmed | **HT/WT Cancel discards typed data without confirmation.** `TrainingRecordEditor.swift:122` dismisses immediately although interactive dismissal is blocked at line 139. | Match the other editors' discard confirmation and preserve drafts on cancellation/auth interruption. |
| P9 | Medium / Partial | **No in-app privacy/settings explanation for access, backup, retention, or tracking.** The manifest is a developer declaration; App Store Connect disclosures and a public privacy policy were not available for review. | Provide accurate user-facing explanations, policy/support links, and distribution disclosures matching the shipped binary. |

## What Is Stored and How

| Data | Location / Representation | Existing Protection and Limits |
| --- | --- | --- |
| Soldier records, notes, training/deadlines/completion dates, HT/WT history, attachment metadata, AFT results, calculator draft | App sandbox `Library/Application Support/LeadersBook/records.json`; Codable JSON (`BookDTO`) | iOS writes request atomic replacement and Complete Data Protection. JSON is not separately encrypted by an application-managed key. It is readable by the app when device access permits. |
| Photos and certificates | Sibling `Attachments/<UUID>.<extension>`; JPEG/PNG/PDF | Same protected write path. Imports are bounded to 10 MB; photos are resized/re-encoded; supported certificates retain original bytes. Original Photos/Files/provider copies remain outside app deletion control. |
| Interrupted transaction metadata | `pending-transaction.json` beside records | Same protected writes. Journal recovery distinguishes committed cleanup from rollback and protects shared referenced files. |
| Selected screen/record | `@SceneStorage` tab index and soldier UUID | UI restoration metadata, not an authentication grant. Restored selection must never bypass future access checks. |
| Loaded records and decoded photos | Store/repository/UI memory | No authenticated lock state or explicit sensitive-memory eviction exists. File protection does not retroactively erase loaded memory. |

`BookRepository.swift:98–105` applies Complete protection to directories and new/replaced files. [Apple documents](https://developer.apple.com/documentation/foundation/fileprotectiontype/complete) encryption at rest and device-lock access restrictions for this protection class. Physical-device behavior, restored/legacy file attributes, and lock/unlock failure recovery remain unverified. Avoid describing the implementation as either “unencrypted files” or an independently encrypted application vault.

**Backup distinction:** there is no app CloudKit/cloud-sync implementation, but system backup may include app data. Apple notes both that app data is backed up and that `isExcludedFromBackup` is guidance, not an absolute guarantee. A strict no-cloud requirement needs an explicit organizational/device-management and key/restore design; simply adding a flag is insufficient. User-created files should not be moved to purgeable caches to evade backups. [Apple backup guidance](https://developer.apple.com/documentation/foundation/optimizing-your-app-s-data-for-icloud-backup).

Positive source findings: actor-owned I/O, validated DTO-to-domain boundaries, atomic root commits plus an attachment journal, conflict/revision checks, surfaced cleanup failures, bounded imports, scoped Files access, and sanitized user-facing errors. Those controls protect consistency; they do not authorize a viewer.

## Does “Do Not Track” Work?

**There is no in-app Do Not Track switch, ATT permission flow, or HTTP DNT mechanism.** Source/package review found no advertising/analytics SDK, IDFA access, app-owned networking client, or tracking code. The privacy manifest declares `NSPrivacyTracking=false`, empty tracking domains, and no collected-data types; it declares the UserDefaults required-reason category. Plist syntax passes, but an aggregated distribution privacy report and App Store disclosures still need review.

This supports a scoped finding of **no tracking implementation found**, not a runtime guarantee that every process stays offline. ATT concerns cross-company tracking; it is not a data-encryption, backup, authentication, or general network-blocking control. An app that does not track should not request ATT merely to advertise a privacy feature. [Apple tracking definition](https://developer.apple.com/app-store/user-privacy-and-data-use/).

Army resource/scoring links open external destinations; those sites and the browser have their own privacy behavior. Photos/Files may use cloud-backed providers. No packet capture or App Privacy Report validation was performed. Verify the signed release binary on hardware through representative offline, import, preview, and link flows before making a broad “no transmission” promise.

## Proposed Summary / Protected Detail Boundary

Recommended implementation: retain a minimal locked summary (prefer aggregate counts; explicitly approve whether names/ranks may be visible). Require system authentication before full records, photos, notes, HT/WT, named AFT history, certificates, edits, imports, exports, or deletion. Today’s last-result card, Fitness history/assignment picker, restored selection, and modal routes must obey the same policy. Summary rows currently contain identity/photo information and are not automatically nonsensitive.

Use `LAContext` with `deviceOwnerAuthentication` for system biometrics and device-passcode fallback; include `NSFaceIDUsageDescription`. This is the device passcode, not a new app PIN. Apple handles fallback and retry delays; cancellation, lockout, unavailable authentication, or no configured passcode must leave details locked. [Apple policy documentation](https://developer.apple.com/documentation/localauthentication/lapolicy/deviceownerauthentication).

Use an explicit locked/authenticating/unlocked session and a minimal summary projection. Check authorization at detail/attachment/mutation boundaries as well as navigation. Handle the authentication prompt's own inactive transition without a lock loop; relock on real background/device lock and invalidate stale authentication completions. Define timeout/manual lock and multi-window behavior. Clear sensitive previews/drafts according to an explicit preservation policy. Test alternate routes and cancellation, not only the happy-path Face ID prompt. Device-owner authentication is not organizational role-based authorization.

A custom app PIN would require a separate threat model, Keychain-backed credential design, retry/lockout policy, recovery, and secure deletion; do not store one in records JSON or UserDefaults. Stronger app-managed encryption, if required, also needs a key recovery/backup policy. These are recommendations; none was implemented during this audit.

## HIG and Accessibility Assessment

Native tabs, navigation stacks/split views, forms, pickers, semantic fonts, and scalable imagery are positive foundations. Apple’s Duo guidance calls for continuity across displays, native vertical controls, and adaptation to reserved regions. Validate selection, scroll, keyboard, drafts, sheets, and lock state while opening/closing and rotating; test Split View and camera activation. Today/Fitness remain single-column layouts: assess readability and opportunity for a wider layout on the actual inner display, rather than declaring a single column categorically noncompliant. [Duo HIG](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo).

Retained tests cover 168 palette combinations and 184 adapter trait resolutions, plus native status/spacing checks. Status uses icon and text; Differentiate Without Color chooses neutral semibold text. These do not certify system-material bars, disabled controls, imported certificates, rank artwork, or every text/background pairing in the app. Retained captures used Debug appearance overrides; automatic dark switching remains a device check. VoiceOver focus/order and modal dismissal, large-type clipping, Reduce Motion/Transparency, and the OS accessibility switches require verification. [Accessibility HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility).

`privacySensitive()` marks content for privacy redaction contexts; it does not itself authenticate, prevent screenshots, or cover every presented controller. The overlay's accessibility-hidden modifier hides the cover itself, not proof that underlying sensitive accessibility content is removed. Test the locked accessibility tree and app-switcher images explicitly. [Apple modifier semantics](https://developer.apple.com/documentation/swiftui/view/privacysensitive(_:)).

## Remediation Order and Release Gates

1. Implement the protected-detail boundary and fail-closed system authentication across every route; validate foreground/background, cancellation, no-passcode, and restored-state behavior.
2. Resolve backup/retention/import-copy/sharing policy, correct “device only” wording, and complete privacy disclosures. Test file protection and backup restore on hardware.
3. Verify modal/app-switcher privacy and accessibility exposure; add appropriate regressions, including auth interruptions and HT/WT discard behavior.
4. Complete Duo pose/reserved-region and full accessibility/device-dark-mode validation on the required toolchain. Record results rather than inferring compliance from iPad screenshots.

The audit does not establish App Store approval, complete WCAG conformance, or Army/DoD/CUI/PII handling authorization. Those have separate distribution, accessibility, and organizational acceptance requirements. [Apple privacy HIG](https://developer.apple.com/design/human-interface-guidelines/privacy).

## Authentication Follow-Up

Authentication controls are now implemented but only partially verified; the native denial-alert test remains failing. P1/P3 are not closed. [Authentication Findings and All File Diffs](AUTHENTICATION-FINDINGS.md) supersedes the earlier implementation-status statements for authentication only. Backup, sharing, device/OS verification, and other audit findings remain open.

Authentication review update: the denial-alert assertion now passes after merging root presenters. The earlier failure is retained as historical evidence; consult [current findings](AUTHENTICATION-FINDINGS.md) for app-level validation and outstanding hardware/privacy-surface checks. Immediate background relocking remains the implemented policy; a grace period or unsaved-editor restoration has not been introduced.
