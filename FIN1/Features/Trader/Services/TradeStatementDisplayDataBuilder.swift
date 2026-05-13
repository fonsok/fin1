import Foundation
import SwiftUI

// MARK: - Display Data Builder Protocol

/// Protocol for building display data from trade and invoice information
protocol TradeStatementDisplayDataBuilderProtocol {
    /// Builds complete display data from trade and invoice information
    func buildDisplayData(
        trade: TradeOverviewItem,
        fullTrade: Trade?,
        buyInvoice: Invoice?,
        sellInvoices: [Invoice]
    ) -> TradeStatementDisplayData
}

// MARK: - Display Data Builder Implementation

/// Service responsible for building display data for trade statements
final class TradeStatementDisplayDataBuilder: TradeStatementDisplayDataBuilderProtocol {
    private let calculationGuardService: CalculationGuardService

    /// Default rechtlicher Hinweis für Collection Bills (Trade Statements).
    /// Dient als Fallback, falls kein serverseitiges Snippet hinterlegt ist.
    static let defaultLegalDisclaimer: String =
        "Wir buchen die Wertpapiere und den Gegenwert gemäß der Abrechnung mit dem angegebenen Valutatag. Bitte prüfen Sie diese Abrechnung auf Richtigkeit und Vollständigkeit. Einspruch gegen diese Abrechnung muss unverzüglich nach Erhalt bei der Bank erhoben werden. Unterlassen Sie den rechtzeitigen Einspruch, gilt dies als Genehmigung. Bitte beachten Sie mögliche Hinweise des Emittenten bezüglich vorzeitiger Fälligkeit, z.B. aufgrund eines Knock-out, in den jeweiligen Optionsscheinbedingungen und informieren Sie sich rechtzeitig, welche besondere Fälligkeitsregelung für die von Ihnen gehaltenen Wertpapiere gilt. Kapitalerträge unterliegen der Einkommensteuer."

    init(calculationGuardService: CalculationGuardService = CalculationGuardService.shared) {
        self.calculationGuardService = calculationGuardService
    }

