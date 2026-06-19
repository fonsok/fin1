//
//  FIN1App.swift
//  FIN1
//
//  Created by ra on 17.08.25.
//

import SwiftUI
import UIKit

// MARK: - App Entry Point
@main
struct FIN1App: App {
    init() {
        Self.configureWindowBackground()
        TabBarAppearanceConfigurator.configureAppearance()
    }

    /// Matches `UILaunchScreen` / `ScreenBackground` so the window is not black before SwiftUI paints.
    private static func configureWindowBackground() {
        UIWindow.appearance().backgroundColor = StripedListStyle.canvasBackgroundUIColor
    }

    var body: some Scene {
        WindowGroup {
            AppLaunchHost()
        }
    }
}
