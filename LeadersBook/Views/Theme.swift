import SwiftUI

extension Color {
    /// Adapts to the current interface style (including per-view overrides).
    static func theme(_ role: ThemeRole) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = role.rgb(in: traits.userInterfaceStyle == .dark ? .dark : .light,
                               contrast: traits.accessibilityContrast == .high ? .increased : .standard)
            return UIColor(
                red: CGFloat(rgb.red) / 255,
                green: CGFloat(rgb.green) / 255,
                blue: CGFloat(rgb.blue) / 255,
                alpha: 1
            )
        })
    }

    static var lbBackground: Color { theme(.background) }
    static var lbSurface: Color { theme(.surface) }
    static var lbSurfaceRaised: Color { theme(.surfaceRaised) }
    static var lbTextPrimary: Color { theme(.textPrimary) }
    static var lbTextSecondary: Color { theme(.textSecondary) }
    static var lbAccent: Color { theme(.accent) }
    static var lbOnAccent: Color { theme(.onAccent) }
    static var lbAccentText: Color { theme(.accentText) }
    static var lbHighlight: Color { theme(.highlight) }
    static var lbOnHighlight: Color { theme(.onHighlight) }
    static var lbDanger: Color { theme(.danger) }
    static var lbBorder: Color { theme(.border) }
}

extension EnvironmentValues {
    @Entry var leadersBookRowIsSelected = false
}

struct LBActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.leadersBookRowIsSelected) private var isSelected
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.foregroundStyle(Color.theme(isSelected ? .textOnSelected : (isEnabled ? .accentText : .disabledText)))
            .underline(configuration.isPressed)
    }
}

/// Primary filled button in theme colors.
struct LBPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.theme(isEnabled ? .onAccent : .disabledText))
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .frame(minHeight: 44)
            .background(Color.theme(isEnabled ? (configuration.isPressed ? .accentPressed : .accent) : .disabledFill), in: .rect(cornerRadius: 12))
    }
}

extension View {
    /// Themes the List/Form canvas. Row fill belongs to the row content.
    func leadersBookList() -> some View {
        self
            .scrollContentBackground(.hidden)
            .background(Color.lbBackground)
    }

    /// Apply to row content, a row ForEach, or an appropriate Section.
    func leadersBookRow(alternating: Bool = false, selected: Bool = false) -> some View {
        self.listRowBackground(Color.theme(selected ? .rowSelected : (alternating ? .rowAlternate : .surface)))
            .environment(\.leadersBookRowIsSelected, selected)
            .foregroundStyle(Color.theme(selected ? .textOnSelected : .textPrimary),
                             Color.theme(selected ? .textOnSelected : .textSecondary))
            .listRowSeparatorTint(Color.theme(selected ? .textOnSelected : .border))
    }

    /// App canvas + default tint. Apply once at the root of each scene.
    func leadersBookTheme() -> some View {
        self
            .tint(Color.lbAccentText)
            .foregroundStyle(Color.lbTextPrimary, Color.lbTextSecondary)
            .background(Color.lbBackground.ignoresSafeArea())
    }
}


/// Status meaning remains available through words and distinct symbols in every mode.
enum LBStatus: CaseIterable {
    case success, warning, failure
    var symbol: String {
        switch self { case .success: "checkmark.circle"; case .warning: "clock.badge.exclamationmark"; case .failure: "exclamationmark.triangle" }
    }
    var role: ThemeRole {
        switch self { case .success: .statusSuccess; case .warning: .statusWarning; case .failure: .statusFailure }
    }
    func foreground(selected: Bool, differentiate: Bool) -> ThemeRole {
        selected ? .textOnSelected : (differentiate ? .textPrimary : role)
    }
}

struct LBStatusLabel: View {
    let text: String
    let status: LBStatus
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate
    @Environment(\.leadersBookRowIsSelected) private var selected
    var body: some View {
        Label(text, systemImage: status.symbol)
            .labelStyle(.titleAndIcon)
            .foregroundStyle(Color.theme(status.foreground(selected: selected, differentiate: differentiate)))
            .fontWeight(differentiate ? .semibold : .regular)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct AFTStatusSummary: View {
    let result: AFTResult
    var body: some View {
        LBStatusLabel(text: result.meetsStandard ? "Meets Standard" : "Does Not Meet Standard",
                      status: result.meetsStandard ? .success : .failure)
        if result.totalShortfall > 0 {
            LBStatusLabel(text: "Total: \(result.totalShortfall) Points Below the \(result.standard.minimum)-Point Standard", status: .failure)
        }
        ForEach(result.failedEvents) { event in
            LBStatusLabel(text: "\(event.title): \(result.points(for: event).value)/100 — No Go (\(result.points(for: event).shortfall) Points Below Standard)", status: .failure)
        }
    }
}
