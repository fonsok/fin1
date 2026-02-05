import XCTest
@testable import FIN1

final class InvestorCollectionBillCalculationServiceTests: XCTestCase {

    private var service: InvestorCollectionBillCalculationService!

    override func setUp() {
        super.setUp()
        service = InvestorCollectionBillCalculationService()
    }

    override func tearDown() {
        service = nil
        super.tearDown()
    }

    // MARK: - Scenario 1: Single Trade

    func testSingleTradeFullCapital() throws {
        // Given: Investment participates in one trade with full capital
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Full investment capital is used
        XCTAssertEqual(output.buyAmount, 3_000.0, accuracy: 0.01)
        XCTAssertEqual(output.buyQuantity, 1_500.0, accuracy: 0.01) // 3000 / 2.0
        XCTAssertEqual(output.buyPrice, 2.0, accuracy: 0.01)

        // Buy fees scaled by ownership (50%)
        XCTAssertEqual(output.buyFees, 10.12, accuracy: 0.01) // 20.24 * 0.5

        // Sell calculations
        XCTAssertEqual(output.sellQuantity, 1_500.0, accuracy: 0.01) // 100% sold
        XCTAssertEqual(output.sellAveragePrice, 4.20, accuracy: 0.01)
        XCTAssertEqual(output.sellAmount, 6_300.0, accuracy: 0.01) // 1500 * 4.20

        // Profit
        XCTAssertEqual(output.grossProfit, 3_269.86, accuracy: 0.01) // 6300 - 20.02*0.5 - (3000 + 10.12)
        XCTAssertEqual(output.roiInvestedAmount, 3_000.0, accuracy: 0.01) // 1500 * 2.0
        XCTAssertEqual(output.roiGrossProfit, 3_300.0, accuracy: 0.01) // 6300 - 3000
    }

    func testSingleTradeWithFees() throws {
        // Given: Trade with multiple fee types
        let buyInvoice = Invoice(
            invoiceNumber: "INV-BUY-001",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: [
                InvoiceItem(description: "Wertpapiere", quantity: 1_500, unitPrice: 2.0, itemType: .securities),
                InvoiceItem(description: "Ordergebühr", quantity: 1, unitPrice: 12.0, itemType: .orderFee),
                InvoiceItem(description: "Börsenplatz", quantity: 1, unitPrice: 4.0, itemType: .exchangeFee),
                InvoiceItem(description: "Fremdkosten", quantity: 1, unitPrice: 4.24, itemType: .foreignCosts)
            ],
            tradeId: "trade-1",
            transactionType: .buy
        )

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: buyInvoice,
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: All fees should be itemized and scaled
        XCTAssertEqual(output.buyFeeDetails.count, 3) // Ordergebühr, Börsenplatz, Fremdkosten
        XCTAssertEqual(output.buyFees, 10.12, accuracy: 0.01) // (12 + 4 + 4.24) * 0.5

        // Verify fee details
        let orderFee = output.buyFeeDetails.first { $0.label == "Ordergebühr" }
        XCTAssertNotNil(orderFee)
        XCTAssertEqual(orderFee?.amount, 6.0, accuracy: 0.01) // 12 * 0.5
    }

    func testSingleTradePartialSell() throws {
        // Given: Only 50% of securities sold
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [createSellInvoice(quantity: 750, price: 4.20, fees: -10.01)], // 50% sold
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Sell quantity is 50% of buy quantity
        XCTAssertEqual(output.sellQuantity, 750.0, accuracy: 0.01) // 1500 * 0.5 (50% sold)
        XCTAssertEqual(output.sellAmount, 3_150.0, accuracy: 0.01) // 750 * 4.20
        XCTAssertEqual(output.sellAveragePrice, 4.20, accuracy: 0.01)
    }

    // MARK: - Scenario 2: Multiple Trades (Capital Distribution)

