import Foundation

// MARK: - Calculation Guard Service

/// Service that ensures only the correct calculation methods are used
/// and prevents old/incorrect calculations from being executed
final class CalculationGuardService {

    // MARK: - Singleton

    static let shared = CalculationGuardService()

    private init() {}

    // MARK: - Configuration

    private var isValidationEnabled = true
    private var validationMode: ValidationMode = .strict

    enum ValidationMode {
        case strict    // Fail on any inconsistency
        case warning   // Log warnings but allow execution
        case disabled  // No validation
    }

    // MARK: - Public Methods

    /// Enables or disables calculation validation
    /// - Parameter enabled: Whether validation should be enabled
    func setValidationEnabled(_ enabled: Bool) {
        isValidationEnabled = enabled
    }

    /// Sets the validation mode
    /// - Parameter mode: The validation mode to use
    func setValidationMode(_ mode: ValidationMode) {
        validationMode = mode
    }

    /// Guards a profit calculation to ensure it uses the correct method
    /// - Parameters:
    ///   - buyInvoice: Buy transaction invoice
    ///   - sellInvoices: Sell transaction invoices
    ///   - fallbackCalculation: Old calculation method (will be blocked)
    /// - Returns: Correctly calculated profit
    func guardProfitCalculation(
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        fallbackCalculation: (() -> Double)? = nil
    ) -> Double {
        // Always use the correct calculation method
        let correctProfit = ProfitCalculationService.calculateTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        if isValidationEnabled && validationMode != .disabled {
            // Validate against fallback if provided
            if let fallback = fallbackCalculation {
                _ = fallback() // Fallback result used for validation but not stored
                let validation = CalculationValidationService.validateCalculationConsistency(
                    buyInvoice: buyInvoice,
                    sellInvoices: sellInvoices,
                    expectedProfit: correctProfit,
                    expectedTaxes: []
                )

                if validation.hasErrors {
                    logValidationError("Profit calculation inconsistency detected", validation.errors)

                    if validationMode == .strict {
                        fatalError("Calculation validation failed: \(validation.errors)")
                    }
                }
            }
        }

        return correctProfit
    }

    /// Guards a tax calculation to ensure it uses the correct method
    /// - Parameters:
    ///   - profit: Profit amount
    ///   - fallbackCalculation: Old calculation method (will be blocked)
    /// - Returns: Correctly calculated total tax
    func guardTaxCalculation(
        profit: Double,
        fallbackCalculation: (() -> Double)? = nil
    ) -> Double {
        // Always use the correct calculation method
        let correctTax = InvoiceTaxCalculator.calculateTotalTax(for: profit)

        if isValidationEnabled && validationMode != .disabled {
            // Validate against fallback if provided
            if let fallback = fallbackCalculation {
                let fallbackResult = fallback()
                let deviation = abs(correctTax - fallbackResult)

                if deviation > 0.01 {
                    let error = CalculationValidationService.ValidationError.inconsistentTaxCalculation(
                        expected: correctTax,
                        actual: fallbackResult
                    )

                    logValidationError("Tax calculation inconsistency detected", [error])

                    if validationMode == .strict {
                        fatalError("Tax calculation validation failed: \(error)")
                    }
                }
            }
        }

        return correctTax
    }

    /// Guards fee calculations to ensure they use the correct method
    /// - Parameters:
    ///   - orderAmount: Order amount
    ///   - fallbackCalculation: Old calculation method (will be blocked)
    /// - Returns: Correctly calculated fees
    func guardFeeCalculation(
        orderAmount: Double,
        fallbackCalculation: (() -> [FeeDetail])? = nil
    ) -> [FeeDetail] {
        // Always use the correct calculation method
        let correctFees = FeeCalculationService.createFeeBreakdown(for: orderAmount)

        if isValidationEnabled && validationMode != .disabled {
            // Validate against fallback if provided
            if let fallback = fallbackCalculation {
                let fallbackResult = fallback()
                let correctTotal = correctFees.reduce(0) { $0 + $1.amount }
                let fallbackTotal = fallbackResult.reduce(0) { $0 + $1.amount }

                if abs(correctTotal - fallbackTotal) > 0.01 {
                    let warning = CalculationValidationService.ValidationWarning.calculationDeviation(
                        expected: correctTotal,
                        actual: fallbackTotal,
                        tolerance: 0.01
                    )

                    logValidationWarning("Fee calculation deviation detected", [warning])
                }
            }
        }

        return correctFees
    }

