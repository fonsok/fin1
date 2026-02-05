import XCTest
@testable import FIN1

// MARK: - Cash Balance Validation Tests

/// Tests for cash balance validation in buy orders
/// Ensures traders cannot place buy orders that would result in balance < 20
class CashBalanceValidationTests: XCTestCase {

    var cashBalanceService: CashBalanceService!
    var mockTraderService: MockTraderService!
    var buyOrderViewModel: BuyOrderViewModel!
    var searchResult: SearchResult!

    override func setUp() {
        super.setUp()
        cashBalanceService = CashBalanceService()
        mockTraderService = MockTraderService()

        // Create a test search result
        searchResult = SearchResult(
            wkn: "TEST123",
            underlyingAsset: "Test Asset",
            askPrice: "10,00",
            bidPrice: "9,50",
            direction: "Call",
            strike: "100,00",
            expiryDate: "2024-12-31"
        )

        buyOrderViewModel = BuyOrderViewModel(
            searchResult: searchResult,
            traderService: mockTraderService,
            cashBalanceService: cashBalanceService
        )
    }

    override func tearDown() {
        cashBalanceService = nil
        mockTraderService = nil
        buyOrderViewModel = nil
        searchResult = nil
        super.tearDown()
    }

    // MARK: - CashBalanceService Tests

    func testEstimatedBalanceAfterPurchase() {
        // Given: Current balance of 1000
        cashBalanceService.currentBalance = 1000.0

        // When: Calculate estimated balance after purchase of 500
        let estimatedBalance = cashBalanceService.estimatedBalanceAfterPurchase(amount: 500.0)

        // Then: Should be 500
        XCTAssertEqual(estimatedBalance, 500.0, "Estimated balance should be current balance minus purchase amount")
    }

    func testHasSufficientFundsWithDefaultMinimum() {
        // Given: Current balance of 1000
        cashBalanceService.currentBalance = 1000.0

        // When: Check if sufficient funds for purchase of 950 (would leave 50, above minimum of 20)
        let hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: 950.0)

