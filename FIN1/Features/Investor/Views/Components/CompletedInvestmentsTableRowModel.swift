import Foundation

struct CompletedInvestmentsTableRowModel {
    let id: String
    let investmentNumber: String
    let amount: Double
    let grossProfit: Double?
    let returnPercentage: Double?
    let isCancelled: Bool
    let traderUsername: String
    let docNumber: String?
    let invoiceNumber: String?

    init(
        investment: Investment,
        summary: InvestorInvestmentStatementSummary?,
        canonical: ServerInvestmentCanonicalSummary? = nil,
        returnPercentage: Double?,
        traderDataService: (any TraderDataServiceProtocol)? = nil,
        docNumber: String?,
        invoiceNumber: String?
    ) {
        self.id = investment.id
        self.investmentNumber = investment.canonicalDisplayReference
        self.amount = investment.displayEffectiveInvestmentAmount(summary: summary, canonical: canonical)
        self.grossProfit = canonical.map(\.grossProfit) ?? summary?.statementGrossProfit
        self.returnPercentage = returnPercentage
        self.isCancelled = investment.status == .cancelled
        self.traderUsername = investment.displayTraderUsername(using: traderDataService)
        self.docNumber = docNumber
        self.invoiceNumber = invoiceNumber
    }
}
