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
    private let services: AppServices = .live
    @StateObject private var lifecycleCoordinator: ServiceLifecycleCoordinator
    @Environment(\.scenePhase) private var scenePhase

    // Launch performance tracking
    private let launchStartTime = Date()

    init() {
        self._lifecycleCoordinator = StateObject(wrappedValue: ServiceLifecycleCoordinator(services: .live))
        // Configure global tab bar appearance at composition root
        TabBarAppearanceConfigurator.configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            AuthenticationView()
                .environment(\.appServices, services)
                .background(AppTheme.screenBackground)
                .preferredColorScheme(.dark) // Force dark mode to match our color scheme
                .onChange(of: scenePhase) { _, newPhase in
                    Task {
                        await handleScenePhaseChange(newPhase)
                    }
                }
        }
    }

    // MARK: - Scene Phase Handling

    private func handleScenePhaseChange(_ newPhase: ScenePhase) async {
        switch newPhase {
        case .active:
            await handleAppBecameActive()
        case .background:
            await handleAppEnteredBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    private func handleAppBecameActive() async {
        // Track launch performance
        let launchTime = Date().timeIntervalSince(launchStartTime)
        print("🚀 App launch time: \(String(format: "%.3f", launchTime)) seconds")

        // Start services with optimized lifecycle
        await lifecycleCoordinator.startServices()
        
        // Log Parse Server configuration for debugging
        print("🔗 Parse Server Configuration:")
        print("   URL: \(services.configurationService.parseServerURL ?? "nil")")
        print("   Live Query URL: \(services.configurationService.parseLiveQueryURL ?? "nil")")
        print("   Application ID: \(services.configurationService.parseApplicationId ?? "nil")")
        
        // Connect Parse Live Query for real-time updates
        if let liveQueryClient = services.parseLiveQueryClient {
            Task {
                do {
                    try await liveQueryClient.connect()
                    print("✅ Parse Live Query connected successfully!")
                } catch {
                    print("⚠️ Failed to connect Parse Live Query: \(error.localizedDescription)")
                    print("   Error details: \(error)")
                }
            }
        } else {
            print("⚠️ Parse Live Query Client not available")
        }

        // Preload user data only after critical services are ready
        guard lifecycleCoordinator.criticalServicesReady else { return }
        guard let currentUser = services.userService.currentUser else { return }

        // Load user-specific data in parallel
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await services.notificationService.loadNotifications(for: currentUser)
            }
            group.addTask {
                await services.documentService.loadDocuments(for: currentUser)
            }
            group.addTask {
                let completedTrades = await services.tradeLifecycleService.completedTrades
                await services.invoiceService.generateInvoicesForCompletedTrades(completedTrades)
            }
            group.addTask {
                await MonthlyAccountStatementGenerator.ensureMonthlyStatements(
                    for: currentUser,
                    services: services
                )
            }
        }

        // Track app activation with launch time
        services.telemetryService.trackEvent(name: "app_active", properties: ["launch_time_seconds": launchTime])

        // Start SLA monitoring service (uses configured interval)
        Task {
            await services.slaMonitoringService.startMonitoring(interval: nil)
        }
    }

    private func handleAppEnteredBackground() async {
        // Stop SLA monitoring to save battery
        services.slaMonitoringService.stopMonitoring()
        
        // Disconnect Parse Live Query to save battery
        services.parseLiveQueryClient?.disconnect()

        // Optimize memory usage before stopping services
        lifecycleCoordinator.optimizeMemoryUsage()

        // Stop non-critical services to save battery
        await lifecycleCoordinator.stopServices()
    }
}
