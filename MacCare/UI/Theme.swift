import SwiftUI

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    static let mcWindow = Color(hex: 0xF5F5F7)
    static let mcCard = Color(hex: 0xFFFFFF)
    static let mcChrome = Color(hex: 0xFBFBFC)
    static let mcChromeBorder = Color(hex: 0xDCDCE0)
    static let mcCardBorder = Color(hex: 0xE3E3E8)
    static let mcRowBorder = Color(hex: 0xEDEDF0)
    static let mcControlBorder = Color(hex: 0xD2D2D7)
    static let mcText = Color(hex: 0x1D1D1F)
    static let mcSecondary = Color(hex: 0x5E5E66)
    static let mcDisabled = Color(hex: 0x6E6E76)
    static let mcDisabledRow = Color(hex: 0xFAFAFB)
    static let mcAccent = Color(hex: 0x0A6E7C)
    static let mcAccentTint = Color(hex: 0xE6F3F5)
    static let mcDiskUsed = Color(hex: 0x3A4652)
    static let mcDiskFree = Color(hex: 0xE3E3E8)
    static let mcDiskFreeBorder = Color(hex: 0xC7C7CC)
    static let mcWarning = Color(hex: 0xB45309)
    static let mcWarningText = Color(hex: 0x5A3A12)
    static let mcBanner = Color(hex: 0xFFF4E5)
    static let mcBannerBorder = Color(hex: 0xF2C68C)
    static let mcBannerButtonBorder = Color(hex: 0xE0B57A)
}

enum Metrics {
    static let windowPaddingH: CGFloat = 24
    static let windowPaddingV: CGFloat = 16
    static let cardGap: CGFloat = 12
    static let cardRadius: CGFloat = 12
    static let bannerRadius: CGFloat = 10
    static let buttonRadius: CGFloat = 7
    static let primaryButtonRadius: CGFloat = 8
    static let tileRadius: CGFloat = 7
    static let rowHeight: CGFloat = 42
    static let listHeaderHeight: CGFloat = 34
    static let footerHeight: CGFloat = 60
    static let buttonHeight: CGFloat = 28
    static let primaryButtonHeight: CGFloat = 32
    static let sizeColumnWidth: CGFloat = 72
}

struct CardBackground: ViewModifier {
    var radius: CGFloat = Metrics.cardRadius
    var fill: Color = .mcCard
    var border: Color = .mcCardBorder

    func body(content: Content) -> some View {
        content
            .background(fill, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(border, lineWidth: 1)
            )
    }
}

extension View {
    func card(radius: CGFloat = Metrics.cardRadius, fill: Color = .mcCard, border: Color = .mcCardBorder) -> some View {
        modifier(CardBackground(radius: radius, fill: fill, border: border))
    }
}

/// Flat button used across the app's custom chrome.
struct MCButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case warning
        case warningSecondary
    }

    var kind: Kind = .secondary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: isPrimary ? .semibold : (kind == .warning ? .medium : .regular)))
            .foregroundStyle(foreground)
            .padding(.horizontal, isPrimary ? 18 : 12)
            .frame(height: isPrimary ? Metrics.primaryButtonHeight : Metrics.buttonHeight)
            .background(background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(border, lineWidth: 1)
                }
            }
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var isPrimary: Bool { kind == .primary }

    private var radius: CGFloat {
        kind == .primary ? Metrics.primaryButtonRadius : Metrics.buttonRadius
    }

    private var foreground: Color {
        switch kind {
        case .primary, .warning: return .white
        case .secondary, .warningSecondary: return .mcText
        }
    }

    private var background: Color {
        switch kind {
        case .primary: return .mcAccent
        case .warning: return .mcWarning
        case .secondary, .warningSecondary: return .mcCard
        }
    }

    private var border: Color? {
        switch kind {
        case .primary, .warning: return nil
        case .secondary: return .mcControlBorder
        case .warningSecondary: return .mcBannerButtonBorder
        }
    }
}
