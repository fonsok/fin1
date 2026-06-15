import SwiftUI

/// Root shell after `AppServices` bootstrap (replaces blocking init in `FIN1App`).
@MainActor
struct AppRootContent: View {
    let services: AppServices
    @ObservedObject var lifecycleCoordinator: ServiceLifecycleCoordinator
    let launchStartTime: Date

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        self.rootView
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.appServices, self.services)
            .background(AppTheme.screenBackground.ignoresSafeArea())
            .preferredColorScheme(.dark)
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
            .onReceive(NotificationCenter.default.publisher(for: .userDocumentInboxShouldRefresh)) { notification in
                Task { @MainActor in
                    await self.refreshDocumentInbox(notification: notification)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .fin1NetworkReachableAgain)) { _ in
                Task { @MainActor in
                    if self.services.userService.currentUser != nil {
                        await OfflineOperationQueue.shared.processQueue()
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .backendBecameHealthy)) { _ in
                Task { @MainActor in
                    await self.refreshTraderPoolInvestmentsIfNeeded()
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

    private func handleAppBecameActive() async {
        let launchTime = Date().timeIntervalSince(self.launchStartTime)
        print("🚀 App launch time: \(String(format: "%.3f", launchTime)) seconds")

        await self.lifecycleCoordinator.startServices()

        print("🔗 Parse Server Configuration:")
        print("   URL: \(self.services.configurationService.parseServerURL ?? "nil")")
        print("   Live Query URL: \(self.services.configurationService.parseLiveQueryURL ?? "nil")")
        print("   Application ID: \(self.services.configurationService.parseApplicationId ?? "nil")")

        if self.services.userService.currentUser != nil {
            Task {
                await OfflineOperationQueue.shared.processQueue()
            }
        }

        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard let liveQueryClient = self.services.parseLiveQueryClient else {
                print("⚠️ Parse Live Query Client not available")
                return
            }
            do {
                try await liveQueryClient.connect()
                print("✅ Parse Live Query connected successfully!")
            } catch {
                print("⚠️ Failed to connect Parse Live Query: \(error.localizedDescription)")
            }
        }

        await self.refreshUserScopedData()
        MonthlyStatementPrefetch.schedule(services: self.services)

        self.services.telemetryService.trackEvent(
            name: "app_active",
            properties: ["launch_time_seconds": launchTime]
        )

        Task(priority: .utility) {
            try? await Task.sleep(nanoseconds: 500_000_000)
            await self.services.slaMonitoringService.startMonitoring(interval: nil)
        }
    }

    private func refreshDocumentInbox(notification: Notification) async {
        guard self.lifecycleCoordinator.criticalServicesReady else { return }
        guard let currentUser = services.userService.currentUser else { return }
        let force = (notification.userInfo?["force"] as? Bool) ?? true
        await self.services.documentService.refreshUserDocumentInbox(for: currentUser, force: force)
    }

    private func refreshUserScopedData() async {
        guard self.lifecycleCoordinator.criticalServicesReady else { return }
        guard let currentUser = services.userService.currentUser else { return }

        async let loadNotifications: Void = self.services.notificationService.loadNotifications(for: currentUser)
        async let loadDocuments: Void = await self.services.documentService.loadDocuments(for: currentUser)
        async let loadInvoices: Void = { _ = try? await self.services.invoiceService.loadInvoices(for: currentUser.id) }()
        async let generateInvoices: Void = self.preloadInvoicesForCompletedTrades()
        async let loadTraderPoolInvestments: Void = self.refreshTraderPoolInvestmentsIfNeeded()
        await loadNotifications
        await loadDocuments
        await loadInvoices
        await generateInvoices
        await loadTraderPoolInvestments
    }

    private func refreshTraderPoolInvestmentsIfNeeded() async {
        guard let currentUser = services.userService.currentUser, currentUser.role == .trader else { return }
        await self.services.investmentService.fetchFromBackendForTrader(user: currentUser)
    }

    private func preloadInvoicesForCompletedTrades() async {
        guard !self.services.configurationService.blocksLocalInvoiceGeneration else {
            print("ℹ️ AppRootContent: skip local invoice backfill — monetary server-only active")
            return
        }
        let completedTrades = self.services.tradeLifecycleService.completedTrades
        await self.services.invoiceService.generateInvoicesForCompletedTrades(completedTrades)
    }

    private func handleAppEnteredBackground() async {
        await self.syncPendingDataToBackend()
        self.services.slaMonitoringService.stopMonitoring()
        self.services.parseLiveQueryClient?.disconnect()
        self.lifecycleCoordinator.optimizeMemoryUsage()
        await self.lifecycleCoordinator.stopServices()
    }

    private func syncPendingDataToBackend() async {
        print("📤 Syncing pending data to backend...")
        guard let currentUser = services.userService.currentUser else {
            print("⚠️ No current user, skipping background sync")
            return
        }

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

    static func schedule(services: AppServices) {
        guard self.inFlight == nil else { return }
        self.inFlight = Task { @MainActor in
            defer { MonthlyStatementPrefetch.inFlight = nil }
            guard let user = services.userService.currentUser else { return }
            await MonthlyAccountStatementGenerator.ensureMonthlyStatements(for: user, services: services)
        }
    }
}
