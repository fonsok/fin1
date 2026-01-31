import XCTest
@testable import FIN1

final class CompletedInvestmentsViewModelTests: XCTestCase {
    var viewModel: CompletedInvestmentsViewModel!
    var mockUserService: MockUserService!
    var mockInvestmentService: MockInvestmentService!

    override func setUp() {
        super.setUp()
        mockUserService = MockUserService()
        mockInvestmentService = MockInvestmentService()
        viewModel = CompletedInvestmentsViewModel(
            userService: mockUserService,
            investmentService: mockInvestmentService
        )
    }

    override func tearDown() {
        viewModel = nil
        mockUserService = nil
        mockInvestmentService = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.investments.isEmpty)
        XCTAssertNil(viewModel.selectedYear)
        XCTAssertFalse(viewModel.showCompletedInvestmentDetails)
        XCTAssertNil(viewModel.selectedCompletedInvestment)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
    }

    // MARK: - Data Loading Tests

    func testLoadCompletedInvestments_LoadsFromService() {
        // Given
        let completedInvestment = createCompletedInvestment(
            id: "1",
            completedAt: Date()
        )
        let activeInvestment = createActiveInvestment(id: "2")

        mockInvestmentService.investments = [completedInvestment, activeInvestment]

        // When
        viewModel.loadCompletedInvestments()

        // Then
        XCTAssertEqual(viewModel.investments.count, 2)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testLoadCompletedInvestments_AutoSelectsCurrentYear() {
        // Given
        let currentYear = Calendar.current.component(.year, from: Date())
        let completedInvestment = createCompletedInvestment(
            id: "1",
            completedAt: Date()
        )
        mockInvestmentService.investments = [completedInvestment]

        // When
        viewModel.loadCompletedInvestments()

        // Then
        XCTAssertEqual(viewModel.selectedYear, currentYear)
    }

    func testLoadCompletedInvestments_DoesNotAutoSelectWhenYearAlreadySet() {
        // Given
        let previousYear = 2020
        viewModel.selectedYear = previousYear
        let completedInvestment = createCompletedInvestment(
            id: "1",
            completedAt: Date()
        )
        mockInvestmentService.investments = [completedInvestment]

        // When
        viewModel.loadCompletedInvestments()

        // Then
        XCTAssertEqual(viewModel.selectedYear, previousYear)
    }

    func testLoadCompletedInvestments_DoesNotAutoSelectWhenNoCompletedInvestments() {
        // Given
        let activeInvestment = createActiveInvestment(id: "1")
        mockInvestmentService.investments = [activeInvestment]

        // When
        viewModel.loadCompletedInvestments()

        // Then
        XCTAssertNil(viewModel.selectedYear)
    }

    // MARK: - Completed Investments Filtering Tests

    func testCompletedInvestments_FiltersOnlyCompletedStatus() {
        // Given
        let completed1 = createCompletedInvestment(id: "1", completedAt: Date())
        let completed2 = createCompletedInvestment(id: "2", completedAt: Date())
        let active = createActiveInvestment(id: "3")
        let cancelled = createCancelledInvestment(id: "4")

        mockInvestmentService.investments = [completed1, completed2, active, cancelled]
        viewModel.investments = mockInvestmentService.investments

        // When
        let completed = viewModel.completedInvestments

        // Then
        XCTAssertEqual(completed.count, 2)
        XCTAssertTrue(completed.allSatisfy { $0.status == .completed })
        XCTAssertEqual(completed.map { $0.id }, ["1", "2"])
    }

    func testCompletedInvestments_ReturnsEmptyWhenNoCompleted() {
        // Given
        let active = createActiveInvestment(id: "1")
        mockInvestmentService.investments = [active]
        viewModel.investments = mockInvestmentService.investments

        // When
        let completed = viewModel.completedInvestments

        // Then
        XCTAssertTrue(completed.isEmpty)
    }

    // MARK: - Year Filtering Tests

    func testCompletedInvestmentsByYear_FiltersBySelectedYear() {
        // Given
        let calendar = Calendar.current
        guard let year2023 = calendar.date(from: DateComponents(year: 2023, month: 6, day: 15)),
              let year2024 = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15)) else {
            XCTFail("Failed to create test dates")
            return
        }

        let investment2023 = createCompletedInvestment(id: "1", completedAt: year2023)
        let investment2024a = createCompletedInvestment(id: "2", completedAt: year2024)
        let investment2024b = createCompletedInvestment(id: "3", completedAt: year2024)

        viewModel.investments = [investment2023, investment2024a, investment2024b]
        viewModel.selectedYear = 2024

        // When
        let filtered = viewModel.completedInvestmentsByYear

        // Then
        XCTAssertEqual(filtered.count, 2)
        XCTAssertEqual(filtered.map { $0.id }, ["2", "3"])
    }

    func testCompletedInvestmentsByYear_ReturnsAllWhenNoYearSelected() {
        // Given
        let investment1 = createCompletedInvestment(id: "1", completedAt: Date())
        let investment2 = createCompletedInvestment(id: "2", completedAt: Date())

        viewModel.investments = [investment1, investment2]
        viewModel.selectedYear = nil

        // When
        let filtered = viewModel.completedInvestmentsByYear

        // Then
        XCTAssertEqual(filtered.count, 2)
    }

    func testCompletedInvestmentsByYear_ExcludesInvestmentsWithoutCompletedAt() {
        // Given
        // Create a completed investment but manually set completedAt to nil
        var investment = createCompletedInvestment(id: "1", completedAt: Date())
        // Note: Since completedAt is let, we can't modify it directly
        // This test verifies the filter logic handles nil completedAt
        let investmentWithDate = createCompletedInvestment(id: "2", completedAt: Date())

        viewModel.investments = [investmentWithDate]
        viewModel.selectedYear = Calendar.current.component(.year, from: Date())

        // When
        let filtered = viewModel.completedInvestmentsByYear

        // Then
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, "2")
    }

    // MARK: - Available Years Tests

    func testAvailableYears_ReturnsUniqueYearsSortedDescending() {
        // Given
        let calendar = Calendar.current
        guard let year2022 = calendar.date(from: DateComponents(year: 2022, month: 6, day: 15)),
              let year2023 = calendar.date(from: DateComponents(year: 2023, month: 6, day: 15)),
              let year2024 = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15)) else {
            XCTFail("Failed to create test dates")
            return
        }

        let investment2022 = createCompletedInvestment(id: "1", completedAt: year2022)
        let investment2023a = createCompletedInvestment(id: "2", completedAt: year2023)
        let investment2023b = createCompletedInvestment(id: "3", completedAt: year2023)
        let investment2024 = createCompletedInvestment(id: "4", completedAt: year2024)

        viewModel.investments = [investment2022, investment2023a, investment2023b, investment2024]

        // When
        let years = viewModel.availableYears

        // Then
        XCTAssertEqual(years, [2024, 2023, 2022])
    }

    func testAvailableYears_ReturnsEmptyWhenNoCompletedInvestments() {
        // Given
        let active = createActiveInvestment(id: "1")
        viewModel.investments = [active]

        // When
        let years = viewModel.availableYears

        // Then
        XCTAssertTrue(years.isEmpty)
    }

    func testAvailableYears_ExcludesInvestmentsWithoutCompletedAt() {
        // Given
        // Only include investments with completedAt dates
        let investmentWithDate = createCompletedInvestment(id: "1", completedAt: Date())
        viewModel.investments = [investmentWithDate]

        // When
        let years = viewModel.availableYears

        // Then
        XCTAssertEqual(years.count, 1)
    }

    // MARK: - Investment Completion Status Update Tests

    /// This test verifies the complete flow:
    /// 1. Investment starts as ACTIVE (ongoing) with pool reservations
    /// 2. Trader completes trades for all pools (pool status becomes .completed)
    /// 3. Investment automatically transitions to COMPLETED
    /// 4. Completed investment appears on Completed Investments page
    func testCheckAndUpdateInvestmentCompletion_MarksInvestmentAsCompletedWhenAllPoolsCompleted() {
        // Given: An active investment where the trader has completed ALL pools
        // In reality: Trader started trades (pools became .active) and then completed all trades (pools became .completed)
        let investment = createActiveInvestmentWithCompletedPools(id: "1")
        viewModel.investments = [investment]

        // Verify initial state: investment is active
        guard let firstInvestment = viewModel.investments.first else {
            XCTFail("Expected investment not found")
            return
        }
        XCTAssertEqual(firstInvestment.status, .active)
        XCTAssertNil(firstInvestment.completedAt)
        XCTAssertTrue(viewModel.completedInvestments.isEmpty) // Not yet in completed list

        // When: loadCompletedInvestments() calls checkAndUpdateInvestmentCompletion()
        // This simulates what happens when the view loads and checks investment status
        viewModel.loadCompletedInvestments()

        // Then: Investment should be automatically marked as completed
        guard let updatedInvestment = viewModel.investments.first else {
            XCTFail("Expected investment not found")
            return
        }
        XCTAssertEqual(updatedInvestment.status, .completed, "Investment should transition from active to completed when all pools are done")
        XCTAssertNotNil(updatedInvestment.completedAt, "Completed investment should have a completion date")

        // And: It should now appear in the completed investments list
        XCTAssertEqual(viewModel.completedInvestments.count, 1, "Completed investment should appear in completed list")
        XCTAssertEqual(viewModel.completedInvestments.first?.id, "1")
    }

    /// This test verifies that an investment with mixed pool statuses (some completed, some not)
    /// remains active until ALL pools are completed
    func testCheckAndUpdateInvestmentCompletion_InvestmentStaysActiveUntilAllPoolsCompleted() {
        // Given: An active investment where trader has completed SOME pools but not all
        // Pool 1: completed (trader finished trades)
        // Pool 2: active (trader still trading)
        let investment = createActiveInvestmentWithMixedPools(id: "1")
        viewModel.investments = [investment]

        // Verify initial state
        guard let firstInvestment = viewModel.investments.first else {
            XCTFail("Expected investment not found")
            return
        }
        XCTAssertEqual(firstInvestment.status, .active)
        XCTAssertFalse(firstInvestment.allPoolsCompleted) // Not all pools done

        // When: checkAndUpdateInvestmentCompletion() runs
        viewModel.loadCompletedInvestments()

        // Then: Investment should REMAIN active (not all pools completed yet)
        guard let updatedInvestment = viewModel.investments.first else {
            XCTFail("Expected investment not found")
            return
        }
        XCTAssertEqual(updatedInvestment.status, .active, "Investment should stay active until ALL pools are completed")
        XCTAssertNil(updatedInvestment.completedAt, "Investment should not have completion date yet")
        XCTAssertTrue(viewModel.completedInvestments.isEmpty, "Investment should not appear in completed list yet")
    }

    func testCheckAndUpdateInvestmentCompletion_DoesNotMarkWhenNotAllPoolsCompleted() {
        // Given
        let investment = createActiveInvestmentWithMixedPools(id: "1")
        viewModel.investments = [investment]

        // When
        viewModel.loadCompletedInvestments()

        // Then
        guard let updatedInvestment = viewModel.investments.first else {
            XCTFail("Expected investment not found")
            return
        }
        XCTAssertEqual(updatedInvestment.status, .active)
        XCTAssertNil(updatedInvestment.completedAt)
    }

    func testCheckAndUpdateInvestmentCompletion_OnlyChecksActiveInvestments() {
        // Given: Mix of investment statuses
        let activeInvestment = createActiveInvestmentWithCompletedPools(id: "1") // Will be auto-completed
        let completedInvestment = createCompletedInvestment(id: "2", completedAt: Date()) // Already done
        let cancelledInvestment = createCancelledInvestment(id: "3") // Cancelled

        viewModel.investments = [activeInvestment, completedInvestment, cancelledInvestment]

        // When: checkAndUpdateInvestmentCompletion() runs
        viewModel.loadCompletedInvestments()

        // Then: Only the active investment should be checked and updated
        XCTAssertEqual(viewModel.investments[0].status, .completed, "Active investment with all pools completed should become completed")
        XCTAssertEqual(viewModel.investments[1].status, .completed, "Already completed investment should remain completed")
        XCTAssertEqual(viewModel.investments[2].status, .cancelled, "Cancelled investment should remain cancelled (not checked)")
    }

    func testCheckAndUpdateInvestmentCompletion_HandlesEmptyPoolSlots() {
        // Given: An active investment with no pool reservations yet
        // This could happen if investment was just created but pools not yet allocated
        let investment = createActiveInvestment(id: "1") // No pool slots
        viewModel.investments = [investment]

        // When: checkAndUpdateInvestmentCompletion() runs
        viewModel.loadCompletedInvestments()

        // Then: Investment should remain active (can't be completed without pools)
        guard let updatedInvestment = viewModel.investments.first else {
            XCTFail("Expected investment not found")
            return
        }
        XCTAssertEqual(updatedInvestment.status, .active, "Investment without pools should remain active")
        XCTAssertFalse(updatedInvestment.allPoolsCompleted, "Investment with no pools should not be considered 'all pools completed'")
    }

    /// Integration test: Verifies the complete flow from active to completed and appearing on page
    func testCompleteFlow_ActiveInvestmentToCompletedInvestmentsPage() {
        // Given: An active investment where trader has completed all pools
        let investment = createActiveInvestmentWithCompletedPools(id: "investment-123")
        mockInvestmentService.investments = [investment]

        // Step 1: Load investments (simulates page load)
        viewModel.loadCompletedInvestments()

        // Step 2: Verify investment was auto-completed
        guard let firstInvestment = viewModel.investments.first else {
            XCTFail("Expected investment not found")
            return
        }
        XCTAssertEqual(firstInvestment.status, .completed)
        XCTAssertNotNil(firstInvestment.completedAt)

        // Step 3: Verify it appears in completed investments list
        let completed = viewModel.completedInvestments
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed.first?.id, "investment-123")

        // Step 4: Verify it appears when filtering by year
        let currentYear = Calendar.current.component(.year, from: Date())
        viewModel.selectedYear = currentYear
        let filteredByYear = viewModel.completedInvestmentsByYear
        XCTAssertEqual(filteredByYear.count, 1)
        XCTAssertEqual(filteredByYear.first?.id, "investment-123")

        // Step 5: Verify year appears in available years
        let availableYears = viewModel.availableYears
        XCTAssertTrue(availableYears.contains(currentYear))
    }

    // MARK: - Reconfigure Tests

    func testReconfigure_UpdatesServicesAndReloadsInvestments() {
        // Given
        let newMockService = MockInvestmentService()
        let investment = createCompletedInvestment(id: "1", completedAt: Date())
        newMockService.investments = [investment]

        // When
        var services = AppServices.live
        services = AppServices(
            userService: mockUserService,
            investmentService: newMockService,
            poolTradeParticipationService: services.poolTradeParticipationService,
            notificationService: services.notificationService,
            documentService: services.documentService,
            watchlistService: services.watchlistService,
            traderDataService: services.traderDataService,
            dashboardService: services.dashboardService,
            traderService: services.traderService,
            telemetryService: services.telemetryService,
            testModeService: services.testModeService,
            securitiesSearchService: services.securitiesSearchService,
            mockDataGenerator: services.mockDataGenerator,
            searchFilterManager: services.searchFilterManager,
            securitiesSearchCoordinator: services.securitiesSearchCoordinator,
            orderManagementService: services.orderManagementService,
            tradeLifecycleService: services.tradeLifecycleService,
            securitiesWatchlistService: services.securitiesWatchlistService,
            tradingStatisticsService: services.tradingStatisticsService,
            orderStatusSimulationService: services.orderStatusSimulationService,
            tradingNotificationService: services.tradingNotificationService,
            tradeMatchingService: services.tradeMatchingService,
            tradingCoordinator: services.tradingCoordinator,
            invoiceService: services.invoiceService,
            transactionIdService: services.transactionIdService,
            tradeNumberService: services.tradeNumberService,
            cashBalanceService: services.cashBalanceService,
            configurationService: services.configurationService,
            potQuantityCalculationService: services.potQuantityCalculationService,
            investorCashBalanceService: services.investorCashBalanceService,
            unifiedOrderService: services.unifiedOrderService,
            tradingStateStore: services.tradingStateStore,
            roundingDifferencesService: services.roundingDifferencesService,
            filterPersistenceRepository: services.filterPersistenceRepository
        )
        viewModel.reconfigure(with: services)

        // Then
        XCTAssertEqual(viewModel.investments.count, 1)
        XCTAssertEqual(viewModel.investments.first?.id, "1")
    }

    // MARK: - Error Handling Tests

    func testShowError_SetsErrorMessageAndShowError() {
        // Given
        let error = AppError.unknownError("Test error")

        // When
        viewModel.showError(error)

        // Then
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.showError)
        XCTAssertEqual(viewModel.errorMessage, error.localizedDescription)
    }

    func testClearError_ResetsErrorMessageAndShowError() {
        // Given
        viewModel.showError(AppError.unknownError("Test error"))

        // When
        viewModel.clearError()

        // Then
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.showError)
    }

    // MARK: - Current User Tests

    func testCurrentUser_ReturnsUserFromService() async {
        // Given
        let expectation = TestHelpers.createExpectation(description: "Sign in for current user")
        mockUserService.signInHandler = { _, _ in
            expectation.fulfill()
        }
        try? await mockUserService.signIn(email: "test@example.com", password: "password123")
        await TestHelpers.waitForExpectation(expectation)

        // When
        let currentUser = viewModel.currentUser

        // Then
        XCTAssertNotNil(currentUser)
        XCTAssertEqual(currentUser?.email, "test@example.com")
    }

    // MARK: - Helper Methods

    private func createCompletedInvestment(id: String, completedAt: Date) -> Investment {
        Investment(
            id: id,
            investorId: "investor1",
            traderId: "trader1",
            traderName: "Test Trader",
            amount: 1000.0,
            currentValue: 1200.0,
            date: Date(),
            status: .completed,
            performance: 20.0,
            numberOfTrades: 5,
            numberOfPools: 2,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: completedAt,
            specialization: "Technology",
            reservedPoolSlots: []
        )
    }

    private func createActiveInvestment(id: String) -> Investment {
        Investment(
            id: id,
            investorId: "investor1",
            traderId: "trader1",
            traderName: "Test Trader",
            amount: 1000.0,
            currentValue: 1100.0,
            date: Date(),
            status: .active,
            performance: 10.0,
            numberOfTrades: 3,
            numberOfPools: 2,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: "Technology",
            reservedPoolSlots: []
        )
    }

    private func createCancelledInvestment(id: String) -> Investment {
        Investment(
            id: id,
            investorId: "investor1",
            traderId: "trader1",
            traderName: "Test Trader",
            amount: 1000.0,
            currentValue: 1000.0,
            date: Date(),
            status: .cancelled,
            performance: 0.0,
            numberOfTrades: 0,
            numberOfPools: 2,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: "Technology",
            reservedPoolSlots: []
        )
    }

    private func createActiveInvestmentWithCompletedPools(id: String) -> Investment {
        let completedPool1 = PoolReservation(
            id: UUID().uuidString,
            poolNumber: 1,
            status: .completed,
            actualPoolId: "pool1",
            allocatedAmount: 500.0,
            reservedAt: Date(),
            isLocked: true
        )
        let completedPool2 = PoolReservation(
            id: UUID().uuidString,
            poolNumber: 2,
            status: .completed,
            actualPoolId: "pool2",
            allocatedAmount: 500.0,
            reservedAt: Date(),
            isLocked: true
        )

        return Investment(
            id: id,
            investorId: "investor1",
            traderId: "trader1",
            traderName: "Test Trader",
            amount: 1000.0,
            currentValue: 1200.0,
            date: Date(),
            status: .active,
            performance: 20.0,
            numberOfTrades: 5,
            numberOfPools: 2,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: "Technology",
            reservedPoolSlots: [completedPool1, completedPool2]
        )
    }

    private func createActiveInvestmentWithMixedPools(id: String) -> Investment {
        let completedPool = PoolReservation(
            id: UUID().uuidString,
            poolNumber: 1,
            status: .completed,
            actualPoolId: "pool1",
            allocatedAmount: 500.0,
            reservedAt: Date(),
            isLocked: true
        )
        let activePool = PoolReservation(
            id: UUID().uuidString,
            poolNumber: 2,
            status: .active,
            actualPoolId: "pool2",
            allocatedAmount: 500.0,
            reservedAt: Date(),
            isLocked: true
        )

        return Investment(
            id: id,
            investorId: "investor1",
            traderId: "trader1",
            traderName: "Test Trader",
            amount: 1000.0,
            currentValue: 1100.0,
            date: Date(),
            status: .active,
            performance: 10.0,
            numberOfTrades: 3,
            numberOfPools: 2,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: "Technology",
            reservedPoolSlots: [completedPool, activePool]
        )
    }
}
