import SwiftUI
import Foundation

// MARK: - Display Service Protocol

/// Protocol for providing computed display properties for trade statements
protocol TradeStatementDisplayServiceProtocol {
    /// Gets all computed display properties for the trade statement
    func getDisplayProperties(from displayData: TradeStatementDisplayData, trade: TradeOverviewItem) -> TradeStatementDisplayProperties
}

// MARK: - Display Properties Model

/// All computed display properties for a trade statement
struct TradeStatementDisplayProperties {
    // Basic info
    let depotNumber: String
    let depotHolder: String
    let securityIdentifier: String
    let accountNumber: String
    let legalDisclaimer: String
    let taxReportTransactionNumber: String

    // Transaction flags
    let hasBuyTransaction: Bool
    let hasSellTransaction: Bool

    // Buy transaction properties
    let buyTransactionNumber: String
    let buyOrderVolume: String
    let buyExecutedVolume: String
    let buyPrice: String
    let buyExchangeRate: String
    let buyConversionFactor: String
    let buyCustodyType: String
    let buyDepository: String
    let buyDepositoryCountry: String
    let buyProfitLoss: String
    let buyProfitLossColor: Color
    let buyValueDate: String
    let buyTradingVenue: String
    let buyClosingDate: String
    let buyMarketValue: String
    let buyCommission: String
    let buyOwnExpenses: String
    let buyExternalExpenses: String
    let buyAssessmentBasis: String
    let buyWithheldTax: String
    let buyFinalAmount: String
    let buyFinalAmountColor: Color

    // Sell transaction properties (legacy - first sell order)
    let sellTransactionNumber: String
    let sellOrderVolume: String
    let sellExecutedVolume: String
    let sellPrice: String
    let sellExchangeRate: String
    let sellConversionFactor: String
    let sellCustodyType: String
    let sellDepository: String
    let sellDepositoryCountry: String
    let sellProfitLoss: String
    let sellProfitLossColor: Color
    let sellValueDate: String
    let sellTradingVenue: String
    let sellClosingDate: String
    let sellMarketValue: String
    let sellCommission: String
    let sellOwnExpenses: String
    let sellExternalExpenses: String
    let sellAssessmentBasis: String
    let sellWithheldTax: String
    let sellFinalAmount: String
    let sellFinalAmountColor: Color

    // Summary properties
    let totalAssessmentBasis: String
    let totalTaxAmount: String
    let netResult: String
    let netResultColor: Color

    // Items
    let calculationBreakdown: CalculationBreakdownData
    let feeItems: [FeeItem]
    let taxItems: [TaxItem]
    let sellOrderData: [SellOrderData]
}

// MARK: - Display Service Implementation

/// Service responsible for providing computed display properties for trade statements
final class TradeStatementDisplayService: TradeStatementDisplayServiceProtocol {

    func getDisplayProperties(from displayData: TradeStatementDisplayData, trade: TradeOverviewItem) -> TradeStatementDisplayProperties {
        let buyTransaction = displayData.buyTransaction
        let sellTransactions = displayData.sellTransactions
        let firstSellTransaction = sellTransactions.first

        return TradeStatementDisplayProperties(
            // Basic info
            depotNumber: displayData.depotNumber,
            depotHolder: displayData.depotHolder,
            securityIdentifier: displayData.securityIdentifier,
            accountNumber: displayData.accountNumber,
            legalDisclaimer: displayData.legalDisclaimer,
            taxReportTransactionNumber: displayData.taxReportTransactionNumber,

            // Transaction flags
            hasBuyTransaction: buyTransaction != nil,
            hasSellTransaction: !sellTransactions.isEmpty,

            // Buy transaction properties
            buyTransactionNumber: getBuyTransactionNumber(buyTransaction, trade: trade),
            buyOrderVolume: getBuyOrderVolume(buyTransaction),
            buyExecutedVolume: getBuyExecutedVolume(buyTransaction),
            buyPrice: getBuyPrice(buyTransaction),
            buyExchangeRate: getBuyExchangeRate(buyTransaction),
            buyConversionFactor: getBuyConversionFactor(buyTransaction),
            buyCustodyType: getBuyCustodyType(buyTransaction),
            buyDepository: getBuyDepository(buyTransaction),
            buyDepositoryCountry: getBuyDepositoryCountry(buyTransaction),
            buyProfitLoss: getBuyProfitLoss(buyTransaction),
            buyProfitLossColor: getBuyProfitLossColor(buyTransaction),
            buyValueDate: getBuyValueDate(buyTransaction),
            buyTradingVenue: getBuyTradingVenue(buyTransaction),
            buyClosingDate: getBuyClosingDate(buyTransaction),
            buyMarketValue: getBuyMarketValue(buyTransaction),
            buyCommission: getBuyCommission(buyTransaction),
            buyOwnExpenses: getBuyOwnExpenses(buyTransaction),
            buyExternalExpenses: getBuyExternalExpenses(buyTransaction),
            buyAssessmentBasis: getBuyAssessmentBasis(buyTransaction),
            buyWithheldTax: getBuyWithheldTax(buyTransaction),
            buyFinalAmount: getBuyFinalAmount(buyTransaction),
            buyFinalAmountColor: getBuyFinalAmountColor(buyTransaction),

            // Sell transaction properties (legacy - first sell order)
            sellTransactionNumber: firstSellTransaction?.transactionNumber ?? "\(trade.tradeNumber)/2",
            sellOrderVolume: firstSellTransaction?.orderVolume ?? "100,00 St.",
            sellExecutedVolume: firstSellTransaction?.executedVolume ?? "100,00 St.",
            sellPrice: firstSellTransaction?.price ?? "0,6200 EUR",
            sellExchangeRate: firstSellTransaction?.exchangeRate ?? "",
            sellConversionFactor: firstSellTransaction?.conversionFactor ?? "1,0000",
            sellCustodyType: firstSellTransaction?.custodyType ?? "GS-Verwahrung",
            sellDepository: firstSellTransaction?.depository ?? "Clearstream Nat.",
            sellDepositoryCountry: firstSellTransaction?.depositoryCountry ?? "Deutschland",
            sellProfitLoss: firstSellTransaction?.profitLoss ?? trade.profitLoss.formatted(.currency(code: "EUR")),
            sellProfitLossColor: colorFromString(firstSellTransaction?.profitLossColor ?? (trade.profitLoss >= 0 ? "fin1AccentGreen" : "fin1AccentRed")),
            sellValueDate: firstSellTransaction?.valueDate ?? "",
            sellTradingVenue: firstSellTransaction?.tradingVenue ?? "Vontobel",
            sellClosingDate: firstSellTransaction?.closingDate ?? "",
            sellMarketValue: firstSellTransaction?.marketValue ?? "62,00 EUR",
            sellCommission: firstSellTransaction?.commission ?? "5,90 EUR",
            sellOwnExpenses: firstSellTransaction?.ownExpenses ?? "",
            sellExternalExpenses: firstSellTransaction?.externalExpenses ?? "",
            sellAssessmentBasis: firstSellTransaction?.assessmentBasis ?? "0,00 EUR",
            sellWithheldTax: firstSellTransaction?.withheldTax ?? "0,00 EUR",
            sellFinalAmount: firstSellTransaction?.finalAmount ?? "53,53 EUR",
            sellFinalAmountColor: colorFromString(firstSellTransaction?.finalAmountColor ?? "fin1AccentGreen"),

            // Summary properties
            totalAssessmentBasis: displayData.taxSummary.assessmentBasis,
            totalTaxAmount: displayData.taxSummary.totalTax,
            netResult: displayData.taxSummary.netResult,
            netResultColor: colorFromString(displayData.taxSummary.netResultColor),

            // Items
            calculationBreakdown: displayData.calculationBreakdown,
            feeItems: displayData.fees,
            taxItems: displayData.taxes,
            sellOrderData: buildSellOrderData(from: displayData.sellInvoices, trade: trade)
        )
    }