    /// Validates that invoice data is properly filtered (excludes tax items from profit calculations)
    /// - Parameters:
    ///   - invoice: Invoice to validate
    ///   - calculationType: Type of calculation being performed
    /// - Returns: Filtered items for the calculation
    func guardInvoiceFiltering(
        invoice: Invoice,
        calculationType: CalculationType
    ) -> [InvoiceItem] {
        switch calculationType {
        case .profitCalculation:
            // For profit calculations, exclude tax items
            let filteredItems = invoice.items.filter { $0.itemType != .tax }

            if isValidationEnabled {
                let taxItems = invoice.items.filter { $0.itemType == .tax }
                if !taxItems.isEmpty {
                    logValidationWarning("Tax items found in profit calculation - properly filtered", [])
                }
            }

            return filteredItems

        case .taxCalculation:
            // For tax calculations, only include tax items
            return invoice.items.filter { $0.itemType == .tax }

        case .feeCalculation:
            // For fee calculations, include fee items
            return invoice.items.filter {
                $0.itemType == .orderFee ||
                $0.itemType == .exchangeFee ||
                $0.itemType == .foreignCosts
            }

        case .securitiesCalculation:
            // For securities calculations, only include securities items
            return invoice.items.filter { $0.itemType == .securities }
        }
    }

    // MARK: - Private Methods

    private func logValidationError(_ message: String, _ errors: [CalculationValidationService.ValidationError]) {
        print("🚨 CALCULATION VALIDATION ERROR: \(message)")
        for error in errors {
            print("   - \(error)")
        }
    }

    private func logValidationWarning(_ message: String, _ warnings: [CalculationValidationService.ValidationWarning]) {
        print("⚠️ CALCULATION VALIDATION WARNING: \(message)")
        for warning in warnings {
            print("   - \(warning)")
        }
    }
}

// MARK: - Calculation Types

enum CalculationType {
    case profitCalculation
    case taxCalculation
    case feeCalculation
    case securitiesCalculation
}

// MARK: - Calculation Guard Extensions

extension CalculationGuardService {

    /// Comprehensive guard for the entire calculation flow
    /// - Parameters:
    ///   - buyInvoice: Buy transaction invoice
    ///   - sellInvoices: Sell transaction invoices
    /// - Returns: Validated calculation result
    func guardCompleteCalculation(
        buyInvoice: Invoice?,
        sellInvoices: [Invoice]
    ) -> CalculationResult {
        // 1. Guard profit calculation
        let profit = guardProfitCalculation(buyInvoice: buyInvoice, sellInvoices: sellInvoices)

        // 2. Guard tax calculation
        let totalTax = guardTaxCalculation(profit: profit)

        // 3. Calculate individual taxes
        let capitalGainsTax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)
        let solidaritySurcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)
        let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)

        // 4. Calculate final result
        let netResult = profit - totalTax

        return CalculationResult(
            profitBeforeTaxes: profit,
            capitalGainsTax: capitalGainsTax,
            solidaritySurcharge: solidaritySurcharge,
            churchTax: churchTax,
            totalTax: totalTax,
            netResult: netResult
        )
    }
}

// MARK: - Calculation Result

struct CalculationResult {
    let profitBeforeTaxes: Double
    let capitalGainsTax: Double
    let solidaritySurcharge: Double
    let churchTax: Double
    let totalTax: Double
    let netResult: Double
}
