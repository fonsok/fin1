import XCTest
@testable import FIN1

/// Comprehensive end-to-end test for the investment pool completion flow
///
/// This test verifies the complete process:
/// 1. Investor creates investment with multiple pools
/// 2. Trader places buy/sell orders
/// 3. Pool reservations update step by step (reserved → active → completed)
/// 4. Investment automatically completes when all pools are done
/// 5. Completed investment appears on Completed Investments page
final class InvestmentPoolCompletionFlowTests: XCTestCase {
    var mockUserService: MockUserService!
    var mockInvestmentService: MockInvestmentService!
    var completedInvestmentsViewModel: CompletedInvestmentsViewModel!
    var investorPortfolioViewModel: InvestorPortfolioViewModel!
    var investor: User!
    var trader: MockTrader!

    override func setUp() {
        super.setUp()
        mockUserService = MockUserService()
        mockInvestmentService = MockInvestmentService()
        completedInvestmentsViewModel = CompletedInvestmentsViewModel(
            userService: mockUserService,
            investmentService: mockInvestmentService,
            documentService: MockDocumentService(),
            invoiceService: MockInvoiceService(),
            traderDataService: MockTraderDataService(),
            poolTradeParticipationService: MockPoolTradeParticipationService(),
            tradeLifecycleService: MockTradeLifecycleService(),
            configurationService: MockConfigurationService(),
            commissionCalculationService: CommissionCalculationService()
        )
        investorPortfolioViewModel = InvestorPortfolioViewModel(
            userService: mockUserService,
            investmentService: mockInvestmentService
        )
    }

    override func tearDown() {
        mockInvestmentService.reset()
        completedInvestmentsViewModel = nil
        investorPortfolioViewModel = nil
        mockUserService = nil
        mockInvestmentService = nil
        investor = nil
        trader = nil
        super.tearDown()
    }

    // MARK: - Complete End-to-End Flow Test