    func testMultipleTradesEqualOwnership() throws {
        // Given: Investment participates in 2 trades with equal ownership
        // Trade 1 gets 50% of capital, Trade 2 gets 50% of capital
        // This test simulates Trade 1's calculation (capital already distributed)
        let input = InvestorCollectionBillInput(
            investmentCapital: 2_166.67, // 50% of 4,333.33 (already distributed)
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 2_166.67
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Uses distributed capital share
        XCTAssertEqual(output.buyAmount, 2_166.67, accuracy: 0.01)
        XCTAssertEqual(output.buyQuantity, 1_083.335, accuracy: 0.01) // 2166.67 / 2.0, rounded down
    }

    func testMultipleTradesUnequalOwnership() throws {
        // Given: Investment participates in 2 trades with unequal ownership
        // Trade 1: 30% ownership, gets 30% of capital
        let input = InvestorCollectionBillInput(
            investmentCapital: 1_300.0, // 30% of 4,333.33 (already distributed)
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.3, // 30% ownership
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 1_300.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Uses distributed capital share
        XCTAssertEqual(output.buyAmount, 1_300.0, accuracy: 0.01)
        XCTAssertEqual(output.buyQuantity, 650.0, accuracy: 0.01) // 1300 / 2.0

        // Fees scaled by ownership (30%)
        XCTAssertEqual(output.buyFees, 6.072, accuracy: 0.01) // 20.24 * 0.3
    }

    // MARK: - Scenario 3: Partial Sells (Multiple Sell Invoices)

    func testPartialSellTwoInvoices() throws {
        // Given: Trade with two partial sell invoices
        let sellInvoice1 = createSellInvoice(quantity: 500, price: 4.00, fees: -8.0)
        let sellInvoice2 = createSellInvoice(quantity: 1_000, price: 4.20, fees: -12.02)

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [sellInvoice1, sellInvoice2],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Aggregated sell values
        XCTAssertEqual(output.sellQuantity, 1_500.0, accuracy: 0.01) // 500 + 1000
        XCTAssertEqual(output.sellAveragePrice, 4.133, accuracy: 0.01) // (500*4.0 + 1000*4.2) / 1500
        XCTAssertEqual(output.sellAmount, 6_200.0, accuracy: 0.01) // 1500 * 4.133...

        // Fees aggregated from both invoices
        XCTAssertEqual(output.sellFees, -10.01, accuracy: 0.01) // (-8.0 - 12.02) * 0.5 (scaled by sell share)
    }

    func testPartialSellThreeInvoices() throws {
        // Given: Trade with three partial sell invoices
        let sellInvoice1 = createSellInvoice(quantity: 300, price: 4.00, fees: -5.0)
        let sellInvoice2 = createSellInvoice(quantity: 500, price: 4.10, fees: -8.0)
        let sellInvoice3 = createSellInvoice(quantity: 700, price: 4.30, fees: -10.0)

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [sellInvoice1, sellInvoice2, sellInvoice3],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: All invoices aggregated
        XCTAssertEqual(output.sellQuantity, 1_500.0, accuracy: 0.01) // 300 + 500 + 700
        let expectedAvgPrice = (300 * 4.0 + 500 * 4.1 + 700 * 4.3) / 1_500.0
        XCTAssertEqual(output.sellAveragePrice, expectedAvgPrice, accuracy: 0.01)
    }

    func testPartialSellDifferentPrices() throws {
        // Given: Partial sells at different prices
        let sellInvoice1 = createSellInvoice(quantity: 1_000, price: 4.00, fees: -10.0)
        let sellInvoice2 = createSellInvoice(quantity: 500, price: 4.50, fees: -5.0)

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [sellInvoice1, sellInvoice2],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Weighted average price calculated correctly
        let expectedAvgPrice = (1_000 * 4.0 + 500 * 4.5) / 1_500.0 // 4.166...
        XCTAssertEqual(output.sellAveragePrice, expectedAvgPrice, accuracy: 0.01)
    }

    // MARK: - Edge Cases

    func testZeroFees() throws {
        // Given: Trade with no fees
        let buyInvoice = Invoice(
            invoiceNumber: "INV-BUY-NO-FEES",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: [
                InvoiceItem(description: "Wertpapiere", quantity: 1_500, unitPrice: 2.0, itemType: .securities)
            ],
            tradeId: "trade-1",
            transactionType: .buy
        )

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: buyInvoice,
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: 0.0)],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Fees should be zero
        XCTAssertEqual(output.buyFees, 0.0, accuracy: 0.01)
        XCTAssertEqual(output.sellFees, 0.0, accuracy: 0.01)
        XCTAssertEqual(output.buyFeeDetails.count, 0)
        XCTAssertEqual(output.sellFeeDetails.count, 0)
    }

