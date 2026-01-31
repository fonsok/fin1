import XCTest
@testable import FIN1

final class RoleRouterTests: XCTestCase {
    func testTabConfigurationsForRoles() {
        // Test that RoleBasedTabCoordinator can be created and returns tab configurations
        let mockUserService = MockUserService()
        let mockNotificationService = MockNotificationService()

        let tabCoordinator = RoleBasedTabCoordinator(
            userService: mockUserService,
            notificationService: mockNotificationService
        )

        // Test that we can get tab configurations
        let configurations = tabCoordinator.getTabConfigurations()
        XCTAssertFalse(configurations.isEmpty)

        // Test that dashboard tab is always present
        let dashboardTab = configurations.first { $0.title == "Dashboard" }
        XCTAssertNotNil(dashboardTab)
        XCTAssertEqual(dashboardTab?.icon, "house.fill")
    }
}
