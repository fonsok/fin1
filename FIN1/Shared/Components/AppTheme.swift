//
//  AppTheme.swift
//  FIN1
//
//  Theme access layer - provides convenient access to ThemeManager colors
//  Matches VVaaa's AppTheme pattern for consistency
//

import SwiftUI

struct AppTheme {
    // MARK: - Colors (using ThemeManager)
    static var primaryBackground: Color { ThemeManager.shared.colors.primaryBackground }
    static var cardBackground: Color { ThemeManager.shared.colors.cardBackground }
    static var accentOrange: Color { ThemeManager.shared.colors.accentColor }

    // MARK: - Text Colors
    static var titleText: Color { ThemeManager.shared.colors.titleText }
    static var primaryText: Color { ThemeManager.shared.colors.primaryText }
    static var secondaryText: Color { ThemeManager.shared.colors.secondaryText }
    static var tertiaryText: Color { ThemeManager.shared.colors.tertiaryText }
    static var quaternaryText: Color { ThemeManager.shared.colors.quaternaryText }

    // MARK: - System Component Colors
    static var systemBackground: Color { ThemeManager.shared.colors.systemBackground }
    static var systemSecondaryBackground: Color { ThemeManager.shared.colors.systemSecondaryBackground }
    static var systemTertiaryBackground: Color { ThemeManager.shared.colors.systemTertiaryBackground }
    static var systemText: Color { ThemeManager.shared.colors.systemText }
    static var systemSecondaryText: Color { ThemeManager.shared.colors.systemSecondaryText }
    static var systemTertiaryText: Color { ThemeManager.shared.colors.systemTertiaryText }
    static var systemSeparator: Color { ThemeManager.shared.colors.systemSeparator }
    static var systemGroupedBackground: Color { ThemeManager.shared.colors.systemGroupedBackground }
    static var systemSecondaryGroupedBackground: Color { ThemeManager.shared.colors.systemSecondaryGroupedBackground }

    // MARK: - Tab Bar Colors
    static var tabBarActive: Color { ThemeManager.shared.colors.tabBarActive }
    static var tabBarInactive: Color { ThemeManager.shared.colors.tabBarInactive }
    static var tabBarBackground: Color { ThemeManager.shared.colors.tabBarBackground }

    // MARK: - Status Colors
    static var successGreen: Color { ThemeManager.shared.colors.successGreen }
    static var warningOrange: Color { ThemeManager.shared.colors.warningOrange }
    static var errorRed: Color { ThemeManager.shared.colors.errorRed }
    static var infoBlue: Color { ThemeManager.shared.colors.infoBlue }

    // MARK: - Input Field Colors
    static var inputFieldBackground: Color { ThemeManager.shared.colors.inputFieldBackground }
    static var inputFieldText: Color { ThemeManager.shared.colors.inputFieldText }
    static var inputText: Color { ThemeManager.shared.colors.inputText }
    static var inputFieldPlaceholder: Color { ThemeManager.shared.colors.inputFieldPlaceholder }

    // MARK: - Link Colors
    static var linkColor: Color { ThemeManager.shared.colors.linkColor }
    static var secondaryLinkColor: Color { ThemeManager.shared.colors.secondaryLinkColor }

    // MARK: - Button Colors
    static var buttonColor: Color { Color("AccentGreen") }

    // MARK: - FIN1 Compatibility (maps to existing Color.fin1* names)
    static var screenBackground: Color { ThemeManager.shared.colors.primaryBackground }
    static var sectionBackground: Color { ThemeManager.shared.colors.cardBackground }
    static var fontColor: Color { ThemeManager.shared.colors.primaryText }
    static var accentLightBlue: Color { ThemeManager.shared.colors.infoBlue }
    static var accentGreen: Color { Color("AccentGreen") }
    static var accentRed: Color { ThemeManager.shared.colors.errorRed }
    // Note: accentOrange is already defined above as accentColor

    // MARK: - Typography
    /// Legacy semantic fonts. Prefer `ResponsiveDesign.*Font()` in new SwiftUI code (`AppTheme` is not `@MainActor` and cannot forward `ResponsiveDesign` here).
    struct Typography {
        static let largeTitle = Font.largeTitle
        static let title = Font.title
        static let headline = Font.headline
        static let subheadline = Font.subheadline
        static let body = Font.body
        static let caption = Font.caption
        static let smallCaption = Font.caption2
        static let footnote = Font.footnote
    }

    // MARK: - Spacing
    struct Spacing {
        static let xsmall: CGFloat = 2
        static let small: CGFloat = 4
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
        static let xxlarge: CGFloat = 20
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
    }
}

// MARK: - View Modifiers
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(AppTheme.Spacing.xlarge)
            .background(AppTheme.cardBackground)
            .cornerRadius(AppTheme.CornerRadius.medium)
    }
}

struct SectionTitleStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(ResponsiveDesign.headlineFont())
            .fontWeight(.semibold)
            .foregroundColor(AppTheme.primaryText)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func sectionTitleStyle() -> some View {
        modifier(SectionTitleStyle())
    }
}