        // Then: Should have sufficient funds
        XCTAssertTrue(hasSufficientFunds, "Should have sufficient funds when estimated balance (50) >= minimum (20)")
    }

    func testHasInsufficientFundsWithDefaultMinimum() {
        // Given: Current balance of 1000
        cashBalanceService.currentBalance = 1000.0

        // When: Check if sufficient funds for purchase of 990 (would leave 10, below minimum of 20)
        let hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: 990.0)

        // Then: Should not have sufficient funds
        XCTAssertFalse(hasSufficientFunds, "Should not have sufficient funds when estimated balance (10) < minimum (20)")
    }

    func testHasSufficientFundsWithCustomMinimum() {
        // Given: Current balance of 1000
        cashBalanceService.currentBalance = 1000.0

        // When: Check if sufficient funds for purchase of 900 with custom minimum of 50
        let hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: 900.0, minimumReserve: 50.0)

        // Then: Should have sufficient funds (estimated balance 100 >= minimum 50)
        XCTAssertTrue(hasSufficientFunds, "Should have sufficient funds when estimated balance (100) >= custom minimum (50)")
    }

    func testHasInsufficientFundsWithCustomMinimum() {
        // Given: Current balance of 1000
        cashBalanceService.currentBalance = 1000.0

        // When: Check if sufficient funds for purchase of 960 with custom minimum of 50
        let hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: 960.0, minimumReserve: 50.0)

        // Then: Should not have sufficient funds (estimated balance 40 < minimum 50)
        XCTAssertFalse(hasSufficientFunds, "Should not have sufficient funds when estimated balance (40) < custom minimum (50)")
    }

    func testExactMinimumBalance() {
        // Given: Current balance of 1000
        cashBalanceService.currentBalance = 1000.0

        // When: Check if sufficient funds for purchase of 980 (would leave exactly 20)
        let hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: 980.0, minimumReserve: 20.0)

        // Then: Should have sufficient funds (estimated balance 20 == minimum 20)
        XCTAssertTrue(hasSufficientFunds, "Should have sufficient funds when estimated balance equals minimum")
    }

    // MARK: - BuyOrderViewModel Tests

    func testCanPlaceOrderWithSufficientFunds() {
        // Given: Sufficient funds scenario
        cashBalanceService.currentBalance = 1000.0
        buyOrderViewModel.quantity = 50.0 // Cost would be 50 * 10.00 = 500, leaving 500 (well above 20)

        // When: Check if can place order
        let canPlaceOrder = buyOrderViewModel.canPlaceOrder

        // Then: Should be able to place order
        XCTAssertTrue(canPlaceOrder, "Should be able to place order when sufficient funds available")
        XCTAssertFalse(buyOrderViewModel.showInsufficientFundsWarning, "Should not show insufficient funds warning")
    }

    func testCannotPlaceOrderWithInsufficientFunds() {
        // Given: Insufficient funds scenario
        cashBalanceService.currentBalance = 100.0
        buyOrderViewModel.quantity = 10.0 // Cost would be 10 * 10.00 = 100, leaving 0 (below minimum of 20)

        // When: Check if can place order
        let canPlaceOrder = buyOrderViewModel.canPlaceOrder

        // Then: Should not be able to place order
        XCTAssertFalse(canPlaceOrder, "Should not be able to place order when insufficient funds")
        XCTAssertTrue(buyOrderViewModel.showInsufficientFundsWarning, "Should show insufficient funds warning")
    }

    func testInsufficientFundsMessage() {
        // Given: Insufficient funds scenario
        cashBalanceService.currentBalance = 100.0
        buyOrderViewModel.quantity = 10.0 // Cost would be 10 * 10.00 = 100, leaving 0

        // When: Get insufficient funds message
        let message = buyOrderViewModel.insufficientFundsMessage

        // Then: Should contain relevant information
        XCTAssertTrue(message.contains("Insufficient funds"), "Message should indicate insufficient funds")
        XCTAssertTrue(message.contains("€100"), "Message should show current balance")
        XCTAssertTrue(message.contains("€0"), "Message should show estimated balance")
        XCTAssertTrue(message.contains("€20"), "Message should show shortfall amount")
    }

    func testHasInsufficientFundsComputedProperty() {
        // Given: Insufficient funds scenario
        cashBalanceService.currentBalance = 100.0
        buyOrderViewModel.quantity = 10.0 // Cost would be 10 * 10.00 = 100, leaving 0

        // When: Check hasInsufficientFunds
        let hasInsufficientFunds = buyOrderViewModel.hasInsufficientFunds

        // Then: Should indicate insufficient funds
        XCTAssertTrue(hasInsufficientFunds, "Should indicate insufficient funds when estimated balance < 20")
    }

    func testValidationWithDifferentQuantities() {
        // Given: Current balance of 1000
        cashBalanceService.currentBalance = 1000.0

        // Test cases: (quantity, expectedCanPlaceOrder, expectedWarning)
        let testCases: [(Double, Bool, Bool)] = [
            (50.0, true, false),   // Cost: 500, Balance: 500 (sufficient)
            (90.0, true, false),   // Cost: 900, Balance: 100 (sufficient)
            (95.0, true, false),   // Cost: 950, Balance: 50 (sufficient)
            (98.0, true, false),   // Cost: 980, Balance: 20 (exactly minimum)
            (99.0, false, true),   // Cost: 990, Balance: 10 (insufficient)
            (100.0, false, true)  // Cost: 1000, Balance: 0 (insufficient)
        ]

        for (quantity, expectedCanPlace, expectedWarning) in testCases {
            // When: Set quantity and check validation
            buyOrderViewModel.quantity = quantity
            let canPlaceOrder = buyOrderViewModel.canPlaceOrder
            let showWarning = buyOrderViewModel.showInsufficientFundsWarning

            // Then: Should match expected results
            XCTAssertEqual(canPlaceOrder, expectedCanPlace, "Quantity \(quantity) should have canPlaceOrder = \(expectedCanPlace)")
            XCTAssertEqual(showWarning, expectedWarning, "Quantity \(quantity) should have warning = \(expectedWarning)")
        }
    }

    func testValidationWithLimitOrders() {
        // Given: Sufficient funds and limit order
        cashBalanceService.currentBalance = 1000.0
        buyOrderViewModel.orderMode = .limit
        buyOrderViewModel.limit = "5,00" // Lower limit price
        buyOrderViewModel.quantity = 100.0 // Cost would be 100 * 5.00 = 500, leaving 500 (sufficient)

        // When: Check if can place order
        let canPlaceOrder = buyOrderViewModel.canPlaceOrder

        // Then: Should be able to place order (uses limit price for cost calculation)
        XCTAssertTrue(canPlaceOrder, "Should be able to place limit order when sufficient funds available")
        XCTAssertFalse(buyOrderViewModel.showInsufficientFundsWarning, "Should not show insufficient funds warning")
    }

    func testValidationWithHighLimitPrice() {
        // Given: Insufficient funds with high limit price
        cashBalanceService.currentBalance = 1000.0
        buyOrderViewModel.orderMode = .limit
        buyOrderViewModel.limit = "15,00" // Higher limit price
        buyOrderViewModel.quantity = 100.0 // Cost would be 100 * 15.00 = 1500, leaving -500 (insufficient)

        // When: Check if can place order
        let canPlaceOrder = buyOrderViewModel.canPlaceOrder

        // Then: Should not be able to place order
        XCTAssertFalse(canPlaceOrder, "Should not be able to place limit order when insufficient funds")
        XCTAssertTrue(buyOrderViewModel.showInsufficientFundsWarning, "Should show insufficient funds warning")
    }

    // MARK: - Edge Cases

    func testZeroBalance() {
        // Given: Zero balance
        cashBalanceService.currentBalance = 0.0
        buyOrderViewModel.quantity = 1.0 // Any purchase would be insufficient

        // When: Check if can place order
        let canPlaceOrder = buyOrderViewModel.canPlaceOrder

        // Then: Should not be able to place order
        XCTAssertFalse(canPlaceOrder, "Should not be able to place order with zero balance")
        XCTAssertTrue(buyOrderViewModel.showInsufficientFundsWarning, "Should show insufficient funds warning")
    }

    func testNegativeBalance() {
        // Given: Negative balance (edge case)
        cashBalanceService.currentBalance = -100.0
        buyOrderViewModel.quantity = 1.0 // Any purchase would make it worse

        // When: Check if can place order
        let canPlaceOrder = buyOrderViewModel.canPlaceOrder

        // Then: Should not be able to place order
        XCTAssertFalse(canPlaceOrder, "Should not be able to place order with negative balance")
        XCTAssertTrue(buyOrderViewModel.showInsufficientFundsWarning, "Should show insufficient funds warning")
    }

    func testVerySmallPurchase() {
        // Given: Large balance with very small purchase
        cashBalanceService.currentBalance = 10000.0
        buyOrderViewModel.quantity = 0.1 // Very small quantity

        // When: Check if can place order
        let canPlaceOrder = buyOrderViewModel.canPlaceOrder

        // Then: Should be able to place order (leaves plenty of balance)
        XCTAssertTrue(canPlaceOrder, "Should be able to place very small order with large balance")
        XCTAssertFalse(buyOrderViewModel.showInsufficientFundsWarning, "Should not show insufficient funds warning")
    }
}

// MARK: - Mock Services
