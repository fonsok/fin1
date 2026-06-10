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
        let background = UIColor(named: "ScreenBackground")
            ?? UIColor(red: 26.0 / 255.0, green: 51.0 / 255.0, blue: 102.0 / 255.0, alpha: 1)
        UIWindow.appearance().backgroundColor = background
    }

    var body: some Scene {
        WindowGroup {
            AppLaunchHost()
        }
    }
}
