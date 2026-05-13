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
            TabView(selection: self.$tabCoordinator.selectedTab) {
                ForEach(self.tabCoordinator.getTabConfigurations(), id: \.id) { config in
                    config.view
                        .environmentObject(self.legacyTabRouter) // Use shared TabRouter instance
                        .tabItem {
                            Image(systemName: config.icon)
                            Text(config.title)
                        }
                        .tag(config.id)
                        .badge(config.badge ?? 0)
                }
            }
            .id(self.tabCoordinator.currentRole) // Force TabView recreation on role change
            .accentColor(AppTheme.accentLightBlue)

            VStack {
                // Impersonation Banner (if impersonating)
                if self.isImpersonating {
                    ImpersonationBanner(services: self.services)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .zIndex(100) // Ensure banner is above content
            .onAppear {
                self.isImpersonating = self.services.userService.isImpersonating
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserImpersonationStarted"))) { _ in
                self.isImpersonating = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserImpersonationStopped"))) { _ in
                self.isImpersonating = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .userDataDidUpdate)) { _ in
                self.isImpersonating = self.services.userService.isImpersonating
            }

            // API Failure Info Overlay
            InfoOverlay(
                message: "Trades konnten nicht vom Server geladen werden. Trade-Nummerierung beginnt bei 1.",
                isVisible: self.showAPIFailureInfo
            )
        }
        .onAppear {
            // Update tab configurations when view appears
            self.tabCoordinator.objectWillChange.send()
            // Synchronize legacy router with current tab
            self.legacyTabRouter.selectedTab = self.tabCoordinator.selectedTab
        }
        .onChange(of: self.tabCoordinator.selectedTab) { _, newValue in
            // Keep legacy router in sync with main tab coordinator
            print("🎯 MainTabView: tabCoordinator.selectedTab changed to \(newValue), syncing to legacyTabRouter")
            self.legacyTabRouter.selectedTab = newValue
        }
        .onReceive(NotificationCenter.default.publisher(for: TradeLifecycleService.showAPIFailureInfoNotification)) { _ in
            self.showAPIFailureInfo = true
            // Auto-hide after 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation {
                    self.showAPIFailureInfo = false
                }
            }
        }
        .onChange(of: self.legacyTabRouter.selectedTab) { _, newValue in
            // Keep main tab coordinator in sync with legacy router
            print("🎯 MainTabView: legacyTabRouter.selectedTab changed to \(newValue), syncing to tabCoordinator")
            if self.tabCoordinator.selectedTab != newValue {
                self.tabCoordinator.selectedTab = newValue
            }
        }
        .onChange(of: self.tabCoordinator.currentRole) { oldRole, newRole in
            // Force view refresh when role changes
            print("🔄 MainTabView: Role changed from \(oldRole?.displayName ?? "nil") to \(newRole?.displayName ?? "nil")")
        }
    }
}

#Preview {
    MainTabView(services: .live)
}