    /// Tests the complete flow from investment creation to completion
    ///
    /// Flow:
    /// 1. Investor creates investment with 3 pools (€500 each = €1500 total)
    /// 2. All pools start as `.reserved` (Status 1)
    /// 3. Trader starts trading Pool 1 → status becomes `.active` (Status 2)
    /// 4. Trader completes Pool 1 trades → status becomes `.completed` (Status 3)
    /// 5. Trader starts trading Pool 2 → status becomes `.active`
    /// 6. Trader completes Pool 2 trades → status becomes `.completed`
    /// 7. Trader starts trading Pool 3 → status becomes `.active`
    /// 8. Trader completes Pool 3 trades → status becomes `.completed`
    /// 9. Investment automatically transitions to `.completed` (all pools done)
    /// 10. Completed investment appears on Completed Investments page
    func testCompleteInvestmentPoolFlow_StepByStep() async throws {
        // MARK: Step 1: Setup - Create Investor and Trader
        let investorExpectation = TestHelpers.createExpectation(description: "Investor sign in")
        try? await mockUserService.signIn(email: "investor@example.com", password: "password123")
        investor = mockUserService.currentUser
        XCTAssertNotNil(investor, "Investor should be created")
        XCTAssertEqual(investor?.role, .investor, "User should be an investor")

        trader = TestHelpers.createMockTrader()
        XCTAssertNotNil(trader, "Trader should be created")

        // MARK: Step 2: Investor Creates Investment with Multiple Pools
        let amountPerPool = 500.0
        let numberOfPools = 3
        let totalAmount = amountPerPool * Double(numberOfPools) // €1500

        // Configure mock to create investment with pool reservations
        mockInvestmentService.createInvestmentHandler = { investor, trader, amountPerPool, numberOfPools, specialization, _ in
            let investment = self.createInvestmentWithPoolReservations(
                investor: investor,
                trader: trader,
                amountPerPool: amountPerPool,
                numberOfPools: numberOfPools,
                specialization: specialization
            )
            await MainActor.run {
                self.mockInvestmentService.investments.append(investment)
            }
        }

        let createExpectation = TestHelpers.createExpectation(description: "Investment creation")
        try await mockInvestmentService.createInvestment(
            investor: investor,
            trader: trader,
            amountPerPool: amountPerPool,
            numberOfPools: numberOfPools,
            specialization: trader.specialization,
            poolSelection: .multiplePools
        )
        createExpectation.fulfill()
        await TestHelpers.waitForExpectation(createExpectation)

        // Verify investment was created
        XCTAssertEqual(mockInvestmentService.investments.count, 1, "Investment should be created")
        guard var investment = mockInvestmentService.investments.first else {
            XCTFail("Investment should exist")
            return
        }

        // Verify initial state: investment is active with all pools reserved
        XCTAssertEqual(investment.status, .active, "Investment should start as active")
        XCTAssertEqual(investment.amount, totalAmount, "Investment amount should be €1500")
        XCTAssertEqual(investment.numberOfPools, numberOfPools, "Investment should have 3 pools")
        XCTAssertEqual(investment.reservedPoolSlots.count, numberOfPools, "Investment should have 3 pool reservations")

        // Verify all pools start as `.reserved` (Status 1)
        for (index, pool) in investment.reservedPoolSlots.enumerated() {
            XCTAssertEqual(pool.status, .reserved, "Pool \(index + 1) should start as reserved")
            XCTAssertEqual(pool.poolNumber, index + 1, "Pool number should be \(index + 1)")
            XCTAssertEqual(pool.allocatedAmount, amountPerPool, "Pool \(index + 1) should have €500 allocated")
        }

        // MARK: Step 3: Trader Starts Trading Pool 1
        // Simulate: Trader sees pool is available and starts trading
        // Pool 1 status: `.reserved` → `.active` (Status 2)
        investment = updatePoolStatus(investment: investment, poolNumber: 1, newStatus: .active)
        mockInvestmentService.investments[0] = investment

        // Verify Pool 1 is now active
        let pool1AfterStart = investment.reservedPoolSlots.first { $0.poolNumber == 1 }
        XCTAssertEqual(pool1AfterStart?.status, .active, "Pool 1 should be active after trader starts trading")
        XCTAssertEqual(investment.status, .active, "Investment should still be active (not all pools done)")

        // MARK: Step 4: Trader Completes Trades for Pool 1
        // Simulate: Trader completes all trades involving Pool 1
        // Pool 1 status: `.active` → `.completed` (Status 3)
        investment = updatePoolStatus(investment: investment, poolNumber: 1, newStatus: .completed)
        mockInvestmentService.investments[0] = investment

        // Verify Pool 1 is completed, but investment still active (other pools not done)
        let pool1AfterComplete = investment.reservedPoolSlots.first { $0.poolNumber == 1 }
        XCTAssertEqual(pool1AfterComplete?.status, .completed, "Pool 1 should be completed")
        XCTAssertEqual(investment.status, .active, "Investment should still be active (waiting for other pools)")

        // MARK: Step 5: Trader Starts Trading Pool 2
        // Pool 2 status: `.reserved` → `.active` (Status 2)
        investment = updatePoolStatus(investment: investment, poolNumber: 2, newStatus: .active)
        mockInvestmentService.investments[0] = investment

        // Verify Pool 2 is active
        let pool2AfterStart = investment.reservedPoolSlots.first { $0.poolNumber == 2 }
        XCTAssertEqual(pool2AfterStart?.status, .active, "Pool 2 should be active")
        XCTAssertEqual(investment.status, .active, "Investment should still be active")

        // MARK: Step 6: Trader Completes Trades for Pool 2
        // Pool 2 status: `.active` → `.completed` (Status 3)
        investment = updatePoolStatus(investment: investment, poolNumber: 2, newStatus: .completed)
        mockInvestmentService.investments[0] = investment

        // Verify Pool 2 is completed, but investment still active (Pool 3 not done)
        let pool2AfterComplete = investment.reservedPoolSlots.first { $0.poolNumber == 2 }
        XCTAssertEqual(pool2AfterComplete?.status, .completed, "Pool 2 should be completed")
        XCTAssertEqual(investment.status, .active, "Investment should still be active (waiting for Pool 3)")

        // MARK: Step 7: Trader Starts Trading Pool 3
        // Pool 3 status: `.reserved` → `.active` (Status 2)
        investment = updatePoolStatus(investment: investment, poolNumber: 3, newStatus: .active)
        mockInvestmentService.investments[0] = investment

        // Verify Pool 3 is active
        let pool3AfterStart = investment.reservedPoolSlots.first { $0.poolNumber == 3 }
        XCTAssertEqual(pool3AfterStart?.status, .active, "Pool 3 should be active")
        XCTAssertEqual(investment.status, .active, "Investment should still be active")

        // MARK: Step 8: Trader Completes Trades for Pool 3
        // Pool 3 status: `.active` → `.completed` (Status 3)
        investment = updatePoolStatus(investment: investment, poolNumber: 3, newStatus: .completed)
        mockInvestmentService.investments[0] = investment

        // Verify all pools are now completed
        let allPoolsCompleted = investment.reservedPoolSlots.allSatisfy { $0.status == .completed }
        XCTAssertTrue(allPoolsCompleted, "All pools should be completed")
        XCTAssertTrue(investment.allPoolsCompleted, "Investment should report all pools completed")

        // MARK: Step 9: Investment Automatically Completes
        // Load investments to trigger checkAndUpdateInvestmentCompletion()
        completedInvestmentsViewModel.investments = mockInvestmentService.investments
        completedInvestmentsViewModel.loadCompletedInvestments()

        // Verify investment is now completed
        guard let updatedInvestment = completedInvestmentsViewModel.investments.first else {
            XCTFail("Expected investment not found")
            return
        }
        XCTAssertEqual(updatedInvestment.status, .completed, "Investment should automatically transition to completed")
        XCTAssertNotNil(updatedInvestment.completedAt, "Completed investment should have completion date")

        // MARK: Step 10: Completed Investment Appears on Completed Investments Page
        let completedInvestments = completedInvestmentsViewModel.completedInvestments
        XCTAssertEqual(completedInvestments.count, 1, "Completed investment should appear in completed list")
        XCTAssertEqual(completedInvestments.first?.id, investment.id, "Completed investment should match original investment")
        XCTAssertEqual(completedInvestments.first?.status, .completed, "Investment in completed list should have completed status")

        // Verify year filtering works
        let currentYear = Calendar.current.component(.year, from: Date())
        completedInvestmentsViewModel.selectedYear = currentYear
        let filteredByYear = completedInvestmentsViewModel.completedInvestmentsByYear
        XCTAssertEqual(filteredByYear.count, 1, "Completed investment should appear when filtered by year")
        XCTAssertTrue(completedInvestmentsViewModel.availableYears.contains(currentYear), "Current year should be in available years")
    }

