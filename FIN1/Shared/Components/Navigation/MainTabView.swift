import SwiftUI

// MARK: - Tab Router (Legacy Support)
final class TabRouter: ObservableObject {
    @Published var selectedTab: Int = 0
}

// MARK: - Optimized Main Tab View
struct MainTabView: View {
    @Environment(\.appServices) private var services
    @StateObject private var tabCoordinator: RoleBasedTabCoordinator
    @StateObject private var legacyTabRouter: TabRouter
    @Environment(\.themeManager) private var themeManager

    init(services: AppServices) {
        _tabCoordinator = StateObject(wrappedValue: RoleBasedTabCoordinator(
            userService: services.userService,
            notificationService: services.notificationService
        ))
        _legacyTabRouter = StateObject(wrappedValue: TabRouter())
    }

    @State private var showAPIFailureInfo = false
    @State private var isImpersonating = false

    var body: some View {
        ZStack {
            TabView(selection: $tabCoordinator.selectedTab) {
                ForEach(tabCoordinator.getTabConfigurations(), id: \.id) { config in
                    config.view
                        .environmentObject(legacyTabRouter) // Use shared TabRouter instance
                        .tabItem {
                            Image(systemName: config.icon)
                            Text(config.title)
                        }
                        .tag(config.id)
                        .badge(config.badge ?? 0)
                }
            }
            .id(tabCoordinator.currentRole) // Force TabView recreation on role change
            .accentColor(AppTheme.accentLightBlue)

            VStack {
                // Impersonation Banner (if impersonating)
                if isImpersonating {
                    ImpersonationBanner(services: services)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .zIndex(100) // Ensure banner is above content
            .onAppear {
                isImpersonating = services.userService.isImpersonating
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserImpersonationStarted"))) { _ in
                isImpersonating = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserImpersonationStopped"))) { _ in
                isImpersonating = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
                isImpersonating = services.userService.isImpersonating
            }

            // API Failure Info Overlay
            InfoOverlay(
                message: "Trades konnten nicht vom Server geladen werden. Trade-Nummerierung beginnt bei 1.",
                isVisible: showAPIFailureInfo
            )
        }
        .onAppear {
            // Update tab configurations when view appears
            tabCoordinator.objectWillChange.send()
            // Synchronize legacy router with current tab
            legacyTabRouter.selectedTab = tabCoordinator.selectedTab
        }
        .onChange(of: tabCoordinator.selectedTab) { _, newValue in
            // Keep legacy router in sync with main tab coordinator
            print("🎯 MainTabView: tabCoordinator.selectedTab changed to \(newValue), syncing to legacyTabRouter")
            legacyTabRouter.selectedTab = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: TradeLifecycleService.showAPIFailureInfoNotification)) { _ in
            showAPIFailureInfo = true
            // Auto-hide after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    showAPIFailureInfo = false
                }
            }
        }
        .onChange(of: legacyTabRouter.selectedTab) { _, newValue in
            // Keep main tab coordinator in sync with legacy router
            print("🎯 MainTabView: legacyTabRouter.selectedTab changed to \(newValue), syncing to tabCoordinator")
            if tabCoordinator.selectedTab != newValue {
                tabCoordinator.selectedTab = newValue
            }
        }
        .onChange(of: tabCoordinator.currentRole) { oldRole, newRole in
            // Force view refresh when role changes
            print("🔄 MainTabView: Role changed from \(oldRole?.displayName ?? "nil") to \(newRole?.displayName ?? "nil")")
        }
    }
}

#Preview {
    MainTabView(services: .live)
}
