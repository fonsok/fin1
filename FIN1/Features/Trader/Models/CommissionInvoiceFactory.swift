import Foundation

// MARK: - Commission Invoice Factory
/// Factory methods for creating commission-related invoices
/// Extracted from InvoiceFactory to reduce file size
extension Invoice {

    /// Creates a trader commission invoice for investment completion with 19% VAT
    /// - Parameters:
    ///   - grossCommissionAmount: The gross commission amount (includes VAT)
    ///   - customerInfo: Customer information for the invoice
    ///   - transactionIdService: Service for generating invoice numbers
    ///   - investmentId: Investment ID to link the invoice to
    /// - Returns: Invoice with commission item and VAT item (19%)
    static func forCommission(
        grossCommissionAmount: Double,
        customerInfo: CustomerInfo,
        transactionIdService: any TransactionIdServiceProtocol,
        investmentId: String
    ) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        // Calculate net and VAT from gross amount
        // Gross = Net + VAT, where VAT = Net * 19%
        // Therefore: Gross = Net * (1 + 19%) = Net * 1.19
        // Net = Gross / 1.19
        let vatRate = CalculationConstants.TaxRates.vatRate
        let netCommission = grossCommissionAmount / (1.0 + vatRate)
        let vatAmount = grossCommissionAmount - netCommission

        // Create invoice items
        var items: [InvoiceItem] = []

        // Commission item (net amount)
        items.append(InvoiceItem(
            description: "Trader-Provision für Investition\n\(investmentId).",
            quantity: 1,
            unitPrice: netCommission,
            itemType: .serviceCharge
        ))

        // VAT item (19%)
        items.append(InvoiceItem(
            description: "Umsatzsteuer (19%)",
            quantity: 1,
            unitPrice: vatAmount,
            itemType: .vat
        ))

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .commissionInvoice,
            status: .generated,
            customerInfo: customerInfo,
            items: items,
            tradeId: investmentId, // Link to investment ID
            taxNote: InvoiceNotes.serviceChargeTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a credit note for trader commission payment
    /// - Parameters:
    ///   - totalCommissionAmount: Total commission amount (gross, includes VAT)
    ///   - customerInfo: Trader customer information
    ///   - transactionIdService: Service for generating invoice numbers
    ///   - tradeNumbers: Array of trade numbers included in this settlement
    ///   - commissions: Array of commission accumulations for detail breakdown
    /// - Returns: Credit note invoice with commission items
    static func creditNote(
        totalCommissionAmount: Double,
        customerInfo: CustomerInfo,
        transactionIdService: any TransactionIdServiceProtocol,
        tradeNumbers: [Int],
        commissions: [CommissionAccumulation]
    ) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        // Calculate net and VAT from gross amount
        let vatRate = CalculationConstants.TaxRates.vatRate
        let netCommission = totalCommissionAmount / (1.0 + vatRate)
        let vatAmount = totalCommissionAmount - netCommission

        // Create invoice items
        var items: [InvoiceItem] = []

        // Build description with trade numbers
        let commissionDescription = CommissionInvoiceDescriptionBuilder.buildTradeDescription(
            baseText: "Trader-Provision für Trades",
            tradeNumbers: tradeNumbers
        )

        // Commission item (net amount) - positive for credit note
        items.append(InvoiceItem(
            description: commissionDescription,
            quantity: 1,
            unitPrice: netCommission,
            itemType: .commission
        ))

        // VAT item (19%)
        items.append(InvoiceItem(
            description: "Umsatzsteuer (19%)",
            quantity: 1,
            unitPrice: vatAmount,
            itemType: .vat
        ))

        // Use first trade number for single trade, nil for multiple (detail is in description)
        let primaryTradeNumber = tradeNumbers.count == 1 ? tradeNumbers.first : nil

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .creditNote,
            status: .generated,
            customerInfo: customerInfo,
            items: items,
            tradeNumber: primaryTradeNumber,
            taxNote: InvoiceNotes.serviceChargeTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a commission invoice for investor showing accumulated commissions
    /// - Parameters:
    ///   - totalCommissionAmount: Total commission amount for this investor (gross, includes VAT)
    ///   - customerInfo: Investor customer information
    ///   - transactionIdService: Service for generating invoice numbers
    ///   - commissions: Array of commission accumulations for detail breakdown
    /// - Returns: Commission invoice with commission items
    static func commissionInvoice(
        totalCommissionAmount: Double,
        customerInfo: CustomerInfo,
        transactionIdService: any TransactionIdServiceProtocol,
        commissions: [CommissionAccumulation]
    ) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        // Calculate net and VAT from gross amount
        let vatRate = CalculationConstants.TaxRates.vatRate
        let netCommission = totalCommissionAmount / (1.0 + vatRate)
        let vatAmount = totalCommissionAmount - netCommission

        // Create invoice items
        var items: [InvoiceItem] = []

        // Build description with trade numbers
        let tradeNumbers = Array(Set(commissions.map { $0.tradeNumber })).sorted()
        let commissionDescription = CommissionInvoiceDescriptionBuilder.buildTradeDescription(
            baseText: "Trader-Provision für Trades",
            tradeNumbers: tradeNumbers
        )

        // Commission item (net amount) - negative for invoice (debit)
        items.append(InvoiceItem(
            description: commissionDescription,
            quantity: 1,
            unitPrice: -netCommission, // Negative for invoice (debit)
            itemType: .commission
        ))

        // VAT item (19%) - negative for invoice
        items.append(InvoiceItem(
            description: "Umsatzsteuer (19%)",
            quantity: 1,
            unitPrice: -vatAmount, // Negative for invoice (debit)
            itemType: .vat
        ))

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .commissionInvoice,
            status: .generated,
            customerInfo: customerInfo,
            items: items,
            taxNote: InvoiceNotes.serviceChargeTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }
}

// MARK: - Commission Description Builder
/// Helper for building commission invoice descriptions
enum CommissionInvoiceDescriptionBuilder {

    /// Builds a trade description string with formatted trade numbers
    /// - Parameters:
    ///   - baseText: The base description text
    ///   - tradeNumbers: Array of trade numbers to include
    /// - Returns: Formatted description string
    static func buildTradeDescription(baseText: String, tradeNumbers: [Int]) -> String {
        var description = baseText

        guard !tradeNumbers.isEmpty else {
            return description
        }

        let formattedTradeNumbers = tradeNumbers.map { String(format: "%03d", $0) }

        if formattedTradeNumbers.count == 1 {
            description += "\nTrade #\(formattedTradeNumbers[0])."
        } else {
            // Format multiple trade numbers: each on a separate line with comma, last one with period
            var formatted: [String] = []
            for (index, tradeNum) in formattedTradeNumbers.enumerated() {
                if index == formattedTradeNumbers.count - 1 {
                    formatted.append("Trade #\(tradeNum).")
                } else {
                    formatted.append("Trade #\(tradeNum),")
                }
            }
            description += "\n\(formatted.joined(separator: "\n"))"
        }

        return description
    }
}











