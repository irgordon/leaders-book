# Theme Adoption and Validation

Reviewed November 3, 2026. The approved adoption uses the corrected supplied palette from `Theme (1).swift`, with explicit row, selection, privacy, interaction, and accessibility roles. No persistence models, record migration, calculator scoring rules, imported photos, or sourced rank assets changed.

## Implementation

- `LeadersBook/Core/ThemePalette.swift` contains Foundation-only RGB values, roles, luminance, and contrast requirements. The sRGB breakpoint is 0.04045. The existing SwiftPM target discovers this file automatically.
- `LeadersBook/Views/Theme.swift` contains the UIKit/SwiftUI adapter. It resolves appearance and accessibility-contrast traits. Increased contrast strengthens secondary text, action text, danger, and borders; other roles retain their already tested values.
- The scene applies the theme once. Lists/forms hide their system canvas; actual Sections and rows receive row fills and separators. Completed training uses alternating rows. Selected-row colors apply only in regular width. Secondary text within selected rows uses `textOnSelected`, rather than the ordinary secondary color.
- `LBPrimaryButtonStyle` uses opaque pressed and disabled fills. `LBActionButtonStyle` owns enabled/disabled in-content action text and pressed underlining. Toolbar controls and swipe actions retain system styling; their colors are not certified by palette math.
- Empty split-view detail columns receive the canvas explicitly. The privacy cover fills safe areas. Storage banners stack vertically and fill the available width. Portraits and rank icons scale with Dynamic Type.

## Contrast Evidence

The matrix has 30 foreground/background requirements, exercised in two appearances and two accessibility-contrast settings: **120 combinations**. Every comparison uses its unrounded ratio. Normal text requires 4.5:1; meaningful borders/graphics require 3:1. Selected secondary labels intentionally use the same contrasting role as selected primary labels.

The earlier **36** counted 18 requirements across two appearances. All 18 remain; 12 requirements were added, giving 30 requirements, 60 standard-contrast appearance combinations, and 120 combinations with increased contrast. No original pairing was removed.

Exact-pair coverage assertions now require primary/secondary text on both `surface` and `rowAlternate`, `textOnSelected/rowSelected`, `disabledText/disabledFill`, and `textOnPrivacyCover/privacyCover`. Ordinary primary/secondary colors are replaced by `textOnSelected` within selected rows. `accentText/rowSelected` is intentionally unsupported: standard-contrast ratios are only 1.2495:1 light and 1.0927:1 dark; increased contrast maps accent text to the same color as the selected fill (1:1). `LBActionButtonStyle` now inherits selection from `leadersBookRow(selected:)` and automatically uses `textOnSelected`, including for disabled selected actions; disabled actions still receive the native disabled state. This guards the normal styled-action path instead of relying on a documentation convention.

| Standard-Contrast Regression | Ratio | Required |
| --- | --- | --- |
| Dark Danger / Raised Surface | 4.7758:1 | 4.5:1 |
| Light Border / Raised Surface | 3.4735:1 | 3:1 |
| Dark Border / Raised Surface | 3.3404:1 | 3:1 |
| Light Accent Text / Raised Surface | 5.1869:1 | 4.5:1 |
| Dark Accent Text / Raised Surface | 4.9205:1 | 4.5:1 |
| Light Pressed Label / Fill | 8.8353:1 | 4.5:1 |
| Dark Pressed Label / Fill | 5.9734:1 | 4.5:1 |

The five core theme test definitions retain the supplied black/white reference, symmetry, and matrix assertions, plus raised-surface regression and required interaction-coverage checks. Native `ThemeAdapterTests` resolve all 20 roles across two appearances, two contrast traits, and two content sizes: 160 trait/role combinations. A second native test checks body-font growth at accessibility size.

## Commands and Evidence

