import SwiftUI
import Foundation

// MARK: - Dashboard Navigation Coordinator
/// Handles navigation state and routing for the dashboard
final class DashboardNavigationCoordinator: ObservableObject {
    @Published var selectedTab: String?

    // MARK: - Navigation Actions

    func navigateToTraderDiscovery() {
        selectedTab = "traderDiscovery"
    }

    func clearNavigationSelection() {
        selectedTab = nil
    }

    // MARK: - Navigation State

    var isNavigatingToDiscovery: Bool {
        selectedTab == "traderDiscovery"
    }
}
