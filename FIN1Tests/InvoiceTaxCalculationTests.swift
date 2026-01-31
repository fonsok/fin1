import XCTest
@testable import FIN1

// MARK: - Invoice Tax Calculation Tests
final class InvoiceTaxCalculationTests: XCTestCase {

    // MARK: - Capital Gains Tax Calculation Tests

    func testCapitalGainsTaxCalculationPositiveProfit() {
        // Given
        let profit = 1000.0 // €1000 profit

        // When
        let tax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)

        // Then
        XCTAssertEqual(tax, 250.0, accuracy: 0.01, "Capital gains tax should be 25% of profit")
    }

    func testCapitalGainsTaxCalculationZeroProfit() {
        // Given
        let profit = 0.0 // No profit

        // When
        let tax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)

        // Then
        XCTAssertEqual(tax, 0.0, accuracy: 0.01, "Capital gains tax should be 0 for zero profit")
    }

    func testCapitalGainsTaxCalculationLoss() {
        // Given
        let profit = -500.0 // €500 loss

        // When
        let tax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)

        // Then
        XCTAssertEqual(tax, 0.0, accuracy: 0.01, "Capital gains tax should be 0 for losses")
    }

    func testCapitalGainsTaxCalculationNegativeProfit() {
        // Given
        let profit = -1000.0 // €1000 loss

        // When
        let tax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)

        // Then
        XCTAssertEqual(tax, 0.0, accuracy: 0.01, "Capital gains tax should be 0 for negative profit")
    }

    // MARK: - Solidarity Surcharge Calculation Tests

    func testSolidaritySurchargeCalculation() {
        // Given
        let capitalGainsTax = 250.0 // €250 capital gains tax

        // When
        let surcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)

        // Then
        XCTAssertEqual(surcharge, 13.75, accuracy: 0.01, "Solidarity surcharge should be 5.5% of capital gains tax")
    }

    func testSolidaritySurchargeCalculationZero() {
        // Given
        let capitalGainsTax = 0.0 // No capital gains tax

        // When
        let surcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)

        // Then
        XCTAssertEqual(surcharge, 0.0, accuracy: 0.01, "Solidarity surcharge should be 0 when capital gains tax is 0")
    }

    func testSolidaritySurchargeCalculationSmallAmount() {
        // Given
        let capitalGainsTax = 10.0 // €10 capital gains tax

        // When
        let surcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)

        // Then
        XCTAssertEqual(surcharge, 0.55, accuracy: 0.01, "Solidarity surcharge should be 5.5% of capital gains tax")
    }

    // MARK: - Church Tax Calculation Tests

    func testChurchTaxCalculation() {
        // Given
        let capitalGainsTax = 250.0 // €250 capital gains tax

        // When
        let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)

        // Then
        XCTAssertEqual(churchTax, 20.0, accuracy: 0.01, "Church tax should be 8% of capital gains tax")
    }

    func testChurchTaxCalculationZero() {
        // Given
        let capitalGainsTax = 0.0 // No capital gains tax

        // When
        let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)

        // Then
        XCTAssertEqual(churchTax, 0.0, accuracy: 0.01, "Church tax should be 0 when capital gains tax is 0")
    }

    func testChurchTaxCalculationSmallAmount() {
        // Given
        let capitalGainsTax = 10.0 // €10 capital gains tax

        // When
        let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)

        // Then
        XCTAssertEqual(churchTax, 0.80, accuracy: 0.01, "Church tax should be 8% of capital gains tax")
    }

    // MARK: - Total Tax Calculation Tests

    func testTotalTaxCalculationPositiveProfit() {
        // Given
        let profit = 1000.0 // €1000 profit

        // When
        let totalTax = InvoiceTaxCalculator.calculateTotalTax(for: profit)

        // Then
        // Capital gains tax: €1000 * 0.25 = €250
        // Solidarity surcharge: €250 * 0.055 = €13.75
        // Church tax: €250 * 0.08 = €20.00
        // Total: €250 + €13.75 + €20.00 = €283.75
        XCTAssertEqual(totalTax, 283.75, accuracy: 0.01, "Total tax should be €283.75 for €1000 profit")
    }

    func testTotalTaxCalculationZeroProfit() {
        // Given
        let profit = 0.0 // No profit

        // When
        let totalTax = InvoiceTaxCalculator.calculateTotalTax(for: profit)

        // Then
        XCTAssertEqual(totalTax, 0.0, accuracy: 0.01, "Total tax should be 0 for zero profit")
    }

    func testTotalTaxCalculationLoss() {
        // Given
        let profit = -500.0 // €500 loss

        // When
        let totalTax = InvoiceTaxCalculator.calculateTotalTax(for: profit)

        // Then
        XCTAssertEqual(totalTax, 0.0, accuracy: 0.01, "Total tax should be 0 for losses")
    }

    // MARK: - Net Amount After Taxes Calculation Tests

    func testNetAmountAfterTaxesPositiveProfit() {
        // Given
        let profit = 1000.0 // €1000 profit

        // When
        let netAmount = InvoiceTaxCalculator.calculateNetAmountAfterTaxes(for: profit)

        // Then
        // Total tax: €283.75
        // Net amount: €1000 - €283.75 = €716.25
        XCTAssertEqual(netAmount, 716.25, accuracy: 0.01, "Net amount should be €716.25 for €1000 profit")
    }

    func testNetAmountAfterTaxesZeroProfit() {
        // Given
        let profit = 0.0 // No profit

        // When
        let netAmount = InvoiceTaxCalculator.calculateNetAmountAfterTaxes(for: profit)

        // Then
        XCTAssertEqual(netAmount, 0.0, accuracy: 0.01, "Net amount should be 0 for zero profit")
    }

    func testNetAmountAfterTaxesLoss() {
        // Given
        let profit = -500.0 // €500 loss

        // When
        let netAmount = InvoiceTaxCalculator.calculateNetAmountAfterTaxes(for: profit)

        // Then
        XCTAssertEqual(netAmount, -500.0, accuracy: 0.01, "Net amount should be -€500 for €500 loss")
    }

    // MARK: - Tax Item Creation Tests

    func testCapitalGainsTaxItemCreation() {
        // Given
        let profit = 1000.0

        // When
        let item = InvoiceTaxCalculator.createCapitalGainsTaxItem(for: profit)

        // Then
        XCTAssertEqual(item.description, "Kapitalertragsteuer (25%)")
        XCTAssertEqual(item.quantity, 1.0)
        XCTAssertEqual(item.unitPrice, 250.0, accuracy: 0.01)
        XCTAssertEqual(item.totalAmount, 250.0, accuracy: 0.01)
        XCTAssertEqual(item.itemType, .tax)
    }

    func testCapitalGainsTaxItemCreationZero() {
        // Given
        let profit = 0.0

        // When
        let item = InvoiceTaxCalculator.createCapitalGainsTaxItem(for: profit)

        // Then
        XCTAssertEqual(item.description, "Kapitalertragsteuer (25%)")
        XCTAssertEqual(item.quantity, 1.0)
        XCTAssertEqual(item.unitPrice, 0.0, accuracy: 0.01)
        XCTAssertEqual(item.totalAmount, 0.0, accuracy: 0.01)
        XCTAssertEqual(item.itemType, .tax)
    }

    func testSolidaritySurchargeItemCreation() {
        // Given
        let profit = 1000.0

        // When
        let item = InvoiceTaxCalculator.createSolidaritySurchargeItem(for: profit)

        // Then
        XCTAssertEqual(item.description, "Solidaritätszuschlag (5,5%)")
        XCTAssertEqual(item.quantity, 1.0)
        XCTAssertEqual(item.unitPrice, 13.75, accuracy: 0.01)
        XCTAssertEqual(item.totalAmount, 13.75, accuracy: 0.01)
        XCTAssertEqual(item.itemType, .tax)
    }

    func testChurchTaxItemCreation() {
        // Given
        let profit = 1000.0

        // When
        let item = InvoiceTaxCalculator.createChurchTaxItem(for: profit)

        // Then
        XCTAssertEqual(item.description, "Kirchensteuer (8%)")
        XCTAssertEqual(item.quantity, 1.0)
        XCTAssertEqual(item.unitPrice, 20.0, accuracy: 0.01)
        XCTAssertEqual(item.totalAmount, 20.0, accuracy: 0.01)
        XCTAssertEqual(item.itemType, .tax)
    }

    // MARK: - All Tax Items Creation Tests

    func testCreateAllTaxItemsPositiveProfit() {
        // Given
        let profit = 1000.0

        // When
        let items = InvoiceTaxCalculator.createAllTaxItems(for: profit)

        // Then
        XCTAssertEqual(items.count, 3, "Should create 3 tax items for positive profit")

        let capitalGainsTaxItem = items.first { $0.description.contains("Kapitalertragsteuer") }
        let solidaritySurchargeItem = items.first { $0.description.contains("Solidaritätszuschlag") }
        let churchTaxItem = items.first { $0.description.contains("Kirchensteuer") }

        XCTAssertNotNil(capitalGainsTaxItem, "Should create capital gains tax item")
        XCTAssertNotNil(solidaritySurchargeItem, "Should create solidarity surcharge item")
        XCTAssertNotNil(churchTaxItem, "Should create church tax item")

        if let capitalGainsTaxItem = capitalGainsTaxItem {
            XCTAssertEqual(capitalGainsTaxItem.unitPrice, 250.0, accuracy: 0.01)
        } else {
            XCTFail("Capital gains tax item missing")
        }
        if let solidaritySurchargeItem = solidaritySurchargeItem {
            XCTAssertEqual(solidaritySurchargeItem.unitPrice, 13.75, accuracy: 0.01)
        } else {
            XCTFail("Solidarity surcharge item missing")
        }
        if let churchTaxItem = churchTaxItem {
            XCTAssertEqual(churchTaxItem.unitPrice, 20.0, accuracy: 0.01)
        } else {
            XCTFail("Church tax item missing")
        }
    }

    func testCreateAllTaxItemsZeroProfit() {
        // Given
        let profit = 0.0

        // When
        let items = InvoiceTaxCalculator.createAllTaxItems(for: profit)

        // Then
        XCTAssertEqual(items.count, 0, "Should create no tax items for zero profit")
    }

    func testCreateAllTaxItemsLoss() {
        // Given
        let profit = -500.0

        // When
        let items = InvoiceTaxCalculator.createAllTaxItems(for: profit)

        // Then
        XCTAssertEqual(items.count, 0, "Should create no tax items for losses")
    }

    // MARK: - TaxCalculationResult Tests

    func testTaxCalculationResultPositiveProfit() {
        // Given
        let profit = 1000.0

        // When
        let result = TaxCalculationResult(profit: profit)

        // Then
        XCTAssertEqual(result.profit, 1000.0, accuracy: 0.01)
        XCTAssertEqual(result.capitalGainsTax, 250.0, accuracy: 0.01)
        XCTAssertEqual(result.solidaritySurcharge, 13.75, accuracy: 0.01)
        XCTAssertEqual(result.churchTax, 20.0, accuracy: 0.01)
        XCTAssertEqual(result.totalTax, 283.75, accuracy: 0.01)
        XCTAssertEqual(result.netAmountAfterTaxes, 716.25, accuracy: 0.01)
    }

    func testTaxCalculationResultZeroProfit() {
        // Given
        let profit = 0.0

        // When
        let result = TaxCalculationResult(profit: profit)

        // Then
        XCTAssertEqual(result.profit, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.capitalGainsTax, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.solidaritySurcharge, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.churchTax, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.totalTax, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.netAmountAfterTaxes, 0.0, accuracy: 0.01)
    }

    func testTaxCalculationResultLoss() {
        // Given
        let profit = -500.0

        // When
        let result = TaxCalculationResult(profit: profit)

        // Then
        XCTAssertEqual(result.profit, -500.0, accuracy: 0.01)
        XCTAssertEqual(result.capitalGainsTax, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.solidaritySurcharge, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.churchTax, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.totalTax, 0.0, accuracy: 0.01)
        XCTAssertEqual(result.netAmountAfterTaxes, -500.0, accuracy: 0.01)
    }

    // MARK: - Edge Cases and Boundary Tests

    func testVerySmallProfit() {
        // Given
        let profit = 0.01 // €0.01 profit

        // When
        let result = TaxCalculationResult(profit: profit)

        // Then
        XCTAssertEqual(result.capitalGainsTax, 0.0025, accuracy: 0.0001)
        XCTAssertEqual(result.solidaritySurcharge, 0.0001375, accuracy: 0.00001)
        XCTAssertEqual(result.churchTax, 0.0002, accuracy: 0.00001)
        XCTAssertEqual(result.totalTax, 0.0028375, accuracy: 0.00001)
        XCTAssertEqual(result.netAmountAfterTaxes, 0.0071625, accuracy: 0.00001)
    }

    func testVeryLargeProfit() {
        // Given
        let profit = 1000000.0 // €1M profit

        // When
        let result = TaxCalculationResult(profit: profit)

        // Then
        XCTAssertEqual(result.capitalGainsTax, 250000.0, accuracy: 0.01)
        XCTAssertEqual(result.solidaritySurcharge, 13750.0, accuracy: 0.01)
        XCTAssertEqual(result.churchTax, 20000.0, accuracy: 0.01)
        XCTAssertEqual(result.totalTax, 283750.0, accuracy: 0.01)
        XCTAssertEqual(result.netAmountAfterTaxes, 716250.0, accuracy: 0.01)
    }

    func testPrecisionWithRounding() {
        // Given - Amount that might cause rounding issues
        let profit = 333.33 // €333.33 profit

        // When
        let result = TaxCalculationResult(profit: profit)

        // Then
        // Capital gains tax: €333.33 * 0.25 = €83.3325
        XCTAssertEqual(result.capitalGainsTax, 83.3325, accuracy: 0.0001)
        // Solidarity surcharge: €83.3325 * 0.055 = €4.5832875
        XCTAssertEqual(result.solidaritySurcharge, 4.5832875, accuracy: 0.00001)
        // Church tax: €83.3325 * 0.08 = €6.6666
        XCTAssertEqual(result.churchTax, 6.6666, accuracy: 0.0001)
    }

    // MARK: - Integration Tests

    func testCompleteTaxCalculationWorkflow() {
        // Given - A typical profitable trade
        let profit = 2000.0 // €2000 profit

        // When - Calculate all tax components
        let capitalGainsTax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)
        let solidaritySurcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)
        let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)
        let totalTax = InvoiceTaxCalculator.calculateTotalTax(for: profit)
        let netAmount = InvoiceTaxCalculator.calculateNetAmountAfterTaxes(for: profit)
        let taxItems = InvoiceTaxCalculator.createAllTaxItems(for: profit)

        // Then - Verify all calculations are consistent
        XCTAssertEqual(capitalGainsTax, 500.0, accuracy: 0.01) // 25% of €2000
        XCTAssertEqual(solidaritySurcharge, 27.5, accuracy: 0.01) // 5.5% of €500
        XCTAssertEqual(churchTax, 40.0, accuracy: 0.01) // 8% of €500
        XCTAssertEqual(totalTax, 567.5, accuracy: 0.01) // Sum of all taxes
        XCTAssertEqual(netAmount, 1432.5, accuracy: 0.01) // €2000 - €567.5
        XCTAssertEqual(taxItems.count, 3, "Should create 3 tax items")

        // Verify tax items sum to total tax
        let itemsTotal = taxItems.reduce(0) { $0 + $1.totalAmount }
        XCTAssertEqual(itemsTotal, totalTax, accuracy: 0.01, "Tax items should sum to total tax")
    }

    func testTaxCalculationWithDifferentProfitAmounts() {
        let testCases: [(profit: Double, expectedCapitalGainsTax: Double, expectedTotalTax: Double)] = [
            (100.0, 25.0, 28.375),      // Small profit
            (1000.0, 250.0, 283.75),    // Medium profit
            (10000.0, 2500.0, 2837.5),  // Large profit
            (0.0, 0.0, 0.0),            // No profit
            (-100.0, 0.0, 0.0),         // Loss
            (-1000.0, 0.0, 0.0)         // Large loss
        ]

        for testCase in testCases {
            let result = TaxCalculationResult(profit: testCase.profit)

            XCTAssertEqual(result.capitalGainsTax, testCase.expectedCapitalGainsTax, accuracy: 0.01,
                          "Capital gains tax should be \(testCase.expectedCapitalGainsTax) for profit \(testCase.profit)")
            XCTAssertEqual(result.totalTax, testCase.expectedTotalTax, accuracy: 0.01,
                          "Total tax should be \(testCase.expectedTotalTax) for profit \(testCase.profit)")
        }
    }
}