    func testZeroSellQuantity() throws {
        // Given: Trade with no sells yet
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [], // No sells
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Sell values should be zero
        XCTAssertEqual(output.sellQuantity, 0.0, accuracy: 0.01)
        XCTAssertEqual(output.sellAmount, 0.0, accuracy: 0.01)
        XCTAssertEqual(output.sellAveragePrice, 0.0, accuracy: 0.01)
        XCTAssertEqual(output.sellFees, 0.0, accuracy: 0.01)

        // Gross profit should be negative (buy costs only)
        XCTAssertEqual(output.grossProfit, -3_010.12, accuracy: 0.01) // -(3000 + 10.12)
    }

    func testBoundaryOwnershipPercentage() throws {
        // Given: Minimum ownership (0.01 = 1%)
        let input = InvestorCollectionBillInput(
            investmentCapital: 30.0, // 1% of 3000
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.01, // 1%
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 30.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Very small values scaled correctly
        XCTAssertEqual(output.buyAmount, 30.0, accuracy: 0.01)
        XCTAssertEqual(output.buyQuantity, 15.0, accuracy: 0.01) // 30 / 2.0
        XCTAssertEqual(output.buyFees, 0.2024, accuracy: 0.0001) // 20.24 * 0.01
    }

    func testMaximumOwnershipPercentage() throws {
        // Given: Maximum ownership (1.0 = 100%)
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 1.0, // 100%
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Full fees (no scaling)
        XCTAssertEqual(output.buyFees, 20.24, accuracy: 0.01) // 20.24 * 1.0
        XCTAssertEqual(output.sellFees, -20.02, accuracy: 0.01) // -20.02 * 1.0
    }

    func testRoundingDownBuyQuantity() throws {
        // Given: Capital that doesn't divide evenly by price
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_333.33, // Doesn't divide evenly by 2.0
            buyPrice: 2.0,
            tradeTotalQuantity: 1_666.665,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_666.665, price: 2.0, fees: 20.24),
            sellInvoices: [createSellInvoice(quantity: 1_666.665, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 3_333.33
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Quantity should be rounded down to 2 decimal places
        let expectedQty = floor((3_333.33 / 2.0) * 100) / 100 // 1666.66
        XCTAssertEqual(output.buyQuantity, expectedQty, accuracy: 0.01)
    }

    // MARK: - Validation Rules

    func testValidationFailsWithZeroCapital() {
        // Given: Zero investment capital
        let input = InvestorCollectionBillInput(
            investmentCapital: 0.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: nil,
            sellInvoices: [],
            investorAllocatedAmount: 0.0
        )

        // When/Then
        XCTAssertThrowsError(try service.calculateCollectionBill(input: input)) { error in
            if case CollectionBillCalculationError.validationFailed(let message) = error {
                XCTAssertTrue(message.contains("capital"))
            } else {
                XCTFail("Expected validationFailed error")
            }
        }
    }

    func testValidationFailsWithNegativeCapital() {
        // Given: Negative investment capital
        let input = InvestorCollectionBillInput(
            investmentCapital: -100.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: nil,
            sellInvoices: [],
            investorAllocatedAmount: -100.0
        )

        // When/Then
        XCTAssertThrowsError(try service.calculateCollectionBill(input: input))
    }

    func testValidationFailsWithZeroBuyPrice() {
        // Given: Zero buy price
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 0.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: nil,
            sellInvoices: [],
            investorAllocatedAmount: 3_000.0
        )

        // When/Then
        XCTAssertThrowsError(try service.calculateCollectionBill(input: input)) { error in
            if case CollectionBillCalculationError.validationFailed(let message) = error {
                XCTAssertTrue(message.contains("price"))
            } else {
                XCTFail("Expected validationFailed error")
            }
        }
    }

    func testValidationFailsWithInvalidOwnershipPercentage() {
        // Given: Ownership percentage > 1.0
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 1.5, // Invalid: > 1.0
            buyInvoice: nil,
            sellInvoices: [],
            investorAllocatedAmount: 3_000.0
        )

        // When/Then
        XCTAssertThrowsError(try service.calculateCollectionBill(input: input))
    }

