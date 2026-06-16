import Foundation

// MARK: - Beleg metadata → TradeStatementDisplayData (GoB SSOT, no invoice synthesis)

enum TraderCollectionBillLegDisplayDataBuilder {

    static func build(
        trade: TradeOverviewItem,
        metadata: TraderCollectionBillBelegMetadata,
        belegNumber: String?
    ) -> TradeStatementDisplayData {
        let qty = metadata.quantity ?? 0
        let gross = metadata.amount?.doubleValue ?? 0
        let fees = metadata.fees ?? TraderCollectionBillBelegMetadata.Fees(
            orderFee: nil,
            exchangeFee: nil,
            foreignCosts: nil,
            totalFees: nil
        )
        let orderFee = fees.orderFee?.doubleValue ?? 0
        let exchangeFee = fees.exchangeFee?.doubleValue ?? 0
        let foreignCosts = fees.foreignCosts?.doubleValue ?? 0
        let totalWithFees = metadata.totalWithFees?.doubleValue ?? gross

        let orderVolume = self.formatQuantity(qty)
        let price = self.formatPrice(metadata.price ?? (qty > 0 ? gross / qty : 0))
        let marketValue = gross.formatted(.currency(code: "EUR"))
        let valueDate = metadata.valueDate ?? ""
        let closingDate = metadata.closingDate ?? ""
        let tradingVenue = metadata.tradingVenue?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (metadata.tradingVenue ?? TradeStatementPlaceholders.tradingVenue)
            : TradeStatementPlaceholders.tradingVenue

        let depotHolder = metadata.traderDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (metadata.traderDisplayName ?? "Max Mustermann")
            : "Max Mustermann"

        let emptyBreakdown = CalculationBreakdownData(
            sellAmounts: [],
            totalSellAmount: "0,00 EUR",
            buyAmount: "0,00 EUR",
            resultBeforeTaxes: "0,00 EUR",
            resultBeforeTaxesColor: "fin1FontColor"
        )
        let emptyTax = TaxSummaryData(
            assessmentBasis: "0,00 EUR",
            totalTax: "0,00 EUR",
            netResult: "0,00 EUR",
            netResultColor: "fin1FontColor"
        )

        let partialSellDisplay = TraderCollectionBillPartialSellDisplayBuilder.build(from: metadata.partialSell)

        if metadata.isSell {
            let sellTx = SellTransactionData(
                transactionNumber: belegNumber ?? "\(trade.tradeNumber)/2",
                orderVolume: orderVolume,
                executedVolume: orderVolume,
                price: price,
                exchangeRate: "",
                conversionFactor: "1,0000",
                custodyType: "GS-Verwahrung",
                depository: "Clearstream Nat.",
                depositoryCountry: "Deutschland",
                profitLoss: "0,00 EUR",
                profitLossColor: "fin1FontColor",
                valueDate: valueDate,
                tradingVenue: tradingVenue,
                closingDate: closingDate,
                marketValue: marketValue,
                commission: (-orderFee).formatted(.currency(code: "EUR")),
                ownExpenses: (-exchangeFee).formatted(.currency(code: "EUR")),
                externalExpenses: (-foreignCosts).formatted(.currency(code: "EUR")),
                assessmentBasis: "0,00 EUR",
                withheldTax: "0,00 EUR",
                finalAmount: totalWithFees.formatted(.currency(code: "EUR")),
                finalAmountColor: "fin1AccentGreen"
            )
            return TradeStatementDisplayData(
                depotNumber: "104801",
                depotHolder: depotHolder,
                securityIdentifier: metadata.securityIdentifier,
                buyTransaction: nil,
                sellTransactions: [sellTx],
                sellInvoices: [],
                calculationBreakdown: CalculationBreakdownData(
                    sellAmounts: [marketValue],
                    totalSellAmount: marketValue,
                    buyAmount: "0,00 EUR",
                    resultBeforeTaxes: marketValue,
                    resultBeforeTaxesColor: "fin1AccentGreen"
                ),
                taxSummary: emptyTax,
                fees: [],
                taxes: [],
                legalDisclaimer: TradeStatementDisplayDataBuilder.defaultLegalDisclaimer,
                accountNumber: "DE89 3704 0044 0532 0130 00",
                taxReportTransactionNumber: "343433",
                partialSellDisplay: partialSellDisplay
            )
        }

        let buyTx = BuyTransactionData(
            transactionNumber: belegNumber ?? "\(trade.tradeNumber)/1",
            orderVolume: orderVolume,
            executedVolume: orderVolume,
            price: price,
            exchangeRate: "",
            conversionFactor: "1,0000",
            custodyType: "GS-Verwahrung",
            depository: "Clearstream Nat.",
            depositoryCountry: "Deutschland",
            profitLoss: "0,00 EUR",
            profitLossColor: "fin1FontColor",
            valueDate: valueDate,
            tradingVenue: tradingVenue,
            closingDate: closingDate,
            marketValue: marketValue,
            commission: orderFee.formatted(.currency(code: "EUR")),
            ownExpenses: exchangeFee.formatted(.currency(code: "EUR")),
            externalExpenses: foreignCosts.formatted(.currency(code: "EUR")),
            assessmentBasis: "0,00 EUR",
            withheldTax: "0,00 EUR",
            finalAmount: (-totalWithFees).formatted(.currency(code: "EUR")),
            finalAmountColor: "fin1AccentRed"
        )
        return TradeStatementDisplayData(
            depotNumber: "104801",
            depotHolder: depotHolder,
            securityIdentifier: metadata.securityIdentifier,
            buyTransaction: buyTx,
            sellTransactions: [],
            sellInvoices: [],
            calculationBreakdown: CalculationBreakdownData(
                sellAmounts: [],
                totalSellAmount: "0,00 EUR",
                buyAmount: marketValue,
                resultBeforeTaxes: "0,00 EUR",
                resultBeforeTaxesColor: "fin1FontColor"
            ),
            taxSummary: emptyTax,
            fees: [],
            taxes: [],
            legalDisclaimer: TradeStatementDisplayDataBuilder.defaultLegalDisclaimer,
            accountNumber: "DE89 3704 0044 0532 0130 00",
            taxReportTransactionNumber: "343433",
            partialSellDisplay: partialSellDisplay
        )
    }

    private static func formatQuantity(_ qty: Double) -> String {
        "\(String(format: "%.0f", qty)) St."
    }

    private static func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "de_DE")
        formatter.decimalSeparator = ","
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 4
        return "\(formatter.string(from: NSNumber(value: value)) ?? "0,00") EUR"
    }
}
