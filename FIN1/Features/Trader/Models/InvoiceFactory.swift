import Foundation

// MARK: - Invoice Factory
extension Invoice {

    /// Creates a securities settlement invoice from an order using actual order values
    static func from(order: OrderBuy, customerInfo: CustomerInfo, transactionIdService: any TransactionIdServiceProtocol, tradeId: String? = nil, tradeNumber: Int? = nil) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        // Create invoice items from actual order data
        var items: [InvoiceItem] = []

        // Add securities item with reorganized description format
        let securitiesDescription = createSecuritiesDescription(
            symbol: order.underlyingAsset ?? order.symbol,
            wkn: order.wkn,
            optionDirection: order.optionDirection,
            strike: order.strike
        )

        print("🔍 InvoiceFactory.from(order:): Creating invoice from OrderBuy")
        print("   📊 order.quantity: \(order.quantity)")
        print("   📊 order.price: \(order.price)")
        print("   📊 order.totalAmount: \(order.totalAmount)")

        let securitiesItem = InvoiceItem(
            description: securitiesDescription,
            quantity: order.quantity,
            unitPrice: order.price,
            itemType: .securities
        )
        print("   ✅ InvoiceItem.quantity: \(securitiesItem.quantity)")
        items.append(securitiesItem)

        // Add fee items
        items.append(contentsOf: createFeeItems(for: order.totalAmount, isSellOrder: false))

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .securitiesSettlement,
            customerInfo: customerInfo,
            items: items,
            tradeId: tradeId ?? order.id, // Use provided tradeId if available, otherwise fall back to order.id
            tradeNumber: tradeNumber,
            orderId: order.id,
            transactionType: .buy,
            taxNote: InvoiceNotes.buyOrderTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a securities settlement invoice from a sell order using actual order values
    static func from(sellOrder: OrderSell, customerInfo: CustomerInfo, transactionIdService: any TransactionIdServiceProtocol, tradeId: String? = nil, tradeNumber: Int? = nil) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        // Create invoice items from actual sell order data
        var items: [InvoiceItem] = []

        // Add securities item with reorganized description format
        let securitiesDescription = createSecuritiesDescription(
            symbol: sellOrder.underlyingAsset ?? sellOrder.symbol,
            wkn: sellOrder.wkn,
            optionDirection: sellOrder.optionDirection,
            strike: sellOrder.strike
        )

        let securitiesItem = InvoiceItem(
            description: securitiesDescription,
            quantity: sellOrder.quantity,
            unitPrice: sellOrder.price,
            itemType: .securities
        )
        items.append(securitiesItem)

        // Add fee items (negative for sell orders)
        items.append(contentsOf: createFeeItems(for: sellOrder.totalAmount, isSellOrder: true))

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .securitiesSettlement,
            customerInfo: customerInfo,
            items: items,
            tradeId: tradeId ?? sellOrder.id, // Use provided tradeId if available, otherwise fall back to order.id
            tradeNumber: tradeNumber,
            orderId: sellOrder.id,
            transactionType: .sell,
            taxNote: InvoiceNotes.sellOrderTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a securities settlement invoice from a holding using actual order values
    static func from(holding: DepotHolding, customerInfo: CustomerInfo, transactionIdService: any TransactionIdServiceProtocol) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        // Create invoice items from actual holding data
        var items: [InvoiceItem] = []

        // Add securities item with reorganized description format
        let securitiesDescription = createHoldingSecuritiesDescription(holding: holding)

        let securitiesItem = InvoiceItem(
            description: securitiesDescription,
            quantity: Double(holding.quantity),
            unitPrice: holding.purchasePrice,
            itemType: .securities
        )
        items.append(securitiesItem)

