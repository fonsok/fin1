import XCTest
@testable import FIN1

// MARK: - Integration Test for Basiswert Flow
// This test ensures that the complete flow from basiswert selection to order creation works correctly

class BasiswertFlowIntegrationTest: XCTestCase {

    var mockDataGenerator: MockDataGenerator!
    var traderService: TraderService!
    var tradingCoordinator: TradingCoordinator!

    override func setUp() {
        super.setUp()
        mockDataGenerator = MockDataGenerator()
        let mockUserService = MockUserService()
        let mockTraderDataService = MockTraderDataService()
        let mockConfigurationService = ConfigurationService(userService: mockUserService)
        let commissionCalculationService = CommissionCalculationService()
        let traderCashBalanceService = TraderCashBalanceService(configurationService: mockConfigurationService)
        let orderLifecycleCoordinator = OrderLifecycleCoordinator(
            orderManagementService: OrderManagementService.shared,
            orderStatusSimulationService: OrderStatusSimulationService.shared,
            tradingNotificationService: TradingNotificationService.shared,
            tradeLifecycleService: TradeLifecycleService.shared,
            tradeMatchingService: TradeMatchingService(),
            cashBalanceService: CashBalanceService(),
            investmentService: nil,
            userService: mockUserService,
            traderDataService: mockTraderDataService,
            commissionCalculationService: commissionCalculationService,
            traderCashBalanceService: traderCashBalanceService
        )
        let tradingStateStore = LegacyTradingStateStore(
            orderManagementService: OrderManagementService.shared,
            tradeLifecycleService: TradeLifecycleService.shared,
            securitiesWatchlistService: SecuritiesWatchlistService.shared,
            orderStatusSimulationService: OrderStatusSimulationService.shared
        )
        let tradingStatisticsService = TradingStatisticsService()

        tradingCoordinator = TradingCoordinator(
            tradingStateStore: tradingStateStore,
            orderLifecycleCoordinator: orderLifecycleCoordinator,
            tradeLifecycleCoordinator: TradeLifecycleCoordinator(tradeLifecycleService: TradeLifecycleService.shared),
            securitiesWatchlistService: SecuritiesWatchlistService.shared,
            tradingStatisticsService: tradingStatisticsService
        )
        traderService = TraderService(tradingCoordinator: tradingCoordinator)
    }

    override func tearDown() {
        mockDataGenerator = nil
        traderService = nil
        tradingCoordinator = nil
        super.tearDown()
    }

    // MARK: - Test Cases

    func testBasiswertFlow_Apple() async throws {
        // Given: User selects "Apple" as basiswert
        let filters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "Apple",
            direction: .call,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        // When: Search results are generated
        let results = mockDataGenerator.generateOptionsResults(for: filters)

        // Then: All results should have "Apple" as underlying asset
        XCTAssertFalse(results.isEmpty, "Should generate search results")

        for result in results {
            XCTAssertEqual(result.underlyingAsset, "Apple", "All results should have Apple as underlying asset")
            XCTAssertEqual(result.direction, "Call", "All results should be Call options")
        }

        // When: User creates an order from the first result
        guard let selectedResult = results.first else {
            XCTFail("Expected at least one result")
            return
        }
        let request = BuyOrderRequest(symbol: selectedResult.wkn, quantity: 1000, price: 1.50, optionDirection: selectedResult.direction, description: selectedResult.underlyingAsset, orderInstruction: "market", limitPrice: nil, strike: Double(selectedResult.strike.replacingOccurrences(of: ",", with: ".")))
        let order = try await traderService.placeBuyOrder(request)

        // Then: Order should have correct underlying asset
        XCTAssertEqual(order.underlyingAsset, "Apple", "Order should have Apple as underlying asset")
        XCTAssertEqual(order.optionDirection, "CALL", "Order should be CALL type")
        XCTAssertTrue(order.description.contains("Apple"), "Order description should contain Apple")
    }

