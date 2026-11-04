# The Leaders Book: iPhone Duo readiness review

Reviewed November 2, 2026 from `/Users/godzilla/Documents/Projects/The Leaders Book App.zip`.

Verdict: this is an interactive web prototype, not yet a working iOS leader-book app. The archive contains Next.js/React and Figma-managed Payload code, but no Xcode project, Swift source, or iOS application target.

## Findings, ordered by impact

1. **P1 — No installable iOS application.** `package.json` supplies web development and deployment scripts only. An iOS target, app lifecycle, assets, signing configuration, persistence, and device validation are required before this can be delivered as an iPhone app.

2. **P1 — The core roster cannot manage records.** `src/app/(frontend)/soldier-roster.tsx:5–16` contains three fixed fictional records. There is no create, edit, delete, or save flow. `page.tsx:129` explicitly says records are disabled. `src/payload.config.ts:38` registers only Admins, Media, Folders, and Tags. The CMS link does not provide a soldier-record backend or app-user authentication. A working release needs a deliberate local storage or authenticated shared storage design, with access protection appropriate to the records collected.

3. **P1 — The exported build depends on its Figma environment.** `src/payload.config.ts:14` uses `buildFigmaConfig`. The production build fails locally with `Environment ID could not be resolved. Set FIGMA_EID or initialize the project.` This establishes a portability blocker for this export; it does not prove the original hosted Figma app is broken.

4. **P1 — Duo adaptation is simulated with CSS.** `page.tsx:144–157` draws a fixed 9:41 clock and status artwork. `styles.css:296–316` fixes the rail to the right. This does not implement system-controlled bar movement, fold/camera reserved regions, or the left-side control placement required for the left app in Split View. The side rail itself is consistent with Duo guidance; the missing system adaptation is the issue. Use native navigation, tab, toolbar, sheet, and menu components, with an adaptive content hierarchy.

5. **P2 — Leaving Fitness discards entered results.** `page.tsx:130` conditionally mounts FitnessTools. All event values and measurements live in its component state (`fitness-tools.tsx:16–21`). Navigating to Soldiers or Guides and returning creates a new instance with empty inputs. Preserve unfinished work above destination views, and persist saved results if result history is part of the release.

6. **P2 — Body Ratio opens the wrong tool initially.** The Body Ratio shortcut targets only Calculators (`page.tsx:29`). FitnessTools always initializes its carousel on AFT (`fitness-tools.tsx:62–65`, `sliding-pages.tsx:10`). A fresh Body Ratio action therefore requires another selection to reach the requested calculator. Pass an explicit destination selection.

7. **P2 — Resources selection never becomes selected.** `page.tsx:94–98` rewrites Army resources to Knowledge base. Its resource toolbar button tests `active === 'Army resources'` at line 151, a state that this navigation does not enter. Preserve a consistent destination/selection model even if resources are embedded in Guides.

8. **P2 — Text size and preferences are app-only and temporary.** `page.tsx:87–88` stores layout and three text-size choices in component state. This is not system Dynamic Type integration and resets on reload. Native text styles should track accessibility settings; verify largest accessibility sizes, VoiceOver order, keyboard avoidance, contrast, and Reduce Motion on device.

9. **P2 — Production build can ignore type errors.** `next.config.ts:37–39` sets `typescript.ignoreBuildErrors: true`. The independent typecheck passed for this snapshot, but this setting could allow future type regressions into a web deployment. Make type validation an explicit release gate.

## What is already implemented

- Search filters the included guide summaries and overview shortcuts.
- Guide carousel has keyboard navigation and swipe handling.
- AFT scoring uses bundled threshold tables, input parsing, and event/total outputs.
- Waist-to-height math validates positive finite measurements.
- Dialogs have labels and cancel handling; several controls provide accessible names.

These are source-level observations, not confirmation of complete device behavior. Current Army scoring policy and the full scoring table were not independently validated. The UI itself identifies the 0.55 ratio threshold as an unverified reference.

## Validation and limits

- PASS: `node node_modules/typescript/bin/tsc --noEmit`.
- PASS: seven direct Node assertions covering valid/invalid time parsing, fractional deadlift rejection, a maximum-score lookup, a below-minimum result, ratio math, and zero-height rejection.
- No existing automated test suite or test script was found in the archive.
- BLOCKED: `pnpm build`. The environment's pnpm launcher automatically restored the archive's locked dependencies, then stopped on `ERR_PNPM_IGNORED_BUILDS` for esbuild. No dependencies were added to the project manifest.
- BLOCKED: direct `node node_modules/payload/bin.js build`, missing Figma environment ID as detailed above.
- BLOCKED: default Next dev preview, Turbopack `unable to start FSEvent stream`.
- BLOCKED: webpack preview, watcher errors followed by localhost HTTP timeout. The browser could not load the app, so no screenshots or visual UX audit are claimed.
- BLOCKED: `xcrun simctl list devices available`, CoreSimulatorService unavailable in this execution context. Xcode reports version 27.0.
- No app source was changed. The ZIP was extracted under `/private/tmp/leaders-book-review` for inspection.

## Recommended implementation scope

Build a native SwiftUI iOS app using this export as a content and visual reference. Keep the existing destinations: Today, Soldiers, Guides, Troop Leading, Fitness, and Resources. Start with durable local records and protected local storage; add shared accounts or sync only if explicitly required. Implement soldier creation/editing, persistent calculator drafts, saved fitness results, and local guide content. Use system navigation and toolbar components, adaptive compact/regular layouts, and reserved-region APIs where custom content requires them.

Acceptance checks: build an iOS target; create/edit/delete a fictional soldier and verify persistence after relaunch; retain calculator input across destinations; validate scoring against authoritative fixtures; open Body Ratio directly; maintain destination selection and drafts across display transitions; exercise outer/inner displays, partial folds, portrait, and Split View; verify VoiceOver and accessibility text sizes. Device checks remain required even after a successful simulator build.

This native conversion necessarily exceeds the user's three-file/100-line approval threshold. Implementation requires explicit scope approval before source edits.

## Apple references

- [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo): adaptive displays, state continuity, reserved regions, system vertical controls, portrait and Split View exceptions.
- [Layout](https://developer.apple.com/design/human-interface-guidelines/layout): safe areas, adaptable hierarchy, and text sizing.
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/): release completeness and minimum functionality. This review does not predict App Store acceptance.
