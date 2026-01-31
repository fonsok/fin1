import Foundation

// MARK: - Trade Calculation Service

/// Service for detailed trade calculations including transactions, fees, and taxes
final class TradeCalculationService {
    private let calculationGuardService: CalculationGuardService

    init(calculationGuardService: CalculationGuardService = CalculationGuardService.shared) {
        self.calculationGuardService = calculationGuardService
    }

    // MARK: - Transaction Breakdown Models

    struct TransactionBreakdown {
        let wknIsin: String
        let direction: String
        let underlying: String
        let strikePrice: Double?
        let issuer: String

        let buyTransaction: TransactionDetails?
        let sellTransactions: [TransactionDetails]

        let profitBeforeTaxes: Double
        let totalTaxes: Double
        let netResult: Double
    }

    // TransactionDetails and FeeDetail are now defined in ProfitCalculationService

    struct TaxBreakdown {
        let capitalGainsTax: Double
        let solidaritySurcharge: Double
        let churchTax: Double
        let totalTaxes: Double
    }

    // MARK: - Public Methods

    /// Calculate detailed breakdown for a trade
    func calculateTradeBreakdown(for trade: Trade, buyInvoice: Invoice?, sellInvoices: [Invoice]) -> TransactionBreakdown {
        // Extract trade information
        let wknIsin = extractWknIsin(from: trade)
        let direction = extractDirection(from: trade)
        let underlying = extractUnderlying(from: trade)
        let strikePrice = extractStrikePrice(from: trade)
        let issuer = extractIssuer(from: trade)

        // Calculate buy transaction
        let buyTransaction = calculateBuyTransaction(trade: trade, invoice: buyInvoice)

        // Calculate sell transactions
        let sellTransactions = calculateSellTransactions(trade: trade, invoices: sellInvoices)

        // Calculate profit before taxes
        let profitBeforeTaxes = calculateProfitBeforeTaxes(
            buyTransaction: buyTransaction,
            sellTransactions: sellTransactions
        )

        // Calculate taxes
        let taxBreakdown = calculateTaxBreakdown(profit: profitBeforeTaxes)

        // Calculate net result
        let netResult = profitBeforeTaxes - taxBreakdown.totalTaxes

        return TransactionBreakdown(
            wknIsin: wknIsin,
            direction: direction,
            underlying: underlying,
            strikePrice: strikePrice,
            issuer: issuer,
            buyTransaction: buyTransaction,
            sellTransactions: sellTransactions,
            profitBeforeTaxes: profitBeforeTaxes,
            totalTaxes: taxBreakdown.totalTaxes,
            netResult: netResult
        )
    }

    // MARK: - Private Methods

    private func extractWknIsin(from trade: Trade) -> String {
        // Try to get WKN/ISIN from buy order
        if let wkn = trade.buyOrder.wkn, !wkn.isEmpty {
            return wkn
        }
        return "N/A"
    }

    private func extractDirection(from trade: Trade) -> String {
        // Determine if it's a call or put based on option direction
        if let optionDirection = trade.buyOrder.optionDirection {
            return optionDirection == "CALL" ? "Call" : "Put"
        }
        return "N/A"
    }

    private func extractUnderlying(from trade: Trade) -> String {
        if let underlying = trade.buyOrder.underlyingAsset, !underlying.isEmpty {
            return underlying
        }
        return "N/A"
    }

    private func extractStrikePrice(from trade: Trade) -> Double? {
        return trade.buyOrder.strike
    }

    private func extractIssuer(from trade: Trade) -> String {
        // Extract issuer from symbol or description
        let symbol = trade.buyOrder.symbol
        if symbol.contains("VONT") {
            return "Vontobel"
        } else if symbol.contains("HSBC") {
            return "HSBC"
        }
        return "N/A"
    }

    private func calculateBuyTransaction(trade: Trade, invoice: Invoice?) -> TransactionDetails? {
        guard let invoice = invoice else { return nil }

        let quantity = trade.buyOrder.quantity
        let price = trade.buyOrder.price
        let amount = quantity * price

        let fees = calculateFees(from: invoice)
        let subtotal = amount + fees.reduce(0) { $0 + $1.amount }

        return TransactionDetails(
            type: .buy,
            quantity: quantity,
            price: price,
            amount: amount,
            fees: fees,
            subtotal: subtotal
        )
    }

    private func calculateSellTransactions(trade: Trade, invoices: [Invoice]) -> [TransactionDetails] {
        let sellOrders = trade.sellOrders.isEmpty ?
            (trade.sellOrder.map { [$0] } ?? []) :
            trade.sellOrders

        return sellOrders.enumerated().compactMap { _, sellOrder in
            // Find corresponding invoice
            let invoice = invoices.first { invoice in
                // Match by quantity and price if possible
                let securityItems = invoice.items.filter { $0.itemType == .securities }
                if let securityItem = securityItems.first {
                    return abs(securityItem.quantity - sellOrder.quantity) < 0.01 &&
                           abs(securityItem.unitPrice - sellOrder.price) < 0.01
                }
                return false
            }

            guard let invoice = invoice else { return nil }

            let quantity = sellOrder.quantity
            let price = sellOrder.price
            let amount = quantity * price

            let fees = calculateSellFees(from: invoice)
            let subtotal = amount + fees.reduce(0) { $0 + $1.amount }

            return TransactionDetails(
                type: .sell,
                quantity: quantity,
                price: price,
                amount: amount,
                fees: fees,
                subtotal: subtotal
            )
        }
    }

    private func calculateFees(from invoice: Invoice) -> [FeeDetail] {
        // Extract securities amount to calculate fees
        let securitiesItems = invoice.items.filter { $0.itemType == .securities }
        let securitiesAmount = securitiesItems.reduce(0) { $0 + $1.totalAmount }

        // Use centralized fee calculation service
        return FeeCalculationService.createFeeBreakdown(for: securitiesAmount)
    }

    private func calculateSellFees(from invoice: Invoice) -> [FeeDetail] {
        // Extract securities amount to calculate fees
        let securitiesItems = invoice.items.filter { $0.itemType == .securities }
        let securitiesAmount = securitiesItems.reduce(0) { $0 + $1.totalAmount }

        // Use centralized fee calculation service and make fees negative for sell transactions
        let feeBreakdown = FeeCalculationService.createFeeBreakdown(for: securitiesAmount)
        return feeBreakdown.map { fee in
            FeeDetail(name: fee.name, amount: -fee.amount) // Make sell fees negative
        }
    }

    private func calculateProfitBeforeTaxes(
        buyTransaction: TransactionDetails?,
        sellTransactions: [TransactionDetails]
    ) -> Double {
        // Use centralized profit calculation service
        return ProfitCalculationService.calculateProfitBeforeTaxes(
            buyTransaction: buyTransaction,
            sellTransactions: sellTransactions
        )
    }

    private func calculateTaxBreakdown(profit: Double) -> TaxBreakdown {
        // Use centralized tax calculation from InvoiceTaxCalculator
        let capitalGainsTax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: profit)
        let solidaritySurcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)
        let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)
        let totalTaxes = calculationGuardService.guardTaxCalculation(profit: profit)

        return TaxBreakdown(
            capitalGainsTax: capitalGainsTax,
            solidaritySurcharge: solidaritySurcharge,
            churchTax: churchTax,
            totalTaxes: totalTaxes
        )
    }
}

// CalculationTransactionType is now defined in ProfitCalculationService
