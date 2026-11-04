import Foundation

// LeadersBook theme. Source palette:
//   #322822 espresso · #6C5744 umber · #957A5A tan · #DBB57E sand · #777348 olive · #454E35 forest
// Light and dark values are authored per role. Every text/background pairing is
// asserted when ThemeContrastTests is run. Release validation must invoke tests.

// MARK: - Color value (no string parsing, so no failure path)

struct ThemeRGB: Sendable, Equatable {
    let red: UInt8
    let green: UInt8
    let blue: UInt8

    /// 0xRRGGBB literal.
    init(_ hex: UInt32) {
        red = UInt8((hex >> 16) & 0xFF)
        green = UInt8((hex >> 8) & 0xFF)
        blue = UInt8(hex & 0xFF)
    }

    /// WCAG 2.x relative luminance.
    var relativeLuminance: Double {
        func linear(_ channel: UInt8) -> Double {
            let c = Double(channel) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// WCAG contrast ratio, 1...21. Symmetric.
    func contrastRatio(with other: ThemeRGB) -> Double {
        let a = relativeLuminance, b = other.relativeLuminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

// MARK: - Roles

enum ThemeAccessibilityContrast: Sendable, CaseIterable { case standard, increased }

enum ThemeMode: Sendable, CaseIterable { case light, dark }

/// Semantic roles. Views use roles, never raw palette colors.
enum ThemeRole: Sendable, CaseIterable {
    case statusSuccess, statusWarning, statusFailure
    case accentPressed
    case rowAlternate
    case rowSelected
    case textOnSelected
    case privacyCover
    case textOnPrivacyCover
    case disabledFill
    case disabledText
    case background       // app canvas
    case surface          // cards, list rows
    case surfaceRaised    // sheets, grouped fills, selected rows
    case textPrimary
    case textSecondary
    case accent           // primary action fill, selection tint
    case onAccent         // text/icons on accent
    case accentText       // links and small accent-colored text
    case highlight        // badges, "ready" chips (sand)
    case onHighlight
    case danger           // destructive text/icons
    case border           // hairlines, control outlines (non-text, 3:1)

    func rgb(in mode: ThemeMode, contrast: ThemeAccessibilityContrast = .standard) -> ThemeRGB {
        if contrast == .increased {
            switch self {
            case .statusSuccess: return ThemeRGB(mode == .light ? 0x163D22 : 0xC0E8C7)
            case .textSecondary, .disabledText: return ThemeRole.textPrimary.rgb(in: mode)
            case .accentText: return ThemeRole.accent.rgb(in: mode)
            case .danger: return ThemeRGB(mode == .light ? 0x7E241C : 0xFFD4CA)
            case .border: return ThemeRGB(mode == .light ? 0x6C5744 : 0xDBB57E)
            default: break
            }
        }
        return switch (self, mode) {
        case (.statusSuccess, .light): ThemeRGB(0x245C35)
        case (.statusSuccess, .dark): ThemeRGB(0x9ED5A8)
        case (.statusWarning, _): ThemeRole.textSecondary.rgb(in: mode, contrast: contrast)
        case (.statusFailure, _): ThemeRole.danger.rgb(in: mode, contrast: contrast)
        case (.accentPressed, .light): ThemeRGB(0x39432B)
        case (.accentPressed, .dark): ThemeRGB(0xC7A16A)
        case (.rowAlternate, _), (.disabledFill, _): ThemeRole.surfaceRaised.rgb(in: mode)
        case (.rowSelected, _): ThemeRole.accent.rgb(in: mode)
        case (.textOnSelected, _): ThemeRole.onAccent.rgb(in: mode)
        case (.privacyCover, _): ThemeRole.background.rgb(in: mode)
        case (.textOnPrivacyCover, _): ThemeRole.textPrimary.rgb(in: mode)
        case (.disabledText, _): ThemeRole.textSecondary.rgb(in: mode)
        case (.background, .light):     ThemeRGB(0xF4EBDD)
        case (.background, .dark):      ThemeRGB(0x322822) // espresso
        case (.surface, .light):        ThemeRGB(0xFBF5EA)
        case (.surface, .dark):         ThemeRGB(0x3D322B)
        case (.surfaceRaised, .light):  ThemeRGB(0xE9DCC6)
        case (.surfaceRaised, .dark):   ThemeRGB(0x4A3E35)
        case (.textPrimary, .light):    ThemeRGB(0x241C17)
        case (.textPrimary, .dark):     ThemeRGB(0xF4EBDD)
        case (.textSecondary, .light):  ThemeRGB(0x5A4636)
        case (.textSecondary, .dark):   ThemeRGB(0xC9B79B)
        case (.accent, .light):         ThemeRGB(0x454E35) // forest
        case (.accent, .dark):          ThemeRGB(0xDBB57E) // sand
        case (.onAccent, .light):       ThemeRGB(0xF4EBDD)
        case (.onAccent, .dark):        ThemeRGB(0x322822)
        case (.accentText, .light):     ThemeRGB(0x5E5A36) // deepened olive
        case (.accentText, .dark):      ThemeRGB(0xB3B77F) // lightened olive
        case (.highlight, _):           ThemeRGB(0xDBB57E) // sand
        case (.onHighlight, _):         ThemeRGB(0x241C17)
        case (.danger, .light):         ThemeRGB(0x9C3B2E)
        case (.danger, .dark):          ThemeRGB(0xEE9B8C)
        case (.border, .light):         ThemeRGB(0x8A6F4F) // tan, darkened for 3:1 on surfaceRaised
        case (.border, .dark):          ThemeRGB(0xAA8E6A) // tan, lightened for 3:1 on surfaceRaised
        }
    }
}

// MARK: - Contrast Requirements

struct ContrastRequirement: Sendable {
    let foreground: ThemeRole
    let background: ThemeRole
    let minimum: Double
    let label: String
}

enum ThemeContrast {
    static let textMinimum = 4.5       // WCAG AA, normal text
    static let nonTextMinimum = 3.0    // WCAG AA, UI components / graphics

    static let requirements: [ContrastRequirement] = {
        let text = textMinimum, ui = nonTextMinimum
        var list: [ContrastRequirement] = []
        for bg in [ThemeRole.background, .surface, .surfaceRaised] {
            list.append(.init(foreground: .textPrimary, background: bg, minimum: text, label: "textPrimary/\(bg)"))
            list.append(.init(foreground: .textSecondary, background: bg, minimum: text, label: "textSecondary/\(bg)"))
        }
        for bg in [ThemeRole.background, .surface, .surfaceRaised] {
            list.append(.init(foreground: .accentText, background: bg, minimum: text, label: "accentText/\(bg)"))
            list.append(.init(foreground: .danger, background: bg, minimum: text, label: "danger/\(bg)"))
            list.append(.init(foreground: .border, background: bg, minimum: ui, label: "border/\(bg)"))
        }
        list.append(.init(foreground: .onAccent, background: .accent, minimum: text, label: "onAccent/accent"))
        list.append(.init(foreground: .onHighlight, background: .highlight, minimum: text, label: "onHighlight/highlight"))
        list.append(.init(foreground: .accent, background: .background, minimum: ui, label: "accent/background"))
        for fg in [ThemeRole.textPrimary, .textSecondary, .accentText, .danger] {
            list.append(.init(foreground: fg, background: .rowAlternate, minimum: text, label: "\(fg)/rowAlternate"))
        }
        list.append(.init(foreground: .border, background: .rowAlternate, minimum: ui, label: "border/rowAlternate"))
        list.append(.init(foreground: .textOnSelected, background: .rowSelected, minimum: text, label: "textOnSelected/rowSelected"))
        for bg in [ThemeRole.background, .surface, .rowAlternate] {
            list.append(.init(foreground: .rowSelected, background: bg, minimum: ui, label: "rowSelected/\(bg)"))
        }
        list.append(.init(foreground: .textOnPrivacyCover, background: .privacyCover, minimum: text, label: "textOnPrivacyCover/privacyCover"))
        list.append(.init(foreground: .onAccent, background: .accentPressed, minimum: text, label: "onAccent/accentPressed"))
        list.append(.init(foreground: .disabledText, background: .disabledFill, minimum: text, label: "disabledText/disabledFill"))
        for foreground in [ThemeRole.statusSuccess, .statusWarning, .statusFailure] {
            for background in [ThemeRole.background, .surface, .surfaceRaised, .rowAlternate] {
                list.append(.init(foreground: foreground, background: background, minimum: text, label: "\(foreground)/\(background)"))
            }
        }
        return list
    }()
}
