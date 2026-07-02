import Foundation
import SwiftUI

// MARK: - Completed Investment Detail ViewModel
@MainActor
final class CompletedInvestmentDetailViewModel: ObservableObject {
    let investment: Investment
    var poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    var tradeLifecycleService: (any TradeLifecycleServiceProtocol)?
    var invoiceService: (any InvoiceServiceProtocol)?
    var calculationService: (any InvestorCollectionBillCalculationServiceProtocol)?
    var commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    var configurationService: (any ConfigurationServiceProtocol)?
    var settlementAPIService: (any SettlementAPIServiceProtocol)?
    var tradeAPIService: (any TradeAPIServiceProtocol)?

    @Published var tradeLineItems: [TradeLineItem] = []
    @Published var statementSummary: InvestorInvestmentStatementSummary?
    @Published var canonicalSummary: ServerInvestmentCanonicalSummary?
    @Published var tradeLedReturnPercentageValue: Double?

    var monetaryServerOnly: Bool {
        self.configurationService?.investorMonetaryServerOnly ?? true
    }

    init(investment: Investment) {
        self.investment = investment
    }
}
