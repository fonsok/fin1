import SwiftUI
import Combine

// MARK: - Tab Configuration
struct TabConfiguration {
    let id: Int
    let icon: String
    let title: String
    let view: AnyView
    let isVisible: Bool
    let badge: Int?

    init<Content: View>(
        id: Int,
        icon: String,
        title: String,
        isVisible: Bool = true,
        badge: Int? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.icon = icon
        self.title = title
        self.isVisible = isVisible
        self.badge = badge
        self.view = AnyView(content())
    }
}

// MARK: - Role-based Tab Coordinator
/// Coordinates tab configuration and navigation based on user role
@MainActor
final class RoleBasedTabCoordinator: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published private(set) var profileBadge: Int = 0
    @Published private(set) var currentRole: UserRole?

    private let userService: any UserServiceProtocol
    private let notificationService: any NotificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    init(userService: any UserServiceProtocol, notificationService: any NotificationServiceProtocol) {
        self.userService = userService
        self.notificationService = notificationService
        self.currentRole = userService.userRole
        // For admins and customer service, start on their primary tab (id: 0)
        self.selectedTab = 0
        setupBadgeObservation()
        setupRoleObservation()
        updateProfileBadge()
    }

    // MARK: - Role Observation

    private func setupRoleObservation() {
        // Listen for role changes via notification
        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleRoleChange()
            }
            .store(in: &cancellables)

        // Also listen for explicit role change notification
        NotificationCenter.default.publisher(for: NSNotification.Name("UserRoleChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleRoleChange()
            }
            .store(in: &cancellables)
    }

    private func handleRoleChange() {
        let newRole = userService.userRole
        if newRole != currentRole {
            print("🔄 RoleBasedTabCoordinator: Role changed from \(currentRole?.displayName ?? "nil") to \(newRole?.displayName ?? "nil")")
            currentRole = newRole
            // Reset to primary tab for new role
            selectedTab = 0
            objectWillChange.send()
        }
    }

    // MARK: - Tab Configurations

    func getTabConfigurations() -> [TabConfiguration] {
        let role = currentRole

        var tabs: [TabConfiguration] = []

        // For admins and customer service, skip the general Dashboard and start with role-specific view
        if role != .admin && role != .customerService {
            // Dashboard Tab - Visible for investors and traders
            tabs.append(TabConfiguration(
                id: 0,
                icon: "house.fill",
                title: "Dashboard",
                content: { DashboardView().accessibilityIdentifier("DashboardTab") }
            ))
        }

        // Role-specific primary tab
        switch role {
        case .investor:
            tabs.append(TabConfiguration(
                id: 1,
                icon: "magnifyingglass",
                title: "Discover",
                content: { InvestorDiscoveryViewWrapper() }
            ))

            tabs.append(TabConfiguration(
                id: 2,
                icon: "chart.pie.fill",
                title: "Investments",
                content: { InvestmentsViewWrapper().accessibilityIdentifier("InvestmentsTab") }
            ))

        case .trader:
            tabs.append(TabConfiguration(
                id: 1,
                icon: "chart.pie.fill",
                title: "Depot",
                content: { TraderDepotView() }
            ))

            tabs.append(TabConfiguration(
                id: 2,
                icon: "chart.line.uptrend.xyaxis",
                title: "Trades",
                content: { TradesOverviewView() }
            ))
            
            tabs.append(TabConfiguration(
                id: 3,
                icon: "bell.fill",
                title: "Alerts",
                content: { PriceAlertListViewWrapper() }
            ))

        case .admin:
            // Admin tab is now the first tab (id: 0) for admins
            tabs.append(TabConfiguration(
                id: 0,
                icon: "hammer.fill",
                title: "Admin",
                content: { AdminDashboardView() }
            ))

        case .customerService:
            // Customer Service Dashboard as primary tab
            tabs.append(TabConfiguration(
                id: 0,
                icon: "headphones.circle.fill",
                title: "Kundenservice",
                content: { CustomerSupportDashboardView() }
            ))

        default:
            tabs.append(TabConfiguration(
                id: 1,
                icon: "questionmark",
                title: "Select Role",
                content: {
                    Text("Please select your role to continue")
                        .font(ResponsiveDesign.headlineFont())
                        .foregroundColor(AppTheme.fontColor)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppTheme.screenBackground)
                }
            ))
        }

        // Watchlist Tab - Role-specific content
        tabs.append(TabConfiguration(
            id: getWatchlistTabId(for: role),
            icon: "star.fill",
            title: "Watchlist",
            content: { getWatchlistContent(for: role) }
        ))

        // Profile Tab - Always visible with badge
        tabs.append(TabConfiguration(
            id: getProfileTabId(for: role),
            icon: "person.fill",
            title: "Profile",
            badge: profileBadge > 0 ? profileBadge : nil,
            content: { ModularProfileView() }
        ))

        return tabs.filter { $0.isVisible }
    }

    // MARK: - Helper Methods

    private func getWatchlistTabId(for role: UserRole?) -> Int {
        switch role {
        case .investor: return 3
        case .trader: return 4  // Trader: Dashboard(0), Depot(1), Trades(2), Alerts(3), Watchlist(4), Profile(5)
        case .admin: return 1  // Admin: Admin(0), Watchlist(1), Profile(2)
        case .customerService: return 1  // CSR: CustomerSupport(0), Watchlist(1), Profile(2)
        default: return 2
        }
    }

    private func getProfileTabId(for role: UserRole?) -> Int {
        switch role {
        case .investor: return 4
        case .trader: return 5  // Trader: Dashboard(0), Depot(1), Trades(2), Alerts(3), Watchlist(4), Profile(5)
        case .admin: return 2  // Admin: Admin(0), Watchlist(1), Profile(2)
        case .customerService: return 2  // CSR: CustomerSupport(0), Watchlist(1), Profile(2)
        default: return 3
        }
    }

    private func getUnreadNotificationCount() -> Int {
        let currentUserId = userService.currentUser?.id
        return notificationService.getCombinedUnreadCount(for: currentUserId)
    }

    // MARK: - Badge Observation

    private func setupBadgeObservation() {
        // Observe NotificationService combined count when concrete instance available
        if let concreteNotificationService = notificationService as? NotificationService {
            concreteNotificationService.$combinedUnreadCount
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.updateProfileBadge()
                }
                .store(in: &cancellables)
        }

        // Observe user changes so badge recalculates on user switch/update
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateProfileBadge() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateProfileBadge() }
            .store(in: &cancellables)
    }

    private func updateProfileBadge() {
        let count = getUnreadNotificationCount()
        if profileBadge != count {
            profileBadge = count
        }
    }

    private func getWatchlistContent(for role: UserRole?) -> AnyView {
        switch role {
        case .investor:
            return AnyView(InvestorWatchlistViewWrapper())
        case .trader:
            return AnyView(TraderWatchlistViewWrapper())
        case .admin:
            return AnyView(InvestorWatchlistViewWrapper()) // Admin can use investor watchlist
        default:
            return AnyView(InvestorWatchlistViewWrapper()) // Default to investor watchlist
        }
    }

    // MARK: - Navigation Helpers

    func navigateToTab(_ tabId: Int) {
        selectedTab = tabId
    }

    func getPrimaryTabId(for role: UserRole?) -> Int {
        // For admins and customer service, primary tab is 0 (role-specific view)
        // For others (investors, traders), primary tab is 1 (role-specific view after Dashboard)
        switch role {
        case .admin, .customerService:
            return 0
        default:
            return 1
        }
    }
}
