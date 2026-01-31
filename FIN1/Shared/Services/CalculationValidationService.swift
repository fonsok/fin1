import Foundation

// MARK: - Calculation Validation Service

/// Service to ensure calculation consistency and prevent old data from disrupting the new scheme
final class CalculationValidationService {

    // MARK: - Validation Results

    struct ValidationResult {
        let isValid: Bool
        let errors: [ValidationError]
        let warnings: [ValidationWarning]

        var hasErrors: Bool { !errors.isEmpty }
        var hasWarnings: Bool { !warnings.isEmpty }
    }

    enum ValidationError: Error, Equatable {
        case inconsistentTaxCalculation(expected: Double, actual: Double)
        case inconsistentProfitCalculation(expected: Double, actual: Double)
        case oldCalculationMethodUsed(method: String)
        case taxItemsIncludedInProfitCalculation
        case missingRequiredCalculationStep(step: String)
    }

    enum ValidationWarning: Equatable {
        case deprecatedMethodUsed(method: String)
        case calculationDeviation(expected: Double, actual: Double, tolerance: Double)
    }

    // MARK: - Public Methods

    /// Validates that all calculations follow the standardized scheme
    /// - Parameters:
    ///   - buyInvoice: Buy transaction invoice
    ///   - sellInvoices: Sell transaction invoices
    ///   - expectedProfit: Expected profit before taxes
    ///   - expectedTaxes: Expected tax breakdown
    /// - Returns: Validation result with any errors or warnings
    static func validateCalculationConsistency(
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        expectedProfit: Double,
        expectedTaxes: [TaxItem]
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        let warnings: [ValidationWarning] = []

        // 1. Validate profit calculation consistency
        let calculatedProfit = ProfitCalculationService.calculateTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        if abs(calculatedProfit - expectedProfit) > 0.01 {
            errors.append(.inconsistentProfitCalculation(
                expected: expectedProfit,
                actual: calculatedProfit
            ))
        }

        // 2. Validate tax calculation consistency
        let calculatedTaxes = InvoiceTaxCalculator.calculateTotalTax(for: calculatedProfit)
        let expectedTotalTax = expectedTaxes.reduce(0) { total, tax in
            // Parse tax amount from formatted string
            let amountString = tax.amount.replacingOccurrences(of: "€", with: "")
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
                .trimmingCharacters(in: .whitespaces)

            if let amount = Double(amountString) {
                return total + amount
            }
            return total
        }

        if abs(calculatedTaxes - expectedTotalTax) > 0.01 {
            errors.append(.inconsistentTaxCalculation(
                expected: expectedTotalTax,
                actual: calculatedTaxes
            ))
        }

        // 3. Validate that tax items are excluded from profit calculation
        let allInvoices = [buyInvoice].compactMap { $0 } + sellInvoices
        let allItems = allInvoices.flatMap { $0.items }
        let taxItems = allItems.filter { $0.itemType == .tax }

        if !taxItems.isEmpty {
            // Check if any tax items are being included in profit calculation
            let profitWithTaxes = allInvoices.reduce(0) { total, invoice in
                total + invoice.items.reduce(0) { $0 + $1.totalAmount }
            }

            if abs(profitWithTaxes - calculatedProfit) > 0.01 {
                errors.append(.taxItemsIncludedInProfitCalculation)
            }
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    /// Validates that the correct calculation methods are being used
    /// - Parameter calculationTrace: Array of method names used in calculation
    /// - Returns: Validation result
    static func validateCalculationMethods(calculationTrace: [String]) -> ValidationResult {
        var errors: [ValidationError] = []
        let warnings: [ValidationWarning] = []

        let deprecatedMethods = [
            "calculateNetCashFlow",
            "calculateTotalTax_old",
            "buildTaxItems_legacy"
        ]

        let requiredMethods = [
            "ProfitCalculationService.calculateTaxableProfit",
            "InvoiceTaxCalculator.calculateTotalTax",
            "FeeCalculationService.createFeeBreakdown"
        ]

        // Check for deprecated methods
        for method in calculationTrace {
            if deprecatedMethods.contains(method) {
                errors.append(.oldCalculationMethodUsed(method: method))
            }
        }

        // Check for required methods
        for requiredMethod in requiredMethods {
            if !calculationTrace.contains(where: { $0.contains(requiredMethod) }) {
                errors.append(.missingRequiredCalculationStep(step: requiredMethod))
            }
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }

    /// Validates invoice data integrity
    /// - Parameters:
    ///   - buyInvoice: Buy transaction invoice
    ///   - sellInvoices: Sell transaction invoices
    /// - Returns: Validation result
    static func validateInvoiceData(
        buyInvoice: Invoice?,
        sellInvoices: [Invoice]
    ) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []

        let allInvoices = [buyInvoice].compactMap { $0 } + sellInvoices

        for invoice in allInvoices {
            // Check for required item types
            let hasSecurities = invoice.items.contains { $0.itemType == .securities }
            if !hasSecurities {
                errors.append(.missingRequiredCalculationStep(step: "securities items"))
            }

            // Check for proper fee structure
            let hasOrderFee = invoice.items.contains { $0.itemType == .orderFee }
            let hasExchangeFee = invoice.items.contains { $0.itemType == .exchangeFee }

            if !hasOrderFee || !hasExchangeFee {
                warnings.append(.deprecatedMethodUsed(method: "incomplete fee structure"))
            }
        }

        return ValidationResult(
            isValid: errors.isEmpty,
            errors: errors,
            warnings: warnings
        )
    }
}

// MARK: - Calculation Trace Protocol

/// Protocol for tracking calculation methods used
protocol CalculationTraceable {
    var calculationTrace: [String] { get set }

    mutating func addToTrace(_ method: String)
}

// MARK: - Calculation Trace Implementation

extension CalculationTraceable {
    mutating func addToTrace(_ method: String) {
        calculationTrace.append(method)
    }
}

// MARK: - Validation Extensions

extension CalculationValidationService {

    /// Comprehensive validation that checks all aspects
    /// - Parameters:
    ///   - buyInvoice: Buy transaction invoice
    ///   - sellInvoices: Sell transaction invoices
    ///   - calculationTrace: Methods used in calculation
    /// - Returns: Complete validation result
    static func validateCompleteCalculation(
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        calculationTrace: [String]
    ) -> ValidationResult {
        // Calculate expected values using the correct methods
        let expectedProfit = ProfitCalculationService.calculateTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        let expectedTaxes = [
            TaxItem(
                name: "Abgeltungssteuer",
                basis: expectedProfit.formatted(.currency(code: "EUR")),
                rate: "25%",
                amount: InvoiceTaxCalculator.calculateCapitalGainsTax(for: expectedProfit).formatted(.currency(code: "EUR"))
            ),
            TaxItem(
                name: "Solidaritätszuschlag",
                basis: InvoiceTaxCalculator.calculateCapitalGainsTax(for: expectedProfit).formatted(.currency(code: "EUR")),
                rate: "5,5%",
                amount: InvoiceTaxCalculator.calculateSolidaritySurcharge(for: InvoiceTaxCalculator.calculateCapitalGainsTax(for: expectedProfit)).formatted(.currency(code: "EUR"))
            ),
            TaxItem(
                name: "Kirchensteuer",
                basis: InvoiceTaxCalculator.calculateCapitalGainsTax(for: expectedProfit).formatted(.currency(code: "EUR")),
                rate: "8%",
                amount: InvoiceTaxCalculator.calculateChurchTax(for: InvoiceTaxCalculator.calculateCapitalGainsTax(for: expectedProfit)).formatted(.currency(code: "EUR"))
            )
        ]

        // Run all validations
        let consistencyResult = validateCalculationConsistency(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            expectedProfit: expectedProfit,
            expectedTaxes: expectedTaxes
        )

        let methodsResult = validateCalculationMethods(calculationTrace: calculationTrace)
        let dataResult = validateInvoiceData(buyInvoice: buyInvoice, sellInvoices: sellInvoices)

        // Combine results
        let allErrors = consistencyResult.errors + methodsResult.errors + dataResult.errors
        let allWarnings = consistencyResult.warnings + methodsResult.warnings + dataResult.warnings

        return ValidationResult(
            isValid: allErrors.isEmpty,
            errors: allErrors,
            warnings: allWarnings
        )
    }
}