    func testValidationFailsWithZeroOwnershipPercentage() {
        // Given: Zero ownership percentage
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.0, // Invalid: must be > 0
            buyInvoice: nil,
            sellInvoices: [],
            investorAllocatedAmount: 3_000.0
        )

        // When/Then
        XCTAssertThrowsError(try service.calculateCollectionBill(input: input))
    }

    func testValidationFailsWithZeroTradeQuantity() {
        // Given: Zero trade total quantity
        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 0.0, // Invalid: must be > 0
            ownershipPercentage: 0.5,
            buyInvoice: nil,
            sellInvoices: [],
            investorAllocatedAmount: 3_000.0
        )

        // When/Then
        XCTAssertThrowsError(try service.calculateCollectionBill(input: input))
    }

    func testValidationWarnsOnInvoiceQuantityMismatch() throws {
        // Given: Invoice quantity differs from calculated quantity
        let buyInvoice = Invoice(
            invoiceNumber: "INV-BUY-MISMATCH",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: [
                InvoiceItem(description: "Wertpapiere", quantity: 1_600, unitPrice: 2.0, itemType: .securities), // Wrong quantity
                InvoiceItem(description: "Ordergebühr", quantity: 1, unitPrice: 20.24, itemType: .orderFee)
            ],
            tradeId: "trade-1",
            transactionType: .buy
        )

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0, // Should give 1500 quantity
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: buyInvoice,
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let validation = service.validateInput(input)

        // Then: Should warn but still be valid
        XCTAssertTrue(validation.isValid)
        XCTAssertNotNil(validation.warningMessage)
        XCTAssertTrue(validation.warningMessage?.contains("Invoice quantity") ?? false)

        // Calculation should still work
        let output = try service.calculateCollectionBill(input: input)
        XCTAssertEqual(output.buyQuantity, 1_500.0, accuracy: 0.01) // Uses calculated, not invoice
    }

    // MARK: - Data Source Hierarchy Enforcement

    func testUsesInvestmentCapitalNotInvoiceForBuyAmount() throws {
        // Given: Invoice has wrong quantity/value, but investment capital is correct
        let buyInvoice = Invoice(
            invoiceNumber: "INV-BUY-WRONG",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: [
                InvoiceItem(description: "Wertpapiere", quantity: 2_000, unitPrice: 2.0, itemType: .securities), // Wrong: should be 1500
                InvoiceItem(description: "Ordergebühr", quantity: 1, unitPrice: 20.24, itemType: .orderFee)
            ],
            tradeId: "trade-1",
            transactionType: .buy
        )

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0, // Correct capital
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: buyInvoice,
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Uses investment capital, not invoice value
        XCTAssertEqual(output.buyAmount, 3_000.0, accuracy: 0.01) // Investment capital
        XCTAssertEqual(output.buyQuantity, 1_500.0, accuracy: 0.01) // Calculated from capital, not invoice
        // NOT: 2000 * 0.5 = 1000 (wrong)
    }

    func testUsesTradeEntryPriceNotInvoicePrice() throws {
        // Given: Invoice has different price than trade entry price
        let buyInvoice = Invoice(
            invoiceNumber: "INV-BUY-PRICE",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: [
                InvoiceItem(description: "Wertpapiere", quantity: 1_500, unitPrice: 2.10, itemType: .securities), // Different price
                InvoiceItem(description: "Ordergebühr", quantity: 1, unitPrice: 20.24, itemType: .orderFee)
            ],
            tradeId: "trade-1",
            transactionType: .buy
        )

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0, // Trade entry price (correct)
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: buyInvoice,
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Uses trade entry price, not invoice price
        XCTAssertEqual(output.buyPrice, 2.0, accuracy: 0.01) // Trade entry price
        XCTAssertEqual(output.buyQuantity, 1_500.0, accuracy: 0.01) // 3000 / 2.0, not 3000 / 2.10
    }

    func testUsesInvoiceForFees() throws {
        // Given: Fees only exist on invoice
        let buyInvoice = Invoice(
            invoiceNumber: "INV-BUY-FEES",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: [
                InvoiceItem(description: "Wertpapiere", quantity: 1_500, unitPrice: 2.0, itemType: .securities),
                InvoiceItem(description: "Ordergebühr", quantity: 1, unitPrice: 12.0, itemType: .orderFee),
                InvoiceItem(description: "Börsenplatz", quantity: 1, unitPrice: 4.0, itemType: .exchangeFee),
                InvoiceItem(description: "Fremdkosten", quantity: 1, unitPrice: 4.24, itemType: .foreignCosts)
            ],
            tradeId: "trade-1",
            transactionType: .buy
        )

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: buyInvoice,
            sellInvoices: [createSellInvoice(quantity: 1_500, price: 4.20, fees: -20.02)],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Fees come from invoice, scaled by ownership
        XCTAssertEqual(output.buyFees, 10.12, accuracy: 0.01) // (12 + 4 + 4.24) * 0.5
        XCTAssertEqual(output.buyFeeDetails.count, 3) // All fee types itemized
    }

    func testUsesInvoiceForSellPrices() throws {
        // Given: Multiple sell invoices with different prices
        let sellInvoice1 = createSellInvoice(quantity: 500, price: 4.00, fees: -8.0)
        let sellInvoice2 = createSellInvoice(quantity: 1_000, price: 4.20, fees: -12.02)

        let input = InvestorCollectionBillInput(
            investmentCapital: 3_000.0,
            buyPrice: 2.0,
            tradeTotalQuantity: 1_500.0,
            ownershipPercentage: 0.5,
            buyInvoice: createBuyInvoice(quantity: 1_500, price: 2.0, fees: 20.24),
            sellInvoices: [sellInvoice1, sellInvoice2],
            investorAllocatedAmount: 3_000.0
        )

        // When
        let output = try service.calculateCollectionBill(input: input)

        // Then: Average sell price calculated from invoices
        let expectedAvgPrice = (500 * 4.0 + 1_000 * 4.2) / 1_500.0
        XCTAssertEqual(output.sellAveragePrice, expectedAvgPrice, accuracy: 0.01)
        XCTAssertEqual(output.sellAmount, 1_500.0 * expectedAvgPrice, accuracy: 0.01)
    }

    // MARK: - Helper Methods

    private func createBuyInvoice(quantity: Double, price: Double, fees: Double) -> Invoice {
        var items: [InvoiceItem] = [
            InvoiceItem(description: "Wertpapiere", quantity: quantity, unitPrice: price, itemType: .securities)
        ]

        if fees > 0 {
            items.append(InvoiceItem(description: "Ordergebühr", quantity: 1, unitPrice: fees, itemType: .orderFee))
        }

        return Invoice(
            invoiceNumber: "INV-BUY-\(UUID().uuidString.prefix(8))",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: items,
            tradeId: "trade-1",
            transactionType: .buy
        )
    }

    private func createSellInvoice(quantity: Double, price: Double, fees: Double) -> Invoice {
        var items: [InvoiceItem] = [
            InvoiceItem(description: "Wertpapiere", quantity: quantity, unitPrice: price, itemType: .securities)
        ]

        if fees != 0 {
            items.append(InvoiceItem(description: "Ordergebühr", quantity: 1, unitPrice: fees, itemType: .orderFee))
        }

        return Invoice(
            invoiceNumber: "INV-SELL-\(UUID().uuidString.prefix(8))",
            type: .securitiesSettlement,
            status: .generated,
            customerInfo: sampleCustomer(),
            items: items,
            tradeId: "trade-1",
            transactionType: .sell
        )
    }

    private func sampleCustomer() -> CustomerInfo {
        CustomerInfo(
            name: "Test Customer",
            address: "Test Address",
            city: "Test City",
            postalCode: "12345",
            taxNumber: "DE123456789",
            depotNumber: "DEP001",
            bank: "Test Bank",
            customerNumber: "CUST001"
        )
    }
}
