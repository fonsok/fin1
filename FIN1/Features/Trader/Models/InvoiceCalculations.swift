import Foundation

// MARK: - Invoice Fee Calculations
struct InvoiceFeeCalculator {

    /// Calculates order fee based on order amount
    /// Uses CalculationConstants for consistency with FeeCalculationService
    /// - Parameter orderAmount: The total order amount
    /// - Returns: Order fee amount (0.5% of order amount, minimum €5, maximum €50)
    static func calculateOrderFee(for orderAmount: Double) -> Double {
        let rate = orderAmount * CalculationConstants.FeeRates.orderFeeRate
        return max(
            CalculationConstants.FeeRates.orderFeeMinimum,
            min(CalculationConstants.FeeRates.orderFeeMaximum, rate)
        )
    }

    /// Calculates exchange fee based on order amount
    /// Uses CalculationConstants for consistency with FeeCalculationService
    /// - Parameter orderAmount: The total order amount
    /// - Returns: Exchange fee amount (0.1% of order amount, minimum €1, maximum €20)
    static func calculateExchangeFee(for orderAmount: Double) -> Double {
        let rate = orderAmount * CalculationConstants.FeeRates.exchangeFeeRate
        return max(
            CalculationConstants.FeeRates.exchangeFeeMinimum,
            min(CalculationConstants.FeeRates.exchangeFeeMaximum, rate)
        )
    }

    /// Calculates foreign costs (fixed amount)
    /// Uses CalculationConstants for consistency with FeeCalculationService
    /// - Returns: Foreign costs amount (€1.50 for domestic trades)
    static func calculateForeignCosts() -> Double {
        return CalculationConstants.FeeRates.foreignCosts
    }

    /// Creates order fee invoice item
    /// - Parameters:
    ///   - orderAmount: The total order amount
    ///   - isNegative: Whether the fee should be negative (for sell orders)
    /// - Returns: InvoiceItem for order fee
    static func createOrderFeeItem(for orderAmount: Double, isNegative: Bool = false) -> InvoiceItem {
        let amount = calculateOrderFee(for: orderAmount)
        return InvoiceItem(
            description: "Ordergebühr",
            quantity: 1,
            unitPrice: isNegative ? -amount : amount,
            itemType: .orderFee
        )
    }

    /// Creates exchange fee invoice item
    /// - Parameters:
    ///   - orderAmount: The total order amount
    ///   - isNegative: Whether the fee should be negative (for sell orders)
    /// - Returns: InvoiceItem for exchange fee
    static func createExchangeFeeItem(for orderAmount: Double, isNegative: Bool = false) -> InvoiceItem {
        let amount = calculateExchangeFee(for: orderAmount)
        return InvoiceItem(
            description: "Börsenplatzgebühr (XETRA)",
            quantity: 1,
            unitPrice: isNegative ? -amount : amount,
            itemType: .exchangeFee
        )
    }

    /// Creates foreign costs invoice item
    /// - Parameter isNegative: Whether the fee should be negative (for sell orders)
    /// - Returns: InvoiceItem for foreign costs
    static func createForeignCostsItem(isNegative: Bool = false) -> InvoiceItem {
        let amount = calculateForeignCosts()
        return InvoiceItem(
            description: "Fremdkostenpauschale",
            quantity: 1,
            unitPrice: isNegative ? -amount : amount,
            itemType: .foreignCosts
        )
    }
}

// MARK: - Invoice Number Generator
struct InvoiceNumberGenerator {

    /// Generates a unique invoice number using the new TransactionIdService
    /// - Parameter transactionIdService: The service to use for ID generation
    /// - Returns: Invoice number in format <PREFIX>-INV-YYYYMMDD-XXXXX
    static func generate(using transactionIdService: any TransactionIdServiceProtocol) -> String {
        return transactionIdService.generateInvoiceNumber()
    }

    /// Legacy method for backward compatibility - generates old format
    /// - Returns: Invoice number in format YYYYMMDD-XXXX
    static func generateLegacy() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let dateString = formatter.string(from: Date())
        let randomNumber = Int.random(in: 1000...9999)
        return "\(dateString)-\(randomNumber)"
    }
}

// MARK: - Invoice Notes
struct InvoiceNotes {

    /// Tax note for buy orders
    static let buyOrderTaxNote = """
    Steuerlicher Hinweis:
    Beim Kauf werden keine Steuern abgezogen. Die Besteuerung erfolgt erst beim Verkauf bzw. Gewinnrealisierung gemäß Abgeltungsteuer (dzt. \(CalculationConstants.TaxRates.capitalGainsTaxWithSoli)).

    Rechtlicher Hinweis:
    Die Versteuerung erfolgt mit Gewinnrealisierung laut aktueller Regelung (§ 20 EStG).
    """

    /// Tax note for sell orders
    static let sellOrderTaxNote = """
    Steuerlicher Hinweis:
    Beim Verkauf erfolgt die Besteuerung gemäß Abgeltungsteuer (dzt. \(CalculationConstants.TaxRates.capitalGainsTaxWithSoli)) auf den realisierten Gewinn. Die Steuer wird automatisch von der Bank einbehalten.

    Rechtlicher Hinweis:
    Die Versteuerung erfolgt mit Gewinnrealisierung laut aktueller Regelung (§ 20 EStG).
    """

    /// Legal note for all invoices
    static let legalNote = "Diese Abrechnung erfolgt nach den Bestimmungen des Wertpapierhandelsgesetzes (WpHG) und der Wertpapierhandelsverordnung (WpDVerOV)."

    /// Tax note for service charge invoices
    static let serviceChargeTaxNote = """
    Steuerlicher Hinweis:
    Die Plattform-Servicegebühr unterliegt der Umsatzsteuer (\(CalculationConstants.VATRates.standardVATPercentage)). Der Rechnungsbetrag ist bereits die Bruttosumme inklusive Umsatzsteuer.

    Rechtlicher Hinweis:
    Diese Gebühr wird bei Erstellung der Investition fällig und ist nicht erstattungsfähig.
    """
}
