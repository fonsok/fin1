import SwiftUI

// MARK: - Responsive Design System
@MainActor
struct ResponsiveDesign {

    // MARK: - Device Size Detection (More Flexible)
    static func isCompactDevice() -> Bool {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let aspectRatio = screenWidth / screenHeight

        // More flexible breakpoints considering aspect ratio
        if isLandscape() {
            return screenWidth < 600 || aspectRatio > 1.8
        } else {
            return screenWidth < 375 || aspectRatio < 0.4
        }
    }

    static func isStandardDevice() -> Bool {
        return !isCompactDevice() && !isLargeDevice()
    }

    static func isLargeDevice() -> Bool {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        let aspectRatio = screenWidth / screenHeight

        // More flexible breakpoints considering aspect ratio
        if isLandscape() {
            return screenWidth >= 900 || aspectRatio > 2.0
        } else {
            return screenWidth >= 428 || aspectRatio > 0.6
        }
    }

    // MARK: - Orientation Detection
    static func isLandscape() -> Bool {
        return UIScreen.main.bounds.width > UIScreen.main.bounds.height
    }

    static func isPortrait() -> Bool {
        return UIScreen.main.bounds.height > UIScreen.main.bounds.width
    }

    // MARK: - Safe Area Awareness
    static func safeAreaInsets() -> UIEdgeInsets {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return .zero
        }
        return window.safeAreaInsets
    }

    static func topSafeAreaPadding() -> CGFloat {
        return safeAreaInsets().top
    }

    static func bottomSafeAreaPadding() -> CGFloat {
        return safeAreaInsets().bottom
    }

    // MARK: - Responsive Spacing
    static func spacing(_ base: CGFloat) -> CGFloat {
        if isCompactDevice() {
            return base * 0.8
        } else if isLargeDevice() {
            return base * 1.2
        }
        return base
    }

    // MARK: - Specific Spacing Values (replacing SpacingConfig)
    static func lightBlueAreaHorizontalPadding() -> CGFloat {
        return spacing(8)
    }

    static func scrollSectionHorizontalPadding() -> CGFloat {
        return spacing(12)
    }

    static func signUpSectionSpacing() -> CGFloat {
        return spacing(24)
    }

    static func signUpElementSpacing() -> CGFloat {
        return spacing(16)
    }

    static func componentHorizontalPadding() -> CGFloat {
        return spacing(12)
    }

    static func componentVerticalPadding() -> CGFloat {
        return spacing(8)
    }

    static func navigationVerticalPadding() -> CGFloat {
        return spacing(32)
    }

    static func progressBarTopPadding() -> CGFloat {
        return spacing(20)
    }

    static func mainHorizontalPadding() -> CGFloat {
        return spacing(16)
    }

    static func mainVerticalPadding() -> CGFloat {
        return spacing(24)
    }

    static func authHorizontalPadding() -> CGFloat {
        return spacing(24)
    }

    static func authVerticalPadding() -> CGFloat {
        return spacing(32)
    }

    static func dashboardHorizontalPadding() -> CGFloat {
        // Ensure minimum 16pt padding regardless of device classification
        // This prevents edge-to-edge content on any device
        return max(16, spacing(16))
    }

    static func dashboardVerticalPadding() -> CGFloat {
        return spacing(20)
    }

    static func horizontalPadding() -> CGFloat {
        // Note: Safe area insets should NOT be added here because:
        // 1. SwiftUI handles safe areas automatically for most views
        // 2. Adding left+right combined to both sides is incorrect
        // 3. The padding value from this function is applied to both leading and trailing
        let basePadding: CGFloat = 16

        if isCompactDevice() {
            // Minimum 12pt even on compact devices
            return max(12, basePadding * 0.75)
        } else if isLargeDevice() {
            return max(24, basePadding * 1.5)
        }
        // Standard devices get 16pt minimum
        return basePadding
    }

    static func verticalPadding() -> CGFloat {
        // Note: Safe area insets should NOT be added here because:
        // 1. SwiftUI handles safe areas automatically for most views
        // 2. Adding top+bottom combined to both sides is incorrect
        // 3. The padding value from this function is applied to both top and bottom
        let basePadding: CGFloat = 16

        if isCompactDevice() {
            return max(12, basePadding * 0.75)
        } else if isLargeDevice() {
            return max(20, basePadding * 1.25)
        }
        return basePadding
    }

    // MARK: - Accessibility-Aware Font Sizes
    static func titleFont() -> Font {
        if isCompactDevice() {
            return .title3
        } else if isLargeDevice() {
            return .largeTitle
        }
        return .title
    }

    static func headlineFont() -> Font {
        if isCompactDevice() {
            return .subheadline
        } else if isLargeDevice() {
            return .title2
        }
        return .headline
    }

    static func bodyFont() -> Font {
        if isCompactDevice() {
            return .caption
        } else if isLargeDevice() {
            return .body
        }
        return .subheadline
    }

    static func captionFont() -> Font {
        if isCompactDevice() {
            return .caption2
        } else if isLargeDevice() {
            return .subheadline
        }
        return .caption
    }

    /// Footnote-tier text (secondary legal/helper copy), scaled by device class like other text styles.
    static func footnoteFont() -> Font {
        if isCompactDevice() {
            return .caption2
        } else if isLargeDevice() {
            return .subheadline
        }
        return .footnote
    }

    /// Dynamic-Type–aware system font (prefer over raw `.font(ResponsiveDesign.scaledSystemFont(size: …))`).
    static func scaledSystemFont(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        let scaled = UIFontMetrics.default.scaledValue(for: size)
        return .system(size: scaled, weight: weight, design: design)
    }

    /// Primary label styling for large input fields (matches prior title3 / title2 split).
    static func inputFieldPrimaryFont() -> Font {
        isCompactDevice() ? .title3 : .title2
    }

    /// Large title font for prominent headers
    static func largeTitleFont() -> Font {
        if isCompactDevice() {
            return .title
        } else if isLargeDevice() {
            return .largeTitle
        }
        return .largeTitle
    }

    /// Icon font with appropriate sizing for SF Symbols
    static func iconFont() -> Font {
        if isCompactDevice() {
            return .system(size: UIFontMetrics.default.scaledValue(for: 16))
        } else if isLargeDevice() {
            return .system(size: UIFontMetrics.default.scaledValue(for: 24))
        }
        return .system(size: UIFontMetrics.default.scaledValue(for: 20))
    }

    // MARK: - Monospaced Fonts (for typewriter design)
    /// Creates an accessibility-aware monospaced font
    /// - Parameters:
    ///   - size: Base font size in points
    ///   - weight: Font weight (default: .regular)
    /// - Returns: Font that respects Dynamic Type while maintaining monospaced design
    static func monospacedFont(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let scaledSize = UIFontMetrics.default.scaledValue(for: size)
        return .system(size: scaledSize, weight: weight, design: .monospaced)
    }

    // MARK: - Responsive Icon Sizes (Accessibility Aware)
    static func iconSize() -> CGFloat {
        let baseSize: CGFloat = 20
        let accessibilityMultiplier = UIFontMetrics.default.scaledValue(for: baseSize) / baseSize

        if isCompactDevice() {
            return baseSize * 0.8 * accessibilityMultiplier
        } else if isLargeDevice() {
            return baseSize * 1.2 * accessibilityMultiplier
        }
        return baseSize * accessibilityMultiplier
    }

    static func profileImageSize() -> CGFloat {
        let baseSize: CGFloat = 60
        let accessibilityMultiplier = UIFontMetrics.default.scaledValue(for: baseSize) / baseSize

        if isCompactDevice() {
            return baseSize * 0.67 * accessibilityMultiplier
        } else if isLargeDevice() {
            return baseSize * 1.33 * accessibilityMultiplier
        }
        return baseSize * accessibilityMultiplier
    }

    // MARK: - UI Constants (Opacity, Font Weights, etc.)
    /// Text opacity for FAQ expandable content
    static let faqAnswerTextOpacity: Double = 0.95

    /// Font weight for FAQ question titles
    static let faqQuestionFontWeight: Font.Weight = .thin

    /// Font weight for FAQ answer text
    static let faqAnswerFontWeight: Font.Weight = .thin

    // MARK: - Responsive Column Widths (Accessibility Aware)
    static func columnWidth(for columnType: ColumnType) -> CGFloat {
        let baseWidth: CGFloat
        let multiplier: CGFloat
        let accessibilityMultiplier = UIFontMetrics.default.scaledValue(for: 16) / 16

        switch columnType {
        case .trader:
            baseWidth = 90
        case .`return`:
            baseWidth = 70
        case .successRate:
            baseWidth = 90
        case .avgReturnPerTrade:
            baseWidth = 80
        case .watchlist:
            baseWidth = 24
        }

        // Apply device size multiplier
        if isCompactDevice() {
            multiplier = 0.85 // Smaller on compact devices
        } else if isLargeDevice() {
            multiplier = 1.15 // Larger on large devices
        } else {
            multiplier = 1.0 // Standard size
        }

        return baseWidth * multiplier * accessibilityMultiplier
    }
}

