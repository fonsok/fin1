import Foundation
import SwiftUI

// MARK: - Dashboard Navigation Coordinator
/// Handles navigation state and routing for the dashboard
final class DashboardNavigationCoordinator: ObservableObject {
    @Published var selectedTab: String?

    // MARK: - Navigation Actions

    func navigateToTraderDiscovery() {
        self.selectedTab = "traderDiscovery"
    }

    func clearNavigationSelection() {
        self.selectedTab = nil
    }

    // MARK: - Navigation State

    var isNavigatingToDiscovery: Bool {
        self.selectedTab == "traderDiscovery"
    }
}