    func testBasiswertFlow_Tesla() async throws {
        // Given: User selects "Tesla" as basiswert
        let filters = SearchFilters(
            category: "Optionsschein",
            underlyingAsset: "Tesla",
            direction: .put,
            strikePriceGap: nil,
            remainingTerm: nil,
            issuer: nil,
            omega: nil
        )

        // When: Search results are generated
        let results = mockDataGenerator.generateOptionsResults(for: filters)

        // Then: All results should have "Tesla" as underlying asset
        XCTAssertFalse(results.isEmpty, "Should generate search results")

        for result in results {
            XCTAssertEqual(result.underlyingAsset, "Tesla", "All results should have Tesla as underlying asset")
            XCTAssertEqual(result.direction, "Put", "All results should be Put options")
        }

        // When: User creates an order from the first result
        guard let selectedResult = results.first else {
            XCTFail("Expected at least one result")
            return
        }
        let request2 = BuyOrderRequest(symbol: selectedResult.wkn, quantity: 1000, price: 2.25, optionDirection: selectedResult.direction, description: selectedResult.underlyingAsset, orderInstruction: "market", limitPrice: nil, strike: Double(selectedResult.strike.replacingOccurrences(of: ",", with: ".")))
        let order = try await traderService.placeBuyOrder(request2)

        // Then: Order should have correct underlying asset
        XCTAssertEqual(order.underlyingAsset, "Tesla", "Order should have Tesla as underlying asset")
        XCTAssertEqual(order.optionDirection, "PUT", "Order should be PUT type")
        XCTAssertTrue(order.description.contains("Tesla"), "Order description should contain Tesla")
    }

    func testBasiswertFlow_NoHardcodedDefaults() async throws {
        // Given: Various basiswert selections
        let testCases = ["Apple", "Tesla", "BMW", "Microsoft", "Gold", "EUR/USD"]

        for basiswert in testCases {
            // When: Search results are generated
            let filters = SearchFilters(
                category: "Optionsschein",
                underlyingAsset: basiswert,
                direction: .call,
                strikePriceGap: nil,
                remainingTerm: nil,
                issuer: nil,
                omega: nil
            )

            let results = mockDataGenerator.generateOptionsResults(for: filters)

            // Then: No results should have hardcoded "DAX" unless basiswert is actually "DAX"
            for result in results {
                if basiswert != "DAX" {
                    XCTAssertNotEqual(result.underlyingAsset, "DAX",
                                    "Result should not have hardcoded DAX when basiswert is \(basiswert)")
                }
                XCTAssertEqual(result.underlyingAsset, basiswert,
                             "Result should have correct underlying asset: \(basiswert)")
            }
        }
    }

    func testDataFlowValidation() {
        // Given: A valid SearchResult
        let validResult = SearchResult(
            valuationDate: "31.12.2000",
            wkn: "TEST123",
            strike: "100.00",
            askPrice: "1.50",
            direction: "Call",
            isin: "DE000TEST123",
            underlyingAsset: "Apple"
        )

        // When: Validating the result
        let validation = validResult.validate(context: "test")

        // Then: Should be valid
        switch validation {
        case .valid:
            break // Expected
        case .warning(let message), .error(let message):
            XCTFail("Valid SearchResult should pass validation: \(message)")
        }
    }

    func testDataFlowValidation_InvalidOptions() {
        // Given: An invalid SearchResult (options without underlying asset)
        let invalidResult = SearchResult(
            valuationDate: "31.12.2000",
            wkn: "TEST123",
            strike: "100.00",
            askPrice: "1.50",
            direction: "Call",
            isin: "DE000TEST123",
            underlyingAsset: nil // This should fail validation
        )

        // When: Validating the result
        let validation = invalidResult.validate(context: "test")

        // Then: Should be invalid
        switch validation {
        case .valid:
            XCTFail("Invalid SearchResult should fail validation")
        case .warning(let message), .error(let message):
            XCTAssertTrue(message.contains("underlying asset"), "Should detect missing underlying asset")
        }
    }
}