        // Add fee items
        items.append(contentsOf: createFeeItems(for: holding.totalValue, isSellOrder: false))

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .securitiesSettlement,
            customerInfo: customerInfo,
            items: items,
            tradeId: holding.orderId,
            transactionType: .buy,
            taxNote: InvoiceNotes.buyOrderTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates an app service charge invoice for investment with 19% VAT
    /// - Parameters:
    ///   - appServiceCharge: The net app service charge amount (before VAT)
    ///   - customerInfo: Customer information for the invoice
    ///   - transactionIdService: Service for generating invoice numbers
    ///   - investmentBatchId: Optional batch ID to link the invoice to the investment batch
    /// - Returns: Invoice with app service charge item and VAT item (19%)
    static func appServiceChargeInvoice(
        appServiceCharge: Double,
        customerInfo: CustomerInfo,
        transactionIdService: any TransactionIdServiceProtocol,
        investmentBatchId: String? = nil
    ) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        var items: [InvoiceItem] = []

        // Add app service charge item (net amount)
        let appServiceChargeItem = InvoiceItem(
            description: "App-Servicegebühr für Investition",
            quantity: 1,
            unitPrice: appServiceCharge,
            itemType: .serviceCharge
        )
        items.append(appServiceChargeItem)

        // Calculate VAT (19% of net amount)
        let vatAmount = appServiceCharge * CalculationConstants.TaxRates.vatRate

        // Add VAT item
        let vatItem = InvoiceItem(
            description: "Umsatzsteuer (19%)",
            quantity: 1,
            unitPrice: vatAmount,
            itemType: .vat
        )
        items.append(vatItem)

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .appServiceCharge,
            customerInfo: customerInfo,
            items: items,
            tradeId: investmentBatchId, // Link to investment batch ID if provided
            orderId: investmentBatchId, // Also store in orderId for consistency
            taxNote: InvoiceNotes.serviceChargeTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates an app service charge invoice for an investor
    /// - Parameters:
    ///   - grossServiceChargeAmount: The gross service charge amount (includes VAT)
    ///   - customerInfo: Customer information for the invoice
    ///   - transactionIdService: Service for generating invoice numbers
    ///   - batchId: Optional batch ID to link the invoice to an investment batch
    ///   - investmentIds: Array of investment IDs that this service charge applies to
    ///   - investmentAmounts: Array of investment amounts corresponding to investmentIds (for detailed description)
    ///   - serviceChargeRate: App service charge rate (default: 2% from CalculationConstants)
    /// - Returns: Invoice with service charge and VAT items
    /// - Note: The gross amount is split into net service charge and VAT (19%)
    static func forServiceCharge(
        grossServiceChargeAmount: Double,
        customerInfo: CustomerInfo,
        transactionIdService: any TransactionIdServiceProtocol,
        batchId: String? = nil,
        investmentIds: [String] = [],
        investmentAmounts: [Double] = [],
        serviceChargeRate: Double = CalculationConstants.ServiceCharges.appServiceChargeRate,
        includeVAT: Bool = true
    ) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        let netServiceCharge: Double
        let vatAmount: Double
        if includeVAT {
            // Calculate net and VAT from gross amount
            // Gross = Net + VAT, where VAT = Net * 19%
            // Therefore: Gross = Net * (1 + 19%) = Net * 1.19
            // Net = Gross / 1.19
            let vatRate = CalculationConstants.TaxRates.vatRate
            netServiceCharge = grossServiceChargeAmount / (1.0 + vatRate)
            vatAmount = grossServiceChargeAmount - netServiceCharge
        } else {
            netServiceCharge = grossServiceChargeAmount
            vatAmount = 0
        }

        // Create invoice items
        var items: [InvoiceItem] = []

        // Build detailed description with calculation basis, investment amounts, IDs, and split
        let serviceChargeDescription = buildServiceChargeDescription(
            investmentIds: investmentIds,
            investmentAmounts: investmentAmounts,
            totalInvestmentAmount: investmentAmounts.reduce(0, +),
            serviceChargeRate: serviceChargeRate,
            netServiceCharge: netServiceCharge,
            vatAmount: vatAmount
        )

        // Service charge item (net amount)
        items.append(InvoiceItem(
            description: serviceChargeDescription,
            quantity: 1,
            unitPrice: netServiceCharge,
            itemType: .serviceCharge
        ))