// MARK: - Column Type Enum
enum ColumnType {
    case trader
    case `return`
    case successRate
    case avgReturnPerTrade
    case watchlist
}

// MARK: - Responsive View Modifiers
struct ResponsivePadding: ViewModifier {
    let horizontal: CGFloat
    let vertical: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, ResponsiveDesign.horizontalPadding())
            .padding(.vertical, ResponsiveDesign.verticalPadding())
    }
}

struct ResponsiveSpacing: ViewModifier {
    let spacing: CGFloat

    func body(content: Content) -> some View {
        content
            .environment(\.spacing, ResponsiveDesign.spacing(spacing))
    }
}

// MARK: - Environment Key for Spacing
private struct SpacingKey: EnvironmentKey {
    static let defaultValue: CGFloat = 16
}

extension EnvironmentValues {
    var spacing: CGFloat {
        get { self[SpacingKey.self] }
        set { self[SpacingKey.self] = newValue }
    }
}

// MARK: - View Extensions
extension View {
    func responsivePadding() -> some View {
        self.modifier(ResponsivePadding(horizontal: ResponsiveDesign.horizontalPadding(), vertical: ResponsiveDesign.verticalPadding()))
    }

    func responsiveSpacing(_ spacing: CGFloat) -> some View {
        self.modifier(ResponsiveSpacing(spacing: spacing))
    }

