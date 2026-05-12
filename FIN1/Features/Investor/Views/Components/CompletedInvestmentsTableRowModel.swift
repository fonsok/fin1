import Foundation

struct CompletedInvestmentsTableRowModel {
    let id: String
    let investmentNumber: String
    let amount: Double
    let grossProfit: Double?
    let returnPercentage: Double?
    let isCancelled: Bool
    let traderUsername: String
    let tradeNumberText: String
    let docNumber: String?
    let invoiceNumber: String?

    init(
        investment: Investment,
        summary: InvestorInvestmentStatementSummary?,
        returnPercentage: Double?,
        traderUsername: String,
        tradeNumberText: String,
        docNumber: String?,
        invoiceNumber: String?
    ) {
        self.id = investment.id
        self.investmentNumber = investment.canonicalDisplayReference
        self.amount = investment.amount
        self.grossProfit = summary?.statementGrossProfit
        self.returnPercentage = returnPercentage
        self.isCancelled = investment.status == .cancelled
        self.traderUsername = traderUsername
        self.tradeNumberText = tradeNumberText
        self.docNumber = docNumber
        self.invoiceNumber = invoiceNumber
    }
}