    // MARK: - Helper Methods

    /// Creates an investment with pool reservations in `.reserved` status
    private func createInvestmentWithPoolReservations(
        investor: User,
        trader: MockTrader,
        amountPerPool: Double,
        numberOfPools: Int,
        specialization: String
    ) -> Investment {
        let totalAmount = amountPerPool * Double(numberOfPools)

        // Create pool reservations (all starting as `.reserved`)
        var poolReservations: [PoolReservation] = []
        for poolIndex in 0..<numberOfPools {
            let reservation = PoolReservation(
                id: UUID().uuidString,
                poolNumber: poolIndex + 1,
                status: .reserved, // Status 1: Initial/reserved state
                actualPoolId: nil,
                allocatedAmount: amountPerPool,
                reservedAt: Date(),
                isLocked: false
            )
            poolReservations.append(reservation)
        }

        return Investment(
            id: UUID().uuidString,
            investorId: investor.id,
            traderId: trader.id.uuidString,
            traderName: trader.name,
            amount: totalAmount,
            currentValue: totalAmount,
            date: Date(),
            status: .active,
            performance: 0.0,
            numberOfTrades: 0,
            numberOfPools: numberOfPools,
            createdAt: Date(),
            updatedAt: Date(),
            completedAt: nil,
            specialization: specialization,
            reservedPoolSlots: poolReservations
        )
    }

    /// Updates the status of a specific pool reservation in an investment
    private func updatePoolStatus(
        investment: Investment,
        poolNumber: Int,
        newStatus: PoolReservationStatus
    ) -> Investment {
        var updatedReservations = investment.reservedPoolSlots
        if let index = updatedReservations.firstIndex(where: { $0.poolNumber == poolNumber }) {
            let oldReservation = updatedReservations[index]
            let updatedReservation = PoolReservation(
                id: oldReservation.id,
                poolNumber: oldReservation.poolNumber,
                status: newStatus,
                actualPoolId: oldReservation.actualPoolId,
                allocatedAmount: oldReservation.allocatedAmount,
                reservedAt: oldReservation.reservedAt,
                isLocked: newStatus != .reserved // Lock when active or completed
            )
            updatedReservations[index] = updatedReservation
        }

        return Investment(
            id: investment.id,
            investorId: investment.investorId,
            traderId: investment.traderId,
            traderName: investment.traderName,
            amount: investment.amount,
            currentValue: investment.currentValue,
            date: investment.date,
            status: investment.status,
            performance: investment.performance,
            numberOfTrades: investment.numberOfTrades,
            numberOfPools: investment.numberOfPools,
            createdAt: investment.createdAt,
            updatedAt: Date(),
            completedAt: investment.completedAt,
            specialization: investment.specialization,
            reservedPoolSlots: updatedReservations
        )
    }
}