        // VAT item (19%) for private persons.
        if includeVAT {
            items.append(InvoiceItem(
                description: "Umsatzsteuer (19%)",
                quantity: 1,
                unitPrice: vatAmount,
                itemType: .vat
            ))
        }

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .appServiceCharge,
            status: .generated,
            customerInfo: customerInfo,
            items: items,
            tradeId: batchId, // Link to investment batch if provided
            taxNote: InvoiceNotes.serviceChargeTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    // MARK: - Commission Invoice Methods
    // Note: Commission-related factory methods (forCommission, creditNote, commissionInvoice)
    // have been extracted to CommissionInvoiceFactory.swift to reduce file size.

    // MARK: - Credit Note / Gutschrift for Fee Refunds

    /// Creates a credit note (Gutschrift) for a fee refund to an investor or trader.
    /// Used when platform fees are refunded after a correction is approved (4-eyes).
    static func forFeeRefund(
        grossRefundAmount: Double,
        customerInfo: CustomerInfo,
        transactionIdService: any TransactionIdServiceProtocol,
        originalInvoiceNumber: String? = nil,
        reason: String,
        correctionRequestId: String? = nil
    ) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        let vatRate = CalculationConstants.TaxRates.vatRate
        let netAmount = grossRefundAmount / (1.0 + vatRate)
        let vatAmount = grossRefundAmount - netAmount

        var refundDescription = "Gutschrift Appgebühr"
        if let original = originalInvoiceNumber {
            refundDescription += " (Ref: \(original))"
        }
        refundDescription += "\nBegründung: \(reason)"

        var items: [InvoiceItem] = []

        items.append(InvoiceItem(
            description: refundDescription,
            quantity: 1,
            unitPrice: -netAmount,
            itemType: .serviceCharge
        ))

        items.append(InvoiceItem(
            description: "Umsatzsteuer-Korrektur (19%)",
            quantity: 1,
            unitPrice: -vatAmount,
            itemType: .vat
        ))

        return Invoice(
            invoiceNumber: invoiceNumber,
            type: .creditNote,
            status: .generated,
            customerInfo: customerInfo,
            items: items,
            tradeId: correctionRequestId,
            taxNote: "Gutschrift gem. § 14 Abs. 2 UStG. Der Vorsteuerabzug aus der Originalrechnung ist entsprechend zu berichtigen.",
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a sample invoice for testing with realistic order values
    static func sampleInvoice(tradeId: String? = nil, transactionType: TransactionType = .buy) -> Invoice {
        let customerInfo = CustomerInfo(
            name: "Anton Huber",
            address: "Hauptstraße 42",
            city: "München",
            postalCode: "80311",
            taxNumber: "43/123/45678",
            depotNumber: "DE12345678901234567890",
            bank: "Deutsche Bank AG",
            customerNumber: "DB-2024-001234"
        )

        // Realistic order values
        let quantity = 750.0
        let unitPrice = 1.85
        let orderAmount = quantity * unitPrice
        let isSellOrder = transactionType == .sell

        let items = [
            InvoiceItem(
                description: "PUT|DAX|VT1234",
                quantity: quantity,
                unitPrice: unitPrice,
                itemType: .securities
            )
        ] + createFeeItems(for: orderAmount, isSellOrder: isSellOrder)

        return Invoice(
            invoiceNumber: InvoiceNumberGenerator.generateLegacy(),
            type: .securitiesSettlement,
            customerInfo: customerInfo,
            items: items,
            tradeId: tradeId, // Use provided tradeId for linking with specific trades
            transactionType: transactionType,
            taxNote: isSellOrder ? InvoiceNotes.sellOrderTaxNote : InvoiceNotes.buyOrderTaxNote,
            legalNote: InvoiceNotes.legalNote
        )
    }
}

// MARK: - Private Helper Methods
private extension Invoice {

