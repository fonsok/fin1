import SwiftUI
import UIKit

// MARK: - Tab Bar Appearance Configurator
/// Configures the appearance of the tab bar
enum TabBarAppearanceConfigurator {
    /// Configures the default tab bar appearance
    static func configureAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(AppTheme.sectionBackground)

        // Customize unselected item color to ensure visibility against the dark background
        appearance.stackedLayoutAppearance.normal.iconColor = .gray
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.gray]

        // Apply the appearance settings
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    /// Updates appearance for a specific theme
    /// - Parameter theme: The color scheme to configure for
    static func updateAppearance(for theme: ColorScheme) {
        // Future: Add theme-specific appearance updates
        configureAppearance()
    }
}