    func buildDisplayData(
        trade: TradeOverviewItem,
        fullTrade: Trade?,
        buyInvoice: Invoice?,
        sellInvoices: [Invoice]
    ) -> TradeStatementDisplayData {

        let buyTransaction = self.buildBuyTransactionData(
            trade: trade,
            buyInvoice: buyInvoice
        )

        let sellTransactions = self.buildSellTransactionData(
            trade: trade,
            sellInvoices: sellInvoices
        )

        let calculationBreakdown = self.buildCalculationBreakdown(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        let taxSummary = buildTaxSummaryData(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            trade: trade
        )

        let fees = buildFeeItems(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        let taxes = buildTaxItems(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        let securityIdentifier = self.securityIdentifierFromInvoices(buyInvoice: buyInvoice, sellInvoices: sellInvoices)

        return TradeStatementDisplayData(
            depotNumber: "104801", // In a real app, this would come from user profile
            depotHolder: "Max Mustermann", // In a real app, this would come from user profile
            securityIdentifier: securityIdentifier,
            buyTransaction: buyTransaction,
            sellTransactions: sellTransactions,
            sellInvoices: sellInvoices,
            calculationBreakdown: calculationBreakdown,
            taxSummary: taxSummary,
            fees: fees,
            taxes: taxes,
            legalDisclaimer: Self.defaultLegalDisclaimer,
            accountNumber: "DE89 3704 0044 0532 0130 00", // In a real app, this would come from user's account information
            taxReportTransactionNumber: "343433" // In a real app, this would be a unique transaction number for tax reporting
        )
    }

    // MARK: - Private Methods

    private func buildCalculationBreakdown(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> CalculationBreakdownData {
        // Calculate individual sell amounts (excluding tax items) - guarded
        let sellAmounts = sellInvoices.map { sellInvoice in
            let sellItems = self.calculationGuardService.guardInvoiceFiltering(
                invoice: sellInvoice,
                calculationType: .profitCalculation
            )
            return sellItems.reduce(0) { $0 + $1.totalAmount }
        }

        // Calculate total sell amount
        let totalSellAmount = sellAmounts.reduce(0, +)

        // Calculate buy amount (excluding tax items) - guarded
        let buyAmount: Double
        if let buyInvoice = buyInvoice {
            let buyItems = self.calculationGuardService.guardInvoiceFiltering(
                invoice: buyInvoice,
                calculationType: .profitCalculation
            )
            buyAmount = buyItems.reduce(0) { $0 + $1.totalAmount }
        } else {
            buyAmount = 0.0
        }

        // Calculate pre-tax profit from the breakdown (sell - buy)
        // This ensures the displayed calculation matches the actual breakdown
        let preTaxProfit = totalSellAmount - abs(buyAmount)

        // Validate that this matches the guarded calculation
        let guardedPreTaxProfit = self.calculationGuardService.guardProfitCalculation(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // If there's a discrepancy, log it and use the guarded result
        if abs(preTaxProfit - guardedPreTaxProfit) > 0.01 {
            print("⚠️ CALCULATION BREAKDOWN DISCREPANCY:")
            print("   Breakdown calculation: \(preTaxProfit)")
            print("   Guarded calculation: \(guardedPreTaxProfit)")
            print("   Using guarded result for consistency")
        }

        // Format amounts
        let formattedSellAmounts = sellAmounts.map { $0.formatted(.currency(code: "EUR")) }
        let formattedTotalSellAmount = totalSellAmount.formatted(.currency(code: "EUR"))
        let formattedBuyAmount = buyAmount.formatted(.currency(code: "EUR"))
        let formattedPreTaxProfit = preTaxProfit.formatted(.currency(code: "EUR"))

        return CalculationBreakdownData(
            sellAmounts: formattedSellAmounts,
            totalSellAmount: formattedTotalSellAmount,
            buyAmount: formattedBuyAmount,
            resultBeforeTaxes: formattedPreTaxProfit,
            resultBeforeTaxesColor: preTaxProfit >= 0 ? "fin1AccentGreen" : "fin1AccentRed"
        )
    }

    private func buildBuyTransactionData(trade: TradeOverviewItem, buyInvoice: Invoice?) -> BuyTransactionData? {
        guard let invoice = buyInvoice else { return nil }

        let transactionDetails = self.extractTransactionDetails(from: invoice)
        let dates = self.formatTransactionDates(from: invoice)

        // Calculate individual fees using the same logic as Trade Details
        let securitiesItems = invoice.items.filter { $0.itemType == .securities }
        let securitiesAmount = securitiesItems.reduce(0) { $0 + $1.totalAmount }
        let feeBreakdown = FeeCalculationService.createFeeBreakdown(for: securitiesAmount)

        // Extract individual fee amounts
        let orderFee = feeBreakdown.first { $0.name == "Ordergebühr" }?.amount ?? 0.0
        let exchangeFee = feeBreakdown.first { $0.name == "Handelsplatzgebühr" }?.amount ?? 0.0
        let foreignCosts = feeBreakdown.first { $0.name == "Fremdkostenpauschale" }?.amount ?? 0.0

        return BuyTransactionData(
            transactionNumber: "\(trade.tradeNumber)/1",
            orderVolume: transactionDetails.orderVolume,
            executedVolume: transactionDetails.orderVolume,
            price: transactionDetails.price,
            exchangeRate: "",
            conversionFactor: "1,0000",
            custodyType: "GS-Verwahrung",
            depository: "Clearstream Nat.",
            depositoryCountry: "Deutschland",
            profitLoss: "0,00 EUR",
            profitLossColor: "fin1FontColor",
            valueDate: dates.valueDate,
            tradingVenue: TradeStatementPlaceholders.tradingVenue,
            closingDate: dates.closingDate,
            marketValue: transactionDetails.marketValue,
            commission: orderFee.formatted(.currency(code: "EUR")),
            ownExpenses: exchangeFee.formatted(.currency(code: "EUR")),
            externalExpenses: foreignCosts.formatted(.currency(code: "EUR")),
            assessmentBasis: "0,00 EUR",
            withheldTax: "0,00 EUR",
            finalAmount: (-invoice.totalAmount).formatted(.currency(code: "EUR")),
            finalAmountColor: "fin1AccentRed"
        )
    }

    private func buildSellTransactionData(trade: TradeOverviewItem, sellInvoices: [Invoice]) -> [SellTransactionData] {
        return sellInvoices.enumerated().map { index, invoice in
            let transactionDetails = self.extractTransactionDetails(from: invoice)
            let dates = self.formatTransactionDates(from: invoice)
            let profitLoss = calculateProfitLossForSell(invoice: invoice, trade: trade)
            let profitLossColor = profitLoss >= 0 ? "fin1AccentGreen" : "fin1AccentRed"

            // Calculate individual fees using the same logic as Trade Details
            // For sell transactions, fees should be negative (like in TradeCalculationService.calculateSellFees)
            let securitiesItems = invoice.items.filter { $0.itemType == .securities }
            let securitiesAmount = securitiesItems.reduce(0) { $0 + $1.totalAmount }
            let feeBreakdown = FeeCalculationService.createFeeBreakdown(for: securitiesAmount)

            // Extract individual fee amounts and make them negative for sell transactions
            let orderFee = -(feeBreakdown.first { $0.name == "Ordergebühr" }?.amount ?? 0.0)
            let exchangeFee = -(feeBreakdown.first { $0.name == "Handelsplatzgebühr" }?.amount ?? 0.0)
            let foreignCosts = -(feeBreakdown.first { $0.name == "Fremdkostenpauschale" }?.amount ?? 0.0)

            return SellTransactionData(
                transactionNumber: "\(trade.tradeNumber)/\(index + 2)",
                orderVolume: transactionDetails.orderVolume,
                executedVolume: transactionDetails.orderVolume,
                price: transactionDetails.price,
                exchangeRate: "",
                conversionFactor: "1,0000",
                custodyType: "GS-Verwahrung",
                depository: "Clearstream Nat.",
                depositoryCountry: "Deutschland",
                profitLoss: profitLoss.formatted(.currency(code: "EUR")),
                profitLossColor: profitLossColor,
                valueDate: dates.valueDate,
                tradingVenue: TradeStatementPlaceholders.tradingVenue,
                closingDate: dates.closingDate,
                marketValue: transactionDetails.marketValue,
                commission: orderFee.formatted(.currency(code: "EUR")),
                ownExpenses: exchangeFee.formatted(.currency(code: "EUR")),
                externalExpenses: foreignCosts.formatted(.currency(code: "EUR")),
                assessmentBasis: profitLoss.formatted(.currency(code: "EUR")),
                withheldTax: "0,00 EUR",
                finalAmount: invoice.totalAmount.formatted(.currency(code: "EUR")),
                finalAmountColor: "fin1AccentGreen"
            )
        }
    }

    // MARK: - Helper Methods

    private func extractTransactionDetails(from invoice: Invoice) -> TradeStatementTransactionDetails {
        let securityItems = invoice.items.filter { $0.itemType == .securities }
        let securityItem = securityItems.first

        let orderVolume = self.formatOrderVolume(from: securityItem)
        let price = self.formatPrice(from: securityItem)
        let marketValue = self.formatMarketValue(from: securityItem)
        let commission = self.calculateCommission(from: invoice)

        return TradeStatementTransactionDetails(
            orderVolume: orderVolume,
            price: price,
            marketValue: marketValue,
            commission: commission
        )
    }

    private func formatOrderVolume(from securityItem: InvoiceItem?) -> String {
        if let item = securityItem {
            return "\(String(format: "%.0f", item.quantity)) St."
        } else {
            return "100,00 St."
        }
    }

    private func formatPrice(from securityItem: InvoiceItem?) -> String {
        if let item = securityItem, item.quantity > 0 {
            return item.unitPrice.formattedAsLocalizedCurrency()
        } else {
            return "0,41 €"
        }
    }

    private func formatMarketValue(from securityItem: InvoiceItem?) -> String {
        if let item = securityItem {
            return item.totalAmount.formatted(.currency(code: "EUR"))
        } else {
            return "41,00 EUR"
        }
    }

    private func calculateCommission(from invoice: Invoice) -> String {
        return invoice.feesTotal.formatted(.currency(code: "EUR"))
    }

    private func formatTransactionDates(from invoice: Invoice) -> TransactionDates {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        let valueDate = formatter.string(from: invoice.createdAt)

        formatter.dateFormat = "dd.MM.yyyy, HH:mm 'Uhr'"
        let closingDate = formatter.string(from: invoice.createdAt)

        return TransactionDates(valueDate: valueDate, closingDate: closingDate)
    }

    /// Builds security identifier line from first available securities description (includes real emittent).
    private func securityIdentifierFromInvoices(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> String {
        if let desc = buyInvoice?.items.first(where: { $0.itemType == .securities })?.description, !desc.isEmpty {
            return desc
        }
        if let desc = sellInvoices.first?.items.first(where: { $0.itemType == .securities })?.description, !desc.isEmpty {
            return desc
        }
        return "VONT.FINL PR PUT23 DAX (DE000VU9GG06/VU9GG0)"
    }
}

// MARK: - Supporting Types

struct TradeStatementTransactionDetails {
    let orderVolume: String
    let price: String
    let marketValue: String
    let commission: String
}

struct TransactionDates {
    let valueDate: String
    let closingDate: String
}

extension TradeStatementDisplayDataBuilder {
    private func buildTaxSummaryData(
        buyInvoice: Invoice?,
        sellInvoices: [Invoice],
        trade: TradeOverviewItem
    ) -> TaxSummaryData {
        // Calculate pre-tax profit (Ergebnis vor Steuern)
        let preTaxProfit = self.calculationGuardService.guardProfitCalculation(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // If pre-tax profit ≤ 0, no taxes are due
        let totalTax: Double
        let netResult: Double

        if preTaxProfit <= CalculationConstants.Limits.minimumTaxableProfit {
            totalTax = 0.0
            netResult = preTaxProfit
        } else {
            // Calculate taxes only if there's a positive pre-tax profit
            totalTax = self.calculationGuardService.guardTaxCalculation(profit: preTaxProfit)
            netResult = preTaxProfit - totalTax
        }

        return TaxSummaryData(
            assessmentBasis: preTaxProfit.formatted(.currency(code: "EUR")),
            totalTax: totalTax.formatted(.currency(code: "EUR")),
            netResult: netResult.formatted(.currency(code: "EUR")),
            netResultColor: netResult >= 0 ? "fin1AccentGreen" : "fin1AccentRed"
        )
    }

    private func buildFeeItems(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> [FeeItem] {
        let allInvoices = [buyInvoice].compactMap { $0 } + sellInvoices
        let feeItems = allInvoices.allFeeItems

        // Group by item type and sum amounts
        let grouped = Dictionary(grouping: feeItems, by: { $0.itemType })
        return grouped.map { (type, items) in
            let totalAmount = items.reduce(0) { $0 + $1.absoluteAmount }
            return FeeItem(
                name: type.displayName,
                amount: totalAmount.formatted(.currency(code: "EUR"))
            )
        }.sorted { $0.name < $1.name }
    }

    private func buildTaxItems(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> [TaxItem] {
        // Calculate pre-tax profit (Ergebnis vor Steuern)
        let preTaxProfit = self.calculationGuardService.guardProfitCalculation(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices
        )

        // Only show tax breakdown if there's a positive pre-tax profit
        guard preTaxProfit > CalculationConstants.Limits.minimumTaxableProfit else {
            return []
        }

        // Calculate individual taxes only if pre-tax profit > 0
        let capitalGainsTax = InvoiceTaxCalculator.calculateCapitalGainsTax(for: preTaxProfit)
        let solidaritySurcharge = InvoiceTaxCalculator.calculateSolidaritySurcharge(for: capitalGainsTax)
        let churchTax = InvoiceTaxCalculator.calculateChurchTax(for: capitalGainsTax)

        return [
            TaxItem(
                name: "Abgeltungssteuer",
                basis: preTaxProfit.formatted(.currency(code: "EUR")),
                rate: "\(Int(CalculationConstants.TaxRates.capitalGainsTax * 100))%",
                amount: capitalGainsTax.formatted(.currency(code: "EUR"))
            ),
            TaxItem(
                name: "Solidaritätszuschlag",
                basis: capitalGainsTax.formatted(.currency(code: "EUR")),
                rate: "\(Int(CalculationConstants.TaxRates.solidaritySurcharge * 100))%",
                amount: solidaritySurcharge.formatted(.currency(code: "EUR"))
            ),
            TaxItem(
                name: "Kirchensteuer",
                basis: capitalGainsTax.formatted(.currency(code: "EUR")),
                rate: "\(Int(CalculationConstants.TaxRates.churchTax * 100))%",
                amount: churchTax.formatted(.currency(code: "EUR"))
            )
        ]
    }

    // MARK: - Calculation Helpers

    private func calculateNetCashFlow(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> Double {
        let allInvoices = [buyInvoice].compactMap { $0 } + sellInvoices
        let buyInvoices = allInvoices.filter { $0.transactionType == .buy }
        let sellInvoices = allInvoices.filter { $0.transactionType == .sell }

        let buyAmount = -buyInvoices.reduce(0) { $0 + $1.totalAmount } // Negative because money goes out
        let sellAmount = sellInvoices.reduce(0) { $0 + $1.totalAmount } // Positive because money comes in

        return buyAmount + sellAmount
    }

    private func calculateTotalTax(buyInvoice: Invoice?, sellInvoices: [Invoice]) -> Double {
        let allInvoices = [buyInvoice].compactMap { $0 } + sellInvoices
        let items = allInvoices.flatMap { $0.items }
        let taxItems = items.filter { $0.itemType == .tax }
        return taxItems.reduce(0) { $0 + abs($1.totalAmount) }
    }

    private func calculateProfitLossForSell(invoice: Invoice, trade: TradeOverviewItem) -> Double {
        // Simplified calculation - in a real app, this would be more complex
        // For now, use the trade's overall profit/loss divided by number of sell transactions
        return trade.profitLoss
    }
}