    /// Creates securities description for orders in the format: WKN/ISIN - direction - underlying - strike price - issuer
    static func createSecuritiesDescription(symbol: String, wkn: String?, optionDirection: String?, strike: Double?) -> String {
        var components: [String] = []

        // Add WKN/ISIN first
        if let wkn = wkn, !wkn.isEmpty {
            components.append(wkn)
        }

        // Add Direction if available
        if let optionDirection = optionDirection, !optionDirection.isEmpty {
            components.append(optionDirection)
        }

        // Add UnderlyingAsset (symbol)
        components.append(symbol)

        // Add Strike Price
        if let strike = strike {
            let strikePrice = DepotUtils.formatStrikePrice(strike, symbol)
            components.append(strikePrice)
        }

        // Add Issuer (Emittent) derived from WKN
        if let wkn = wkn, !wkn.isEmpty {
            components.append(String.emittentName(forWKN: wkn))
        }

        return components.joined(separator: " - ")
    }

    /// Creates securities description for holdings in the format: WKN/ISIN - direction - underlying - strike price - issuer
    static func createHoldingSecuritiesDescription(holding: DepotHolding) -> String {
        var components: [String] = []

        // Add WKN/ISIN first
        components.append(holding.wkn)

        // Add Direction if available
        if let direction = holding.direction, !direction.isEmpty {
            components.append(direction)
        }

        // Add UnderlyingAsset (designation)
        components.append(holding.designation)

        // Add Strike Price
        let strikePrice = DepotUtils.formatStrikePrice(holding.strike, holding.underlyingAsset)
        components.append(strikePrice)

        // Add Issuer (Emittent) derived from WKN
        components.append(String.emittentName(forWKN: holding.wkn))

        return components.joined(separator: " - ")
    }

    /// Creates fee items for an order
    static func createFeeItems(for orderAmount: Double, isSellOrder: Bool) -> [InvoiceItem] {
        return [
            InvoiceFeeCalculator.createOrderFeeItem(for: orderAmount, isNegative: isSellOrder),
            InvoiceFeeCalculator.createExchangeFeeItem(for: orderAmount, isNegative: isSellOrder),
            InvoiceFeeCalculator.createForeignCostsItem(isNegative: isSellOrder)
        ]
    }

    /// Builds a detailed service charge description with calculation basis, investment amounts, IDs, and split
    static func buildServiceChargeDescription(
        investmentIds: [String],
        investmentAmounts: [Double],
        totalInvestmentAmount: Double,
        serviceChargeRate: Double,
        netServiceCharge: Double,
        vatAmount: Double
    ) -> String {
        var description = "App-Servicegebühr für Investition(en)"

        // Add calculation basis
        if totalInvestmentAmount > 0 {
            let formattedTotal = totalInvestmentAmount.formatted(.currency(code: "EUR"))
            let ratePercent = (serviceChargeRate * 100).formatted(.number.precision(.fractionLength(2)))
            description += "\n\nBerechnungsgrundlage:"
            description += "\nInvestitionsbetrag gesamt: \(formattedTotal)"
            description += "\nServicegebühr-Satz: \(ratePercent)%"
        }

        // Add investment details (split information) - show individual investments if multiple
        if !investmentIds.isEmpty {
            if investmentIds.count > 1 {
                description += "\n\nAufteilung auf \(investmentIds.count) Investition(en):"
            } else {
                description += "\n\nInvestition:"
            }

            // Match IDs with amounts (if arrays have same length)
            let count = min(investmentIds.count, investmentAmounts.count)
            if count > 0 {
                for index in 0..<count {
                    let id = investmentIds[index]
                    let amount = investmentAmounts[index]
                    let formattedAmount = amount.formatted(.currency(code: "EUR"))
                    let separator = index < count - 1 ? "," : "."
                    description += "\nBuchungsnummer \(id): \(formattedAmount)\(separator)"
                }
            } else {
                // Fallback: just show IDs if amounts not available
                for (index, id) in investmentIds.enumerated() {
                    let separator = index < investmentIds.count - 1 ? "," : "."
                    description += "\nBuchungsnummer \(id)\(separator)"
                }
            }
        }

        return description
    }
}
