import Testing
@testable import LeadersBookCore

@Suite struct ThemeContrastTests {
    @Test(arguments: ThemeMode.allCases, ThemeAccessibilityContrast.allCases)
    func everyRequirementMeetsWCAG(mode: ThemeMode, contrast: ThemeAccessibilityContrast) {
        for req in ThemeContrast.requirements {
            let ratio = req.foreground.rgb(in: mode, contrast: contrast).contrastRatio(with: req.background.rgb(in: mode, contrast: contrast))
            #expect(ratio >= req.minimum, "\(req.label) in \(mode): \(ratio) < \(req.minimum)")
        }
    }

    @Test func statusRolesHaveAllSurfaceRequirements() {
        for role in [ThemeRole.statusSuccess, .statusWarning, .statusFailure] {
            for surface in [ThemeRole.background, .surface, .surfaceRaised, .rowAlternate] {
                #expect(ThemeContrast.requirements.contains { $0.foreground == role && $0.background == surface && $0.minimum >= 4.5 })
            }
        }
    }

    @Test func knownRatioMatchesReference() {
        // Black on white is exactly 21:1.
        let ratio = ThemeRGB(0x000000).contrastRatio(with: ThemeRGB(0xFFFFFF))
        #expect(abs(ratio - 21) < 0.001)
    }

    @Test func contrastIsSymmetric() {
        let a = ThemeRGB(0x454E35), b = ThemeRGB(0xF4EBDD)
        #expect(a.contrastRatio(with: b) == b.contrastRatio(with: a))
    }

    @Test(arguments: ThemeMode.allCases)
    func raisedSurfaceRegression(mode: ThemeMode) {
        let surface = ThemeRole.surfaceRaised.rgb(in: mode)
        #expect(ThemeRole.danger.rgb(in: mode).contrastRatio(with: surface) >= 4.5)
        #expect(ThemeRole.border.rgb(in: mode).contrastRatio(with: surface) >= 3)
        #expect(ThemeRole.accentText.rgb(in: mode).contrastRatio(with: surface) >= 4.5)
    }

    @Test func interactionPairingsRemainCovered() {
        for background in [ThemeRole.accentPressed, .rowSelected, .privacyCover, .disabledFill] {
            #expect(ThemeContrast.requirements.contains { $0.background == background && $0.minimum >= 4.5 })
        }
        let required: [(ThemeRole, ThemeRole)] = [
            (.textPrimary, .surface), (.textSecondary, .surface),
            (.textPrimary, .rowAlternate), (.textSecondary, .rowAlternate),
            (.textOnSelected, .rowSelected), (.disabledText, .disabledFill),
            (.textOnPrivacyCover, .privacyCover)
        ]
        for (foreground, background) in required {
            #expect(ThemeContrast.requirements.contains {
                $0.foreground == foreground && $0.background == background && $0.minimum >= 4.5
            })
        }
    }
}
