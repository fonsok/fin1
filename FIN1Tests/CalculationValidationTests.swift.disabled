import XCTest
@testable import FIN1

// MARK: - Calculation Validation Tests

final class CalculationValidationTests: XCTestCase {

    var validationService: CalculationValidationService!

    override func setUp() {
        super.setUp()
        validationService = CalculationValidationService()
    }

    override func tearDown() {
        validationService = nil
        super.tearDown()
    }

    // MARK: - Test Data Setup

    private func createTestInvoice(
        transactionType: TransactionType,
        securitiesAmount: Double,
        fees: Double,
        taxes: Double = 0
    ) -> Invoice {
        var items: [InvoiceItem] = []

        // Add securities item
        items.append(InvoiceItem(
            description: "Securities",
            quantity: 100,
            unitPrice: securitiesAmount / 100,
            itemType: .securities
        ))

        // Add fee items
        if fees > 0 {
            items.append(InvoiceItem(
                description: "Order Fee",
                quantity: 1,
                unitPrice: fees,
                itemType: .orderFee
            ))
        }

        // Add tax items
        if taxes > 0 {
            items.append(InvoiceItem(
                description: "Tax",
                quantity: 1,
                unitPrice: taxes,
                itemType: .tax
            ))
        }

        return Invoice(
            id: UUID().uuidString,
            transactionType: transactionType,
            items: items,
            totalAmount: securitiesAmount + fees + taxes,
            createdAt: Date()
        )
    }

    // MARK: - Validation Tests