    // MARK: - Private Methods

    private func colorFromString(_ colorString: String) -> Color {
        switch colorString {
        case "fin1AccentGreen":
            return AppTheme.accentGreen
        case "fin1AccentRed":
            return AppTheme.accentRed
        case "fin1AccentLightBlue":
            return AppTheme.accentLightBlue
        case "fin1FontColor":
            return AppTheme.fontColor
        default:
            return AppTheme.fontColor
        }
    }

    // MARK: - Buy Transaction Property Helpers

    private func getBuyTransactionNumber(_ buyTransaction: BuyTransactionData?, trade: TradeOverviewItem) -> String {
        return buyTransaction?.transactionNumber ?? "\(trade.tradeNumber)/1"
    }

    private func getBuyOrderVolume(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.orderVolume ?? "100,00 St."
    }

    private func getBuyExecutedVolume(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.executedVolume ?? "100,00 St."
    }

    private func getBuyPrice(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.price ?? "0,4100 EUR"
    }

    private func getBuyExchangeRate(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.exchangeRate ?? ""
    }

    private func getBuyConversionFactor(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.conversionFactor ?? "1,0000"
    }

    private func getBuyCustodyType(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.custodyType ?? "GS-Verwahrung"
    }

    private func getBuyDepository(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.depository ?? "Clearstream Nat."
    }

    private func getBuyDepositoryCountry(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.depositoryCountry ?? "Deutschland"
    }

    private func getBuyProfitLoss(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.profitLoss ?? "0,00 EUR"
    }

    private func getBuyProfitLossColor(_ buyTransaction: BuyTransactionData?) -> Color {
        return colorFromString(buyTransaction?.profitLossColor ?? "fin1FontColor")
    }

    private func getBuyValueDate(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.valueDate ?? ""
    }

    private func getBuyTradingVenue(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.tradingVenue ?? "Vontobel"
    }

    private func getBuyClosingDate(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.closingDate ?? ""
    }

    private func getBuyMarketValue(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.marketValue ?? "41,00 EUR"
    }

    private func getBuyCommission(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.commission ?? "5,90 EUR"
    }

    private func getBuyOwnExpenses(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.ownExpenses ?? ""
    }

    private func getBuyExternalExpenses(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.externalExpenses ?? ""
    }

    private func getBuyAssessmentBasis(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.assessmentBasis ?? "0,00 EUR"
    }

    private func getBuyWithheldTax(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.withheldTax ?? "0,00 EUR"
    }

    private func getBuyFinalAmount(_ buyTransaction: BuyTransactionData?) -> String {
        return buyTransaction?.finalAmount ?? "41,00 EUR"
    }

    private func getBuyFinalAmountColor(_ buyTransaction: BuyTransactionData?) -> Color {
        return colorFromString(buyTransaction?.finalAmountColor ?? "fin1AccentRed")
    }

    // MARK: - Sell Order Data Builder

    private func buildSellOrderData(from sellInvoices: [Invoice], trade: TradeOverviewItem) -> [SellOrderData] {
        return sellInvoices.enumerated().map { index, invoice in
            SellOrderData(
                transactionNumber: "\(trade.tradeNumber)/\(index + 2)",
                invoice: invoice
            )
        }
    }
}