    // MARK: - Safe Area Aware Modifiers
    func safeAreaPadding() -> some View {
        self.padding(.top, ResponsiveDesign.topSafeAreaPadding())
            .padding(.bottom, ResponsiveDesign.bottomSafeAreaPadding())
    }

    func horizontalSafeAreaPadding() -> some View {
        self.padding(.leading, ResponsiveDesign.safeAreaInsets().left)
            .padding(.trailing, ResponsiveDesign.safeAreaInsets().right)
    }

    // MARK: - SpacingConfig Replacement Extensions
    func signUpHorizontalPadding() -> some View {
        self.padding(.horizontal, ResponsiveDesign.scrollSectionHorizontalPadding())
    }

    func signUpSectionPadding() -> some View {
        self.padding(.horizontal, ResponsiveDesign.scrollSectionHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.signUpSectionSpacing())
    }

    func componentPadding() -> some View {
        self.padding(.horizontal, ResponsiveDesign.componentHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.componentVerticalPadding())
    }

    func navigationPadding() -> some View {
        self.padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
            .padding(.bottom, ResponsiveDesign.navigationVerticalPadding())
    }

    func progressBarPadding() -> some View {
        self.padding(.horizontal, ResponsiveDesign.lightBlueAreaHorizontalPadding())
            .padding(.top, ResponsiveDesign.progressBarTopPadding())
    }

    func mainPadding() -> some View {
        self.padding(.horizontal, ResponsiveDesign.mainHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.mainVerticalPadding())
    }

    func authPadding() -> some View {
        self.padding(.horizontal, ResponsiveDesign.authHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.authVerticalPadding())
    }

    func dashboardPadding() -> some View {
        self.padding(.horizontal, ResponsiveDesign.dashboardHorizontalPadding())
            .padding(.vertical, ResponsiveDesign.dashboardVerticalPadding())
    }
}
