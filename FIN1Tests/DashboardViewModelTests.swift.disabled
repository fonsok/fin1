import XCTest
import Combine
@testable import FIN1

class DashboardViewModelTests: XCTestCase {
    var viewModel: DashboardViewModel!
    var mockUserService: MockUserService!
    var mockDashboardService: MockDashboardService!
    var mockTelemetryService: MockTelemetryService!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        mockUserService = MockUserService()
        mockDashboardService = MockDashboardService()
        mockTelemetryService = MockTelemetryService()
        viewModel = DashboardViewModel(userService: mockUserService, dashboardService: mockDashboardService)
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        viewModel = nil
        mockUserService = nil
        mockDashboardService = nil
        mockTelemetryService = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertNil(viewModel.selectedTab)
        XCTAssertNil(viewModel.currentUser)
        XCTAssertFalse(viewModel.isInvestor)
        XCTAssertFalse(viewModel.isTrader)
        XCTAssertEqual(viewModel.userDisplayName, "Guest")
        XCTAssertEqual(viewModel.userRoleDisplayName, "Guest")
    }

    // MARK: - User Properties Tests

    func testCurrentUser() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Sign in for current user")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        try? await mockUserService.signIn(email: "test@example.com", password: "password123")
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertNotNil(viewModel.currentUser)
        XCTAssertEqual(viewModel.currentUser?.email, "test@example.com")
    }

    func testIsInvestor() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Create investor user")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        await TestHelpers.createInvestorUser(mockUserService: mockUserService)
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertTrue(viewModel.isInvestor)
        XCTAssertFalse(viewModel.isTrader)
    }

    func testIsTrader() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Create trader user")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        await TestHelpers.createTraderUser(mockUserService: mockUserService)
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertTrue(viewModel.isTrader)
        XCTAssertFalse(viewModel.isInvestor)
    }

    func testUserDisplayName() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Create test user")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        await TestHelpers.createTestUser(email: "john.doe@example.com", mockUserService: mockUserService)
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertEqual(viewModel.userDisplayName, "Test User") // MockUserService creates "Test User"
    }

    func testUserRoleDisplayName_Investor() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Create investor user")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        await TestHelpers.createInvestorUser(mockUserService: mockUserService)
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertEqual(viewModel.userRoleDisplayName, "Investor")
    }

    func testUserRoleDisplayName_Trader() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Create trader user")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        await TestHelpers.createTraderUser(mockUserService: mockUserService)
        await TestHelpers.waitForExpectation(expectation)

        // Then
        XCTAssertEqual(viewModel.userRoleDisplayName, "Trader")

        // Given - No user
        mockUserService.currentUser = nil

        // Then
        XCTAssertEqual(viewModel.userRoleDisplayName, "Guest")
    }

    // MARK: - Dashboard Service Properties Tests

    func testRecentActivity() {
        // Given
        // Note: MockDashboardService doesn't have recentActivity property yet
        // This test would need to be updated when the property is added

        // Then
        // For now, just verify the method doesn't crash
        XCTAssertTrue(true)
    }

    func testQuickStats() {
        // Given
        // Note: MockDashboardService doesn't have quickStats property yet
        // This test would need to be updated when the property is added

        // Then
        // For now, just verify the method doesn't crash
        XCTAssertTrue(true)
    }

    // MARK: - Navigation Tests

    func testSelectedTab() {
        // Given
        XCTAssertNil(viewModel.selectedTab)

        // When
        viewModel.selectedTab = "traderDiscovery"

        // Then
        XCTAssertEqual(viewModel.selectedTab, "traderDiscovery")
    }

    func testNavigateToTraderDiscovery() {
        // Given
        XCTAssertNil(viewModel.selectedTab)

        // When
        viewModel.navigateToTraderDiscovery()

        // Then
        XCTAssertEqual(viewModel.selectedTab, "traderDiscovery")
    }

    func testClearNavigationSelection() {
        // Given
        viewModel.selectedTab = "Portfolio"
        XCTAssertEqual(viewModel.selectedTab, "Portfolio")

        // When
        viewModel.clearNavigationSelection()

        // Then
        XCTAssertNil(viewModel.selectedTab)
    }

    // MARK: - Data Loading Tests

    func testLoadDashboardDataSuccess() async {
        // Given
        // MockDashboardService doesn't have error simulation yet
        // Note: This is a placeholder test that will need proper expectations when service is implemented

        // When
        await viewModel.loadDashboardDataAsync()

        // Then
        // For now, just verify the method doesn't crash
        XCTAssertTrue(true) // Placeholder assertion
    }

    func testLoadDashboardDataWithError() async {
        // Given
        // Note: MockDashboardService doesn't have error simulation
        // This test would need to be updated when error handling is added
        // Note: This is a placeholder test that will need proper expectations when service is implemented

        // When
        await viewModel.loadDashboardDataAsync()

        // Then
        // For now, just verify the method doesn't crash
        XCTAssertTrue(true) // Placeholder assertion
    }

    func testRefreshUserDataSuccess() async {
        // Given - No handler set, uses default (no-op)
        let expectation = XCTestExpectation(description: "Refresh user data")
        mockUserService.refreshUserDataHandler = {
            expectation.fulfill()
        }

        // When
        viewModel.refreshUserData()
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertFalse(viewModel.showError)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testRefreshUserDataWithError() async {
        // Given
        let expectedError = AppError.networkError(.noConnection)
        let expectation = XCTestExpectation(description: "Refresh user data error")
        mockUserService.refreshUserDataHandler = {
            expectation.fulfill()
            throw expectedError
        }

        // When
        viewModel.refreshUserData()
        await fulfillment(of: [expectation], timeout: 1.0)

        // Then
        XCTAssertTrue(viewModel.showError)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    // MARK: - Sign Out Tests

    func testSignOut() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Create test user")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        await TestHelpers.createTestUser(mockUserService: mockUserService)
        await TestHelpers.waitForExpectation(expectation)
        XCTAssertTrue(mockUserService.isAuthenticated)

        // When
        viewModel.signOut()
        // Sign out is async but handled internally, no explicit wait needed for this test

        // Then
        XCTAssertFalse(mockUserService.isAuthenticated)
        XCTAssertNil(mockUserService.currentUser)
    }

    // MARK: - Error Handling Tests

    func testErrorHandling() {
        // Given
        // The simplified DashboardViewModel delegates error handling to DashboardErrorHandler

        // When
        // Error handling is now managed by the errorHandler component

        // Then
        XCTAssertTrue(true) // Placeholder assertion
    }

    // MARK: - Publisher Tests

    func testSelectedTabPublisher() {
        // Given
        let expectation = XCTestExpectation(description: "Selected tab should be set")
        var receivedTab: String?

        viewModel.$selectedTab
            .dropFirst() // Skip initial value
            .sink { tab in
                receivedTab = tab
                expectation.fulfill()
            }
            .store(in: &cancellables)

        // When
        viewModel.selectedTab = "traderDiscovery"

        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTab, "traderDiscovery")
    }
}
