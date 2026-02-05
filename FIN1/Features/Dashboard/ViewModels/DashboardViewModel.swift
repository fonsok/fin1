import SwiftUI
import Foundation
import Combine

// MARK: - Simplified Dashboard ViewModel
/// Simplified ViewModel focused on UI state and user role information
@MainActor
final class DashboardViewModel: ObservableObject {
    // MARK: - Dependencies
    private let userService: any UserServiceProtocol
    private let dashboardService: any DashboardServiceProtocol
    private let telemetryService: any TelemetryServiceProtocol
    private let dataLoader: DashboardDataLoaderProtocol
    private let errorHandler: DashboardErrorHandler
    private let navigationCoordinator: DashboardNavigationCoordinator

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties
    @Published var selectedTab: String? {
        didSet {
            navigationCoordinator.selectedTab = selectedTab
        }
    }

    // MARK: - Initialization
    init(
        userService: any UserServiceProtocol,
        dashboardService: any DashboardServiceProtocol,
        telemetryService: any TelemetryServiceProtocol,
        dataLoader: DashboardDataLoaderProtocol? = nil,
        errorHandler: DashboardErrorHandler? = nil,
        navigationCoordinator: DashboardNavigationCoordinator? = nil
    ) {
        self.userService = userService
        self.dashboardService = dashboardService
        self.telemetryService = telemetryService
        self.dataLoader = dataLoader ?? DashboardDataLoader(
            userService: userService,
            dashboardService: dashboardService,
            telemetryService: telemetryService
        )
        self.errorHandler = errorHandler ?? DashboardErrorHandler(
            telemetryService: telemetryService
        )
        self.navigationCoordinator = navigationCoordinator ?? DashboardNavigationCoordinator()

        setupObservers()
    }

    deinit {
        print("🧹 DashboardViewModel deallocated")
    }

    // MARK: - Setup and Observers

    private func setupObservers() {
        // Observe authentication state changes via NotificationCenter
        NotificationCenter.default.addObserver(
            forName: .userDidSignIn,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }

        NotificationCenter.default.addObserver(
            forName: .userDidSignOut,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }

        NotificationCenter.default.addObserver(
            forName: .userDataDidUpdate,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    // MARK: - User Information (Computed Properties)

    var currentUser: User? {
        userService.currentUser
    }

    var isInvestor: Bool {
        userService.isInvestor
    }

    var isTrader: Bool {
        userService.isTrader
    }

    var userDisplayName: String {
        userService.userDisplayName
    }

    var userRoleDisplayName: String {
        switch userService.currentUser?.role {
        case .investor: return "Investor"
        case .trader: return "Trader"
        case .admin: return "Admin"
        case .customerService: return "Kundenberater"
        case .other: return "Other"
        case .none: return "Guest"
        }
    }

    // MARK: - Dashboard Service Properties (Delegated)

    var quickStats: DashboardStats {
        dashboardService.quickStats
    }

    var isLoading: Bool {
        dashboardService.isLoading
    }

    // MARK: - Error Handling (Delegated)

    var errorMessage: String? {
        errorHandler.errorMessage
    }

    var showError: Bool {
        errorHandler.showError
    }

    // MARK: - Navigation (Delegated)

    func navigateToTraderDiscovery() {
        navigationCoordinator.navigateToTraderDiscovery()
        selectedTab = navigationCoordinator.selectedTab
    }

    func clearNavigationSelection() {
        navigationCoordinator.clearNavigationSelection()
        selectedTab = navigationCoordinator.selectedTab
    }

    // MARK: - Data Loading (Delegated)

    func loadDashboardDataAsync() async {
        do {
            try await dataLoader.loadDashboardData()
        } catch {
            errorHandler.handleDataLoadingError(
                error,
                userId: currentUser?.id,
                userRole: currentUser?.role.displayName
            )
        }
    }

    func refreshUserData() {
        Task {
            do {
                try await dataLoader.refreshUserData()
            } catch {
                errorHandler.handleUserRefreshError(
                    error,
                    userId: currentUser?.id,
                    userRole: currentUser?.role.displayName
                )
            }
        }
    }

    func signOut() {
        Task {
            await userService.signOut()
        }
    }

    func clearError() {
        errorHandler.clearError()
    }
}
