//
//  ThemeManager.swift
//  FIN1
//
//  Theme management system with target group support
//

import SwiftUI

// MARK: - Theme Manager
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    // MARK: - Target Group Configuration
    enum TargetGroup: String, CaseIterable {
        case standard = "standard"
        case premium = "premium"
        case institutional = "institutional"
        case corporate = "corporate"
        case demo = "demo"

        var displayName: String {
            switch self {
            case .standard: return "Standard"
            case .premium: return "Premium"
            case .institutional: return "Institutional"
            case .corporate: return "Corporate"
            case .demo: return "Demo"
            }
        }

        var description: String {
            switch self {
            case .standard: return "Default theme for regular users"
            case .premium: return "Sophisticated dark theme with gold accents"
            case .institutional: return "Professional blue theme for institutional clients"
            case .corporate: return "Corporate green theme for business clients"
            case .demo: return "Bright theme for demonstration purposes"
            }
        }
    }

    @Published var currentTargetGroup: TargetGroup = .standard

    // MARK: - Theme Colors Structure (Full VVaaa Structure)
    struct ThemeColors {
        // MARK: - Primary Colors
        let primaryBackground: Color
        let cardBackground: Color
        let accentColor: Color

        // MARK: - Text Colors
        let titleText: Color
        let primaryText: Color
        let secondaryText: Color
        let tertiaryText: Color
        let quaternaryText: Color

        // MARK: - Status Colors
        let successGreen: Color
        let warningOrange: Color
        let errorRed: Color
        let infoBlue: Color

        // MARK: - System Component Colors
        let systemBackground: Color
        let systemSecondaryBackground: Color
        let systemTertiaryBackground: Color
        let systemText: Color
        let systemSecondaryText: Color
        let systemTertiaryText: Color
        let systemSeparator: Color
        let systemGroupedBackground: Color
        let systemSecondaryGroupedBackground: Color

        // MARK: - Tab Bar Colors
        let tabBarActive: Color
        let tabBarInactive: Color
        let tabBarBackground: Color

        // MARK: - Input Field Colors
        let inputFieldBackground: Color
        let inputFieldText: Color
        let inputFieldPlaceholder: Color

        // MARK: - Link Colors
        let linkColor: Color
        let secondaryLinkColor: Color

        // MARK: - Button Colors
        let buttonColor: Color

        // MARK: - FIN1 Compatibility Properties
        var screenBackground: Color { primaryBackground }
        var sectionBackground: Color { cardBackground }
        var fontColor: Color { primaryText }
        var accentGreen: Color { successGreen }
        var accentRed: Color { errorRed }
        var accentOrange: Color { warningOrange }
        var accentLightBlue: Color { infoBlue }
        var inputText: Color { inputFieldText }
    }

    // MARK: - Theme Presets (Exact VVaaa Colors)
    private let themes: [TargetGroup: ThemeColors] = [
        .standard: ThemeColors(
            // Primary Colors - Dark blue theme (VVaaa exact values)
            primaryBackground: Color(hex: "#1A3366"), // Dark blue background
            cardBackground: Color(hex: "#0D1A33"), // Darker blue for cards
            accentColor: Color.orange,

            // Text Colors
            titleText: Color(hex: "#F5F5F5"), // Light gray for titles
            primaryText: Color.white,
            secondaryText: Color.white.opacity(0.8),
            tertiaryText: Color.white.opacity(0.6),
            quaternaryText: Color.white.opacity(0.4),

            // Status Colors
            successGreen: Color.green,
            warningOrange: Color.orange,
            errorRed: Color.red,
            infoBlue: Color.blue,

            // System Component Colors
            systemBackground: Color(hex: "#1A3366"), // Same as primary
            systemSecondaryBackground: Color(hex: "#0D1A33"), // Same as card
            systemTertiaryBackground: Color(hex: "#14264D"), // Medium blue
            systemText: Color.white,
            systemSecondaryText: Color.white.opacity(0.8),
            systemTertiaryText: Color.white.opacity(0.6),
            systemSeparator: Color.white.opacity(0.2),
            systemGroupedBackground: Color(hex: "#1A3366"), // Same as primary
            systemSecondaryGroupedBackground: Color(hex: "#0D1A33"), // Same as card

            // Tab Bar Colors
            tabBarActive: Color.white,
            tabBarInactive: Color.white.opacity(0.6),
            tabBarBackground: Color(hex: "#0D1A33"), // Same as card

            // Input Field Colors
            inputFieldBackground: Color(hex: "#8EA0AE"), // Gray-blue input field
            inputFieldText: Color(hex: "#051221"),
            inputFieldPlaceholder: Color.white.opacity(0.6),

            // Link Colors
            linkColor: Color.orange,
            secondaryLinkColor: Color(hex: "#778C9E"), // Muted blue-gray

            // Button Colors
            buttonColor: Color(hex: "#33651a")
        ),

        .premium: ThemeColors(
            // Primary Colors - Darker, more sophisticated (VVaaa exact values)
            primaryBackground: Color(hex: "#0D1A33"), // Very dark blue
            cardBackground: Color(hex: "#050A1A"), // Darkest blue
            accentColor: Color(hex: "#FFCC00"), // Gold accent

            // Text Colors
            titleText: Color(hex: "#FFF2E6"), // Warm white
            primaryText: Color.white,
            secondaryText: Color.white.opacity(0.85),
            tertiaryText: Color.white.opacity(0.7),
            quaternaryText: Color.white.opacity(0.5),

            // Status Colors
            successGreen: Color(hex: "#33CC33"), // Bright green
            warningOrange: Color(hex: "#FF9900"), // Bright orange
            errorRed: Color(hex: "#E63333"), // Bright red
            infoBlue: Color(hex: "#3399FF"), // Bright blue

            // System Component Colors
            systemBackground: Color(hex: "#0D1A33"), // Same as primary
            systemSecondaryBackground: Color(hex: "#050A1A"), // Same as card
            systemTertiaryBackground: Color(hex: "#0A1426"), // Medium dark
            systemText: Color.white,
            systemSecondaryText: Color.white.opacity(0.85),
            systemTertiaryText: Color.white.opacity(0.7),
            systemSeparator: Color.white.opacity(0.25),
            systemGroupedBackground: Color(hex: "#0D1A33"), // Same as primary
            systemSecondaryGroupedBackground: Color(hex: "#050A1A"), // Same as card

            // Tab Bar Colors
            tabBarActive: Color(hex: "#FFF2E6"), // Warm white
            tabBarInactive: Color.white.opacity(0.7),
            tabBarBackground: Color(hex: "#050A1A"), // Same as card

            // Input Field Colors
            inputFieldBackground: Color(hex: "#99A6B3"), // Light gray-blue
            inputFieldText: Color.black,
            inputFieldPlaceholder: Color.black.opacity(0.5),

            // Link Colors
            linkColor: Color(hex: "#FFCC00"), // Gold
            secondaryLinkColor: Color(hex: "#808C99"), // Muted gray

            // Button Colors
            buttonColor: Color(hex: "#33651a")
        ),

        .institutional: ThemeColors(
            // Primary Colors - Professional blue theme (VVaaa exact values)
            primaryBackground: Color(hex: "#0D1A40"), // Professional dark blue
            cardBackground: Color(hex: "#050A26"), // Darker professional blue
            accentColor: Color(hex: "#0099FF"), // Professional blue

            // Text Colors
            titleText: Color(hex: "#F2F8FF"), // Light blue-white
            primaryText: Color.white,
            secondaryText: Color.white.opacity(0.8),
            tertiaryText: Color.white.opacity(0.6),
            quaternaryText: Color.white.opacity(0.4),

            // Status Colors
            successGreen: Color(hex: "#00B34D"), // Professional green
            warningOrange: Color(hex: "#FF8000"), // Professional orange
            errorRed: Color(hex: "#CC3333"), // Professional red
            infoBlue: Color(hex: "#0099FF"), // Professional blue

            // System Component Colors
            systemBackground: Color(hex: "#0D1A40"), // Same as primary
            systemSecondaryBackground: Color(hex: "#050A26"), // Same as card
            systemTertiaryBackground: Color(hex: "#0A1426"), // Medium professional blue
            systemText: Color.white,
            systemSecondaryText: Color.white.opacity(0.8),
            systemTertiaryText: Color.white.opacity(0.6),
            systemSeparator: Color.white.opacity(0.2),
            systemGroupedBackground: Color(hex: "#0D1A40"), // Same as primary
            systemSecondaryGroupedBackground: Color(hex: "#050A26"), // Same as card

            // Tab Bar Colors
            tabBarActive: Color(hex: "#F2F8FF"), // Light blue-white
            tabBarInactive: Color.white.opacity(0.6),
            tabBarBackground: Color(hex: "#050A26"), // Same as card

            // Input Field Colors
            inputFieldBackground: Color(hex: "#8C99A6"), // Professional gray
            inputFieldText: Color.black,
            inputFieldPlaceholder: Color.black.opacity(0.5),

            // Link Colors
            linkColor: Color(hex: "#0099FF"), // Professional blue
            secondaryLinkColor: Color(hex: "#737A8C"), // Muted professional gray

            // Button Colors
            buttonColor: Color(hex: "#33651a")
        ),

        .corporate: ThemeColors(
            // Primary Colors - Corporate green theme (VVaaa exact values)
            primaryBackground: Color(hex: "#0D261A"), // Corporate dark green
            cardBackground: Color(hex: "#051A0D"), // Darker corporate green
            accentColor: Color(hex: "#00CC66"), // Corporate green

            // Text Colors
            titleText: Color(hex: "#E6FFF2"), // Light green-white
            primaryText: Color.white,
            secondaryText: Color.white.opacity(0.8),
            tertiaryText: Color.white.opacity(0.6),
            quaternaryText: Color.white.opacity(0.4),

            // Status Colors
            successGreen: Color(hex: "#00CC66"), // Corporate green
            warningOrange: Color(hex: "#FF9900"), // Corporate orange
            errorRed: Color(hex: "#E63333"), // Corporate red
            infoBlue: Color(hex: "#00B3E6"), // Corporate blue

            // System Component Colors
            systemBackground: Color(hex: "#0D261A"), // Same as primary
            systemSecondaryBackground: Color(hex: "#051A0D"), // Same as card
            systemTertiaryBackground: Color(hex: "#0A2014"), // Medium corporate green
            systemText: Color.white,
            systemSecondaryText: Color.white.opacity(0.8),
            systemTertiaryText: Color.white.opacity(0.6),
            systemSeparator: Color.white.opacity(0.2),
            systemGroupedBackground: Color(hex: "#0D261A"), // Same as primary
            systemSecondaryGroupedBackground: Color(hex: "#051A0D"), // Same as card

            // Tab Bar Colors
            tabBarActive: Color(hex: "#E6FFF2"), // Light green-white
            tabBarInactive: Color.white.opacity(0.6),
            tabBarBackground: Color(hex: "#051A0D"), // Same as card

            // Input Field Colors
            inputFieldBackground: Color(hex: "#99B3A6"), // Corporate gray
            inputFieldText: Color.black,
            inputFieldPlaceholder: Color.black.opacity(0.5),

            // Link Colors
            linkColor: Color(hex: "#00CC66"), // Corporate green
            secondaryLinkColor: Color(hex: "#80998C"), // Muted corporate gray

            // Button Colors
            buttonColor: Color(hex: "#33651a")
        ),

        .demo: ThemeColors(
            // Primary Colors - Bright demo theme (VVaaa exact values)
            primaryBackground: Color(hex: "#334D80"), // Bright blue
            cardBackground: Color(hex: "#264066"), // Medium blue
            accentColor: Color(hex: "#FF6699"), // Pink accent for demo

            // Text Colors
            titleText: Color(hex: "#FFF2E6"), // Warm white
            primaryText: Color.white,
            secondaryText: Color.white.opacity(0.8),
            tertiaryText: Color.white.opacity(0.6),
            quaternaryText: Color.white.opacity(0.4),

            // Status Colors
            successGreen: Color(hex: "#4DCC4D"), // Bright green
            warningOrange: Color(hex: "#FF9933"), // Bright orange
            errorRed: Color(hex: "#E64D4D"), // Bright red
            infoBlue: Color(hex: "#4DB3FF"), // Bright blue

            // System Component Colors
            systemBackground: Color(hex: "#334D80"), // Same as primary
            systemSecondaryBackground: Color(hex: "#264066"), // Same as card
            systemTertiaryBackground: Color(hex: "#2E4773"), // Medium bright blue
            systemText: Color.white,
            systemSecondaryText: Color.white.opacity(0.8),
            systemTertiaryText: Color.white.opacity(0.6),
            systemSeparator: Color.white.opacity(0.2),
            systemGroupedBackground: Color(hex: "#334D80"), // Same as primary
            systemSecondaryGroupedBackground: Color(hex: "#264066"), // Same as card

            // Tab Bar Colors
            tabBarActive: Color(hex: "#FFF2E6"), // Warm white
            tabBarInactive: Color.white.opacity(0.6),
            tabBarBackground: Color(hex: "#264066"), // Same as card

            // Input Field Colors
            inputFieldBackground: Color(hex: "#A6B3BF"), // Bright gray-blue
            inputFieldText: Color.black,
            inputFieldPlaceholder: Color.black.opacity(0.5),

            // Link Colors
            linkColor: Color(hex: "#FF6699"), // Pink for demo
            secondaryLinkColor: Color(hex: "#8C99A6"), // Muted gray

            // Button Colors
            buttonColor: Color(hex: "#33651a")
        )
    ]

    // MARK: - Current Theme Access
    var currentTheme: ThemeColors {
        return themes[currentTargetGroup] ?? {
            guard let standardTheme = themes[.standard] else {
                fatalError("Standard theme must always exist")
            }
            return standardTheme
        }()
    }

    var colors: ThemeColors {
        return currentTheme
    }

    // MARK: - Methods
    func switchTargetGroup(_ group: TargetGroup) {
        currentTargetGroup = group
        UserDefaults.standard.set(group.rawValue, forKey: "selectedTargetGroup")
    }

    func getThemeForGroup(_ group: TargetGroup) -> ThemeColors {
        return themes[group] ?? {
            guard let standardTheme = themes[.standard] else {
                fatalError("Standard theme must always exist")
            }
            return standardTheme
        }()
    }

    // MARK: - Initialization
    private init() {
        if let savedGroup = UserDefaults.standard.string(forKey: "selectedTargetGroup"),
           let group = TargetGroup(rawValue: savedGroup) {
            currentTargetGroup = group
        }
    }
}

// MARK: - Environment Key
private struct ThemeManagerKey: EnvironmentKey {
    static let defaultValue: ThemeManager = .shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeManagerKey.self] }
        set { self[ThemeManagerKey.self] = newValue }
    }
}