    func testCalculationConsistency_ValidData() {
        // Given
        let buyInvoice = createTestInvoice(
            transactionType: .buy,
            securitiesAmount: -2000,
            fees: -10
        )

        let sellInvoices = [
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 1000,
                fees: 5
            ),
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 1500,
                fees: 7
            )
        ]

        let expectedProfit = 1000.0 + 1500.0 - 2000.0 - 10.0 - 5.0 - 7.0 // 478.0
        let expectedTaxes = [
            TaxItem(
                name: "Abgeltungssteuer",
                basis: "478,00 €",
                rate: "25%",
                amount: "119,50 €"
            )
        ]

        // When
        let result = CalculationValidationService.validateCalculationConsistency(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            expectedProfit: expectedProfit,
            expectedTaxes: expectedTaxes
        )

        // Then
        XCTAssertTrue(result.isValid, "Calculation should be valid")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
    }

    func testCalculationConsistency_InconsistentProfit() {
        // Given
        let buyInvoice = createTestInvoice(
            transactionType: .buy,
            securitiesAmount: -2000,
            fees: -10
        )

        let sellInvoices = [
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 1000,
                fees: 5
            )
        ]

        let expectedProfit = 1000.0 // Wrong expected value
        let expectedTaxes: [TaxItem] = []

        // When
        let result = CalculationValidationService.validateCalculationConsistency(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            expectedProfit: expectedProfit,
            expectedTaxes: expectedTaxes
        )

        // Then
        XCTAssertFalse(result.isValid, "Calculation should be invalid")
        XCTAssertFalse(result.errors.isEmpty, "Should have errors")
        XCTAssertTrue(result.errors.contains { error in
            if case .inconsistentProfitCalculation = error {
                return true
            }
            return false
        })
    }

    func testCalculationConsistency_TaxItemsIncluded() {
        // Given
        let buyInvoice = createTestInvoice(
            transactionType: .buy,
            securitiesAmount: -2000,
            fees: -10,
            taxes: -100 // Tax item that should be excluded
        )

        let sellInvoices = [
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 1000,
                fees: 5
            )
        ]

        let expectedProfit = 1000.0 - 2000.0 - 10.0 - 5.0 // Should exclude tax
        let expectedTaxes: [TaxItem] = []

        // When
        let result = CalculationValidationService.validateCalculationConsistency(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            expectedProfit: expectedProfit,
            expectedTaxes: expectedTaxes
        )

        // Then
        XCTAssertTrue(result.isValid, "Calculation should be valid (tax items properly excluded)")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
    }

    func testCalculationMethods_ValidMethods() {
        // Given
        let calculationTrace = [
            "ProfitCalculationService.calculateTaxableProfit",
            "InvoiceTaxCalculator.calculateTotalTax",
            "FeeCalculationService.createFeeBreakdown"
        ]

        // When
        let result = CalculationValidationService.validateCalculationMethods(
            calculationTrace: calculationTrace
        )

        // Then
        XCTAssertTrue(result.isValid, "Methods should be valid")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
    }

    func testCalculationMethods_DeprecatedMethods() {
        // Given
        let calculationTrace = [
            "calculateNetCashFlow", // Deprecated method
            "ProfitCalculationService.calculateTaxableProfit"
        ]

        // When
        let result = CalculationValidationService.validateCalculationMethods(
            calculationTrace: calculationTrace
        )

        // Then
        XCTAssertFalse(result.isValid, "Methods should be invalid")
        XCTAssertFalse(result.errors.isEmpty, "Should have errors")
        XCTAssertTrue(result.errors.contains { error in
            if case .oldCalculationMethodUsed = error {
                return true
            }
            return false
        })
    }

    func testInvoiceDataValidation_ValidData() {
        // Given
        let buyInvoice = createTestInvoice(
            transactionType: .buy,
            securitiesAmount: -2000,
            fees: -10
        )

        let sellInvoices = [
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 1000,
                fees: 5
            )
        ]

        // When
        let result = CalculationValidationService.validateInvoiceData(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // Then
        XCTAssertTrue(result.isValid, "Invoice data should be valid")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
    }

    func testInvoiceDataValidation_MissingSecurities() {
        // Given
        let buyInvoice = Invoice(
            id: UUID().uuidString,
            transactionType: .buy,
            items: [
                InvoiceItem(
                    description: "Fee Only",
                    quantity: 1,
                    unitPrice: -10,
                    itemType: .orderFee
                )
            ],
            totalAmount: -10,
            createdAt: Date()
        )

        let sellInvoices: [Invoice] = []

        // When
        let result = CalculationValidationService.validateInvoiceData(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // Then
        XCTAssertFalse(result.isValid, "Invoice data should be invalid")
        XCTAssertFalse(result.errors.isEmpty, "Should have errors")
        XCTAssertTrue(result.errors.contains { error in
            if case .missingRequiredCalculationStep = error {
                return true
            }
            return false
        })
    }

    // MARK: - Integration Tests

    func testCompleteCalculationValidation() {
        // Given
        let buyInvoice = createTestInvoice(
            transactionType: .buy,
            securitiesAmount: -2000,
            fees: -10
        )

        let sellInvoices = [
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 1000,
                fees: 5
            ),
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 1500,
                fees: 7
            )
        ]

        let calculationTrace = [
            "ProfitCalculationService.calculateTaxableProfit",
            "InvoiceTaxCalculator.calculateTotalTax",
            "FeeCalculationService.createFeeBreakdown"
        ]

        // When
        let result = CalculationValidationService.validateCompleteCalculation(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            calculationTrace: calculationTrace
        )

        // Then
        XCTAssertTrue(result.isValid, "Complete calculation should be valid")
        XCTAssertTrue(result.errors.isEmpty, "Should have no errors")
    }

    func testCalculationBreakdownConsistency() {
        // Given - Test case that was failing: 8.348,10 - 4.266,94 = 4.081,16
        let buyInvoice = createTestInvoice(
            transactionType: .buy,
            securitiesAmount: -4266.94,
            fees: 0
        )

        let sellInvoices = [
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 8348.10,
                fees: 0
            )
        ]

        // When - Calculate breakdown
        let sellAmounts = sellInvoices.map { sellInvoice in
            let sellItems = sellInvoice.items.filter { $0.itemType != .tax }
            return sellItems.reduce(0) { $0 + $1.totalAmount }
        }
        let totalSellAmount = sellAmounts.reduce(0, +)

        let buyAmount: Double
        if let buyInvoice = buyInvoice {
            let buyItems = buyInvoice.items.filter { $0.itemType != .tax }
            buyAmount = buyItems.reduce(0) { $0 + $1.totalAmount }
        } else {
            buyAmount = 0.0
        }

        let breakdownResult = totalSellAmount - abs(buyAmount)

        // Calculate using the guarded method
        let guardedResult = ProfitCalculationService.calculateTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // Then - Both calculations should match
        XCTAssertEqual(breakdownResult, guardedResult, accuracy: 0.01,
                      "Breakdown calculation should match guarded calculation")
        XCTAssertEqual(breakdownResult, 4081.16, accuracy: 0.01,
                      "Expected result should be 4.081,16 €")
    }

    func testNegativeProfitNoTaxes() {
        // Given - Negative profit scenario: 1.831,99 - 1.892,78 = -60,79
        let buyInvoice = createTestInvoice(
            transactionType: .buy,
            securitiesAmount: -1892.78,
            fees: 0
        )

        let sellInvoices = [
            createTestInvoice(
                transactionType: .sell,
                securitiesAmount: 1831.99,
                fees: 0
            )
        ]

        // When - Calculate pre-tax profit
        let preTaxProfit = ProfitCalculationService.calculateTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // Then - No taxes should be due
        XCTAssertEqual(preTaxProfit, -60.79, accuracy: 0.01, "Pre-tax profit should be -60,79 €")
        XCTAssertTrue(preTaxProfit <= 0, "Pre-tax profit should be negative or zero")

        // Tax calculation should return 0
        let totalTax = InvoiceTaxCalculator.calculateTotalTax(for: preTaxProfit)
        XCTAssertEqual(totalTax, 0.0, "No taxes should be due for negative pre-tax profit")
    }
}