Durable evidence is preserved in [validation/theme](validation/theme/): raw core, release-gate, Release, capture, and functional UI logs; machine-readable Xcode result summaries; and an integrity manifest. [VALIDATION.md](../VALIDATION.md#theme-evidence--november-3-2026) records the results and scope. Temporary paths below identify the original runs and are no longer the only evidence.

```sh
swift test --scratch-path /private/tmp/leaders-theme-core-build --filter ThemeContrastTests
SIMULATOR_UDID=042F1B65-E9EF-413F-B09B-9B6E3F191ABC bash script/build_and_run.sh --validate
```

The release gate explicitly runs core contrast tests and native adapter tests before an unsigned physical-device Release build. An ordinary `--build` still only builds. Validation products live in temporary storage: a first attempt under Documents failed because Finder/file-provider metadata prevented signing the resource bundle. The metadata was confirmed; source metadata and assertions were not altered.

Targeted contrast log: `/private/tmp/leaders-theme-reviewed-core-final.log`. Broader final core log: `/private/tmp/leaders-theme-final-core.log` (35 passing tests including the increased-contrast extension). Release-gate log: `/private/tmp/leaders-theme-final-gate.log`. Final unsigned Release build: `/private/tmp/leaders-theme-delivery-release.log`. All four functional UI workflows passed in `/private/tmp/leaders-theme-functional`; compact/expanded accessibility-spacing and native adapter checks passed in `/private/tmp/leaders-theme-delivery-compact` and `/private/tmp/leaders-theme-delivery-expanded`. Preview reruns diagnosed duplicate fictional records and loss of selection after relaunch; navigation/setup was corrected without weakening assertions.

## Native Rendering and Limits

Headless simulator appearance switching and the standard launch preference both left captures in light mode. Final captures use explicit `--preview-light` / `--preview-dark` SwiftUI overrides compiled only in Debug. Release has no override; it follows automatic system appearance. Automatic switching on actual hardware remains unverified. Captures are rendered native app UI, not recolored images.

See [Labeled New-Theme Previews](../Previews/README.md#new-theme--compact-and-expanded-previews). These are compact iPhone and expanded iPad layout previews, not Duo captures. A Duo simulator is unavailable on the installed Xcode 27.0 toolchain; Xcode 27.2+, folding transitions, reserved regions, and physical hardware remain unverified.

The initial isolated rendering comparison demonstrated why row traits belong on content: helper-only rows were system white / `#1C1C1E`; explicit rows were `#FBF5EA` / `#3D322B`. [Light Comparison](../Previews/Theme-List-Light.png) and [Dark Comparison](../Previews/Theme-List-Dark.png) preserve that evidence. The initial isolated sample also verified rendered primary, secondary, accent, and danger glyph colors; that evidence is separate from whole-app usability.

Native navigation chrome, menus, DatePicker controls, placeholders, toggles, and system destructive dialogs are platform-rendered. Palette contrast tests do not certify every pixel or state of those controls. Dynamic Type header spacing checks do not establish exhaustive accessibility or VoiceOver compliance. AFT status retains icon plus text; richer status roles, event-failure explanations, a regular-width Fitness layout, and consistent HT/WT Cancel confirmation remain follow-up work outside this color adoption.

### Navigation and Tab Bar Screenshot Checklist

Bars use system materials, so there is no single fixed background hex value: the result depends on appearance, underlying content, scrolling, and accessibility settings. Root tint requests `accentText` for selected tabs and eligible controls; platform button styles can choose their own foreground. Navigation titles and unselected tabs use platform foregrounds, not guaranteed palette roles. Static captures show dark foregrounds in light mode and light foregrounds in dark mode, with gray inactive control states. These are observations, not bar-contrast certification.

- Reviewed in the four retained captures: navigation title, toolbar controls, selected tab, unselected tabs, and visible material backgrounds in both explicit appearances.
- Still required on device: automatic light/dark transitions, scrolled/scroll-edge bar states, enabled/disabled controls, Increase Contrast, Reduce Transparency, and Dynamic Type. Measure foreground contrast against the actual composited material where appropriate.
- Duo-specific outer/inner widths, fold/reserved-region avoidance, and display-transition continuity remain open; iPad previews do not close these checks.
- Follow-up order: status roles with icon/text and Differentiate Without Color behavior; regular-width Fitness layout; independent HT/WT Cancel confirmation. No functional follow-up is implemented by this evidence update.

Primary references: [W3C Text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [W3C Non-Text Contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html), [W3C Relative Luminance](https://www.w3.org/WAI/WCAG22/Understanding/relative-luminance.html), [Apple Row Backgrounds](https://developer.apple.com/documentation/swiftui/view/listrowbackground(_:)), and [Apple Appearance Testing](https://developer.apple.com/documentation/xcuiautomation/xcuidevice/appearance-swift.property).

Final appearance-specific captures passed in `/private/tmp/leaders-theme-capture-compact` and `/private/tmp/leaders-theme-capture-expanded`. Raw screenshot RGB checks passed for 12 canvas/surface/selection/alternating-fill samples across all four exported images. Probe: `/private/tmp/leaders-theme-final-pixels.swift`. Final Release confirmation, including exclusion of debug preview controls: `/private/tmp/leaders-theme-release-confirmed.log`.

## Selected Action Render Diagnostic — November 4, 2026

The certificate action pairing `accentText/rowAlternate` is already included in the 30 requirements: it passes all four appearance/contrast configurations (standard light 5.1869:1, standard dark 4.9205:1).

The new action-style test initially produced fully transparent bitmaps in all 16 configurations: 0/5184 nontransparent pixels, maximum alpha 0. It uses a solid rectangle, not glyphs, and downsamples the entire bitmap rather than sampling a point. `drawHierarchy` returned true, and the hosting view reported the requested appearance/contrast traits. The window was unattached despite one connected scene. [Before PNGs and Metadata](validation/theme/action-alpha-before/manifest.json) retain that diagnostic with the assertions unchanged.

Attaching the window to the available scene, making it key/visible, removing irrelevant test safe-area insets, and yielding for a bounded 100 ms render pass resolved the fixture failure. Their individual contributions were not isolated. All 16 configurations then rendered 5184/5184 opaque pixels and passed the original exact-color assertions; selected labels also pass the original 4.5:1 contrast assertion. [After PNGs and Metadata](validation/theme/action-alpha-after/manifest.json) retain the successful captures. Production action-color selection was not changed by this fixture repair.

Broader verification passed: all three native adapter tests ([result summary](validation/theme/action-adapter-final.json)) and the unsigned physical-device Release build ([log](validation/theme/action-release-final.log)). Core contrast checks also passed during the preceding selection-guard change. No assertion or test was removed, skipped, or weakened.
