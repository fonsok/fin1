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

    /// Creates a platform service charge invoice for investment with 19% VAT
    /// - Parameters:
    ///   - platformServiceCharge: The net platform service charge amount (before VAT)
    ///   - customerInfo: Customer information for the invoice
    ///   - transactionIdService: Service for generating invoice numbers
    ///   - investmentBatchId: Optional batch ID to link the invoice to the investment batch
    /// - Returns: Invoice with platform service charge item and VAT item (19%)
    static func platformServiceChargeInvoice(
        platformServiceCharge: Double,
        customerInfo: CustomerInfo,
        transactionIdService: any TransactionIdServiceProtocol,
        investmentBatchId: String? = nil
    ) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        var items: [InvoiceItem] = []

        // Add platform service charge item (net amount)
        let platformServiceChargeItem = InvoiceItem(
            description: "Plattform-Servicegebühr für Investition",
            quantity: 1,
            unitPrice: platformServiceCharge,
            itemType: .serviceCharge
        )
        items.append(platformServiceChargeItem)

        // Calculate VAT (19% of net amount)
        let vatAmount = platformServiceCharge * CalculationConstants.TaxRates.vatRate

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
            type: .platformServiceCharge,
            customerInfo: customerInfo,
            items: items,
            tradeId: investmentBatchId, // Link to investment batch ID if provided
            orderId: investmentBatchId, // Also store in orderId for consistency
            taxNote: InvoiceNotes.serviceChargeTaxNote,
            legalNote: InvoiceNotes.legalNote,
            dueDate: Calendar.current.date(byAdding: .day, value: 14, to: Date())
        )
    }

    /// Creates a platform service charge invoice for an investor
    /// - Parameters:
    ///   - grossServiceChargeAmount: The gross service charge amount (1.5% of investment amount, includes VAT)
    ///   - customerInfo: Customer information for the invoice
    ///   - transactionIdService: Service for generating invoice numbers
    ///   - batchId: Optional batch ID to link the invoice to an investment batch
    ///   - investmentIds: Array of investment IDs that this service charge applies to
    /// - Returns: Invoice with service charge and VAT items
    /// - Note: The gross amount (1.5% of investment) is split into net service charge and VAT (19%)
    static func forServiceCharge(
        grossServiceChargeAmount: Double,
        customerInfo: CustomerInfo,
        transactionIdService: any TransactionIdServiceProtocol,
        batchId: String? = nil,
        investmentIds: [String] = []
    ) -> Invoice {
        let invoiceNumber = InvoiceNumberGenerator.generate(using: transactionIdService)

        // Calculate net and VAT from gross amount
        // Gross = Net + VAT, where VAT = Net * 19%
        // Therefore: Gross = Net * (1 + 19%) = Net * 1.19
        // Net = Gross / 1.19
        let vatRate = CalculationConstants.TaxRates.vatRate
        let netServiceCharge = grossServiceChargeAmount / (1.0 + vatRate)
        let vatAmount = grossServiceChargeAmount - netServiceCharge

        // Create invoice items
        var items: [InvoiceItem] = []

        // Build description with investment IDs (each ID on a separate line with comma/period)
        var serviceChargeDescription = "Plattform-Servicegebühr für Investition(en)"
        if !investmentIds.isEmpty {
            if investmentIds.count == 1 {
                // Single investment: just add period
                serviceChargeDescription += "\n\(investmentIds[0])."
            } else {
                // Format multiple IDs: each ID on a separate line with comma, last one with period
                var formattedIds: [String] = []
                for (index, id) in investmentIds.enumerated() {
                    if index == investmentIds.count - 1 {
                        // Last ID: add period
                        formattedIds.append("\(id).")
                    } else {
                        // Other IDs: add comma
                        formattedIds.append("\(id),")
                    }
                }
                let idsString = formattedIds.joined(separator: "\n")
                serviceChargeDescription += "\n\(idsString)"
            }
        }

        // Service charge item (net amount)
        items.append(InvoiceItem(
            description: serviceChargeDescription,
            quantity: 1,
            unitPrice: netServiceCharge,
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
            type: .platformServiceCharge,
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

        // Add Issuer (placeholder for now - would need to be passed as parameter)
        // components.append("Issuer")

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

        // Add Issuer (placeholder for now - would need to be added to DepotHolding model)
        // components.append("Issuer")

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
}
