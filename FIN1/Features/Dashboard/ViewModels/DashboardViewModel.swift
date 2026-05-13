import Combine
import Foundation
import SwiftUI

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
            self.navigationCoordinator.selectedTab = self.selectedTab
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

        self.setupObservers()
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
        self.userService.currentUser
    }

    var isInvestor: Bool {
        self.userService.isInvestor
    }

    var isTrader: Bool {
        self.userService.isTrader
    }

    var userDisplayName: String {
        self.userService.userDisplayName
    }

    var userRoleDisplayName: String {
        switch self.userService.currentUser?.role {
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
        self.dashboardService.quickStats
    }

    var isLoading: Bool {
        self.dashboardService.isLoading
    }

    // MARK: - Error Handling (Delegated)

    var errorMessage: String? {
        self.errorHandler.errorMessage
    }

    var showError: Bool {
        self.errorHandler.showError
    }

    // MARK: - Navigation (Delegated)

    func navigateToTraderDiscovery() {
        self.navigationCoordinator.navigateToTraderDiscovery()
        self.selectedTab = self.navigationCoordinator.selectedTab
    }

    func clearNavigationSelection() {
        self.navigationCoordinator.clearNavigationSelection()
        self.selectedTab = self.navigationCoordinator.selectedTab
    }

    // MARK: - Data Loading (Delegated)

    func loadDashboardDataAsync() async {
        do {
            try await self.dataLoader.loadDashboardData()
        } catch {
            self.errorHandler.handleDataLoadingError(
                error,
                userId: self.currentUser?.id,
                userRole: self.currentUser?.role.displayName
            )
        }
    }

    func refreshUserData() {
        Task {
            do {
                try await self.dataLoader.refreshUserData()
            } catch {
                self.errorHandler.handleUserRefreshError(
                    error,
                    userId: self.currentUser?.id,
                    userRole: self.currentUser?.role.displayName
                )
            }
        }
    }

    func signOut() {
        Task {
            await self.userService.signOut()
        }
    }

    func clearError() {
        self.errorHandler.clearError()
    }
}
