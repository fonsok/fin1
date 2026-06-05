//
//  FIN1App.swift
//  FIN1
//
//  Created by ra on 17.08.25.
//

import SwiftUI

// MARK: - App Entry Point
@main
struct FIN1App: App {
    init() {
        TabBarAppearanceConfigurator.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            AppLaunchHost()
        }
    }
}
