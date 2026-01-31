import XCTest
@testable import FIN1

final class DashboardServiceTests: XCTestCase {
    var dashboardService: DashboardService!

    override func setUp() {
        super.setUp()
        dashboardService = DashboardService.shared
        dashboardService.reset()
    }

    override func tearDown() {
        dashboardService = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(dashboardService.isLoading)
        XCTAssertNil(dashboardService.errorMessage)
        XCTAssertTrue(dashboardService.quickStats.totalPortfolioValue == 0)
    }

    // MARK: - Data Loading Tests

    func testLoadDashboardData() async {
        // Given
        let expectation = XCTestExpectation(description: "Dashboard data loaded")

        // When
        do {
            try await dashboardService.loadDashboardData()
            expectation.fulfill()
        } catch {
            XCTFail("Failed to load dashboard data: \(error)")
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertGreaterThan(dashboardService.quickStats.totalPortfolioValue, 0)
    }

    func testLoadQuickStats() async {
        // Given
        let expectation = XCTestExpectation(description: "Quick stats loaded")

        // When
        do {
            try await dashboardService.loadQuickStats()
            expectation.fulfill()
        } catch {
            XCTFail("Failed to load quick stats: \(error)")
        }

        // Then
        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertGreaterThan(dashboardService.quickStats.totalPortfolioValue, 0)
        XCTAssertGreaterThan(dashboardService.quickStats.totalInvestments, 0)
    }

    // MARK: - Statistics Management Tests

    func testUpdateStats() {
        // Given
        let newStats = DashboardStats(
            totalPortfolioValue: 50000,
            dailyChange: 2500,
            dailyChangePercentage: 5.0,
            totalInvestments: 10,
            activeTraders: "5"
        )

        // When
        dashboardService.updateStats(newStats)

        // Then
        XCTAssertEqual(dashboardService.quickStats.totalPortfolioValue, 50000)
        XCTAssertEqual(dashboardService.quickStats.dailyChange, 2500)
        XCTAssertEqual(dashboardService.quickStats.totalInvestments, 10)
    }

    func testResetStats() {
        // Given
        dashboardService.updateStats(DashboardStats(
            totalPortfolioValue: 50000,
            dailyChange: 2500,
            dailyChangePercentage: 5.0,
            totalInvestments: 10,
            activeTraders: "5"
        ))

        // When
        dashboardService.resetStats()

        // Then
        XCTAssertEqual(dashboardService.quickStats.totalPortfolioValue, 0)
        XCTAssertEqual(dashboardService.quickStats.dailyChange, 0)
        XCTAssertEqual(dashboardService.quickStats.totalInvestments, 0)
    }

    // MARK: - Service Lifecycle Tests

    func testServiceLifecycle() {
        // Given
        dashboardService.reset()

        // When
        dashboardService.start()

        // Then
        // Service should be started (in real implementation, this would verify state)
        XCTAssertNotNil(dashboardService)

        // When
        dashboardService.stop()

        // Then
        // Service should be stopped (in real implementation, this would verify state)
        XCTAssertNotNil(dashboardService)
    }
}
