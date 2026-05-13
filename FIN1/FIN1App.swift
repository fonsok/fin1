//
//  FIN1App.swift
//  FIN1
//
//  Created by ra on 17.08.25.
//

import Combine
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
            self.rootView
                .environment(\.appServices, self.services)
                .background(AppTheme.screenBackground)
                .preferredColorScheme(.dark) // Force dark mode to match our color scheme
                .onChange(of: self.scenePhase) { _, newPhase in
                    Task { @MainActor in
                        await self.handleScenePhaseChange(newPhase)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .userDidSignIn)) { _ in
                    Task { @MainActor in
                        await self.refreshUserScopedData()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
                    Task { @MainActor in
                        await self.refreshUserScopedData()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .fin1NetworkReachableAgain)) { _ in
                    Task { @MainActor in
                        if self.services.userService.currentUser != nil {
                            await OfflineOperationQueue.shared.processQueue()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var rootView: some View {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-entry-limit-buy-order") {
            UITestLimitButtonsEntryView(services: self.services, mode: .buy)
                .environmentObject(TabRouter())
        } else if ProcessInfo.processInfo.arguments.contains("--ui-test-entry-limit-sell-order") {
            UITestLimitButtonsEntryView(services: self.services, mode: .sell)
                .environmentObject(TabRouter())
        } else {
            AuthenticationView()
        }
        #else
        AuthenticationView()
        #endif
    }

    // MARK: - Scene Phase Handling

    @MainActor
    private func handleScenePhaseChange(_ newPhase: ScenePhase) async {
        switch newPhase {
        case .active:
            await self.handleAppBecameActive()
        case .background:
            await self.handleAppEnteredBackground()
        case .inactive:
            break
        @unknown default:
            break
        }
    }

    @MainActor
    private func handleAppBecameActive() async {
        // Track launch performance
        let launchTime = Date().timeIntervalSince(self.launchStartTime)
        print("🚀 App launch time: \(String(format: "%.3f", launchTime)) seconds")

        // Start services with optimized lifecycle
        await self.lifecycleCoordinator.startServices()

        // Log Parse Server configuration for debugging
        print("🔗 Parse Server Configuration:")
        print("   URL: \(self.services.configurationService.parseServerURL ?? "nil")")
        print("   Live Query URL: \(self.services.configurationService.parseLiveQueryURL ?? "nil")")
        print("   Application ID: \(self.services.configurationService.parseApplicationId ?? "nil")")

        // Process offline operation queue when app becomes active
        Task {
            // Resource-saving & UX: only process the offline queue once a user is available.
            // The queue is @MainActor and may do non-trivial work; avoid impacting the unauthenticated landing experience.
            if self.services.userService.currentUser != nil {
                await OfflineOperationQueue.shared.processQueue()
            }
        }

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

        await self.refreshUserScopedData()

        // Monthly statements: non-blocking so activation can finish (telemetry, SLA, etc.) promptly.
        MonthlyStatementPrefetch.schedule(services: self.services)

        // Track app activation with launch time
        self.services.telemetryService.trackEvent(name: "app_active", properties: ["launch_time_seconds": launchTime])

        // Start SLA monitoring service (uses configured interval)
        Task {
            await self.services.slaMonitoringService.startMonitoring(interval: nil)
        }
    }

    @MainActor
    private func preloadInvoicesForCompletedTrades(using services: AppServices) async {
        let completedTrades = services.tradeLifecycleService.completedTrades
        await services.invoiceService.generateInvoicesForCompletedTrades(completedTrades)
    }

    @MainActor
    private func refreshUserScopedData() async {
        guard self.lifecycleCoordinator.criticalServicesReady else { return }
        guard let currentUser = services.userService.currentUser else { return }

        async let loadNotifications: Void = self.services.notificationService.loadNotifications(for: currentUser)
        async let loadDocuments: Void = self.services.documentService.loadDocuments(for: currentUser)
        async let loadInvoices: Void = { _ = try? await self.services.invoiceService.loadInvoices(for: currentUser.id) }()
        async let generateInvoices: Void = self.preloadInvoicesForCompletedTrades(using: self.services)
        await loadNotifications
        await loadDocuments
        await loadInvoices
        await generateInvoices
    }

    @MainActor
    private func handleAppEnteredBackground() async {
        // Sync pending data to backend before going to background
        await self.syncPendingDataToBackend()

        // Stop SLA monitoring to save battery
        self.services.slaMonitoringService.stopMonitoring()

        // Disconnect Parse Live Query to save battery
        self.services.parseLiveQueryClient?.disconnect()

        // Optimize memory usage before stopping services
        self.lifecycleCoordinator.optimizeMemoryUsage()

        // Stop non-critical services to save battery
        await self.lifecycleCoordinator.stopServices()
    }

    /// Syncs any pending local data to the backend before app goes to background
    @MainActor
    private func syncPendingDataToBackend() async {
        print("📤 Syncing pending data to backend...")

        guard let currentUser = services.userService.currentUser else {
            print("⚠️ No current user, skipping background sync")
            return
        }

        // Sequential: avoids Swift 6 task-group + nested @MainActor isolation checker issues.
        await self.services.investmentService.syncToBackend()
        await self.services.orderManagementService.syncToBackend()
        await self.services.paymentService.syncToBackend()
        await self.services.documentService.syncToBackend()
        await self.services.userService.syncToBackend()
        await self.services.securitiesWatchlistService.syncToBackend()
        await self.services.notificationService.syncPushTokensToBackend(for: currentUser.id)
        await self.services.watchlistService.syncToBackend()
        await self.services.invoiceService.syncToBackend()
        await self.services.customerSupportService.syncToBackend()
        if let filterSyncService = services.filterSyncService {
            await filterSyncService.syncToBackend()
        }
        if let priceAlertService = services.priceAlertService {
            await priceAlertService.syncToBackend()
        }

        print("✅ Background sync completed")
    }
}

// MARK: - Monthly statement prefetch (non-blocking)

@MainActor
private enum MonthlyStatementPrefetch {
    static var inFlight: Task<Void, Never>?

    /// Runs statement generation on the main actor without awaiting it from `handleAppBecameActive`.
    /// Skips if a run is already in progress; re-reads the current user when the task starts.
    static func schedule(services: AppServices) {
        guard self.inFlight == nil else { return }
        self.inFlight = Task { @MainActor in
            defer { MonthlyStatementPrefetch.inFlight = nil }
            guard let user = services.userService.currentUser else { return }
            await MonthlyAccountStatementGenerator.ensureMonthlyStatements(for: user, services: services)
        }
    }
}
