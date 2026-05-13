import Foundation
import SwiftUI

// MARK: - Investor Investment Statement ViewModel
/// Builds an investor-focused statement view for a single investment,
/// using the investor's actual investment capital (source of truth) for calculations.
@MainActor
final class InvestorInvestmentStatementViewModel: ObservableObject {
    // MARK: - Dependencies
    let investment: Investment
    let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    let tradeService: any TradeLifecycleServiceProtocol
    let invoiceService: any InvoiceServiceProtocol
    let calculationService: any InvestorCollectionBillCalculationServiceProtocol
    let commissionCalculationService: any CommissionCalculationServiceProtocol
    let configurationService: any ConfigurationServiceProtocol
    let settlementAPIService: (any SettlementAPIServiceProtocol)?
    let statementDataProvider: (any InvestorInvestmentStatementDataProviderProtocol)?

    // MARK: - Published Data
    @Published var statementItems: [InvestorInvestmentStatementItem] = []
    /// True while fetching backend-authoritative collection bill data
    @Published var isRefreshingFromBackend = false
    /// When non-nil, backend fetch failed; user is seeing local/cached data
    @Published var backendRefreshMessage: String?

    // MARK: - Document Number
    /// Eindeutige Belegnummer für dieses Collection Bill Dokument (gemäß GoB)
    var documentNumber: String?

    /// Admin-configured commission rate (single source of truth via ConfigurationService)
    var effectiveCommissionRate: Double {
        self.configurationService.effectiveCommissionRate
    }

    // MARK: - Initialization
    init(
        investment: Investment,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        tradeService: any TradeLifecycleServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        calculationService: any InvestorCollectionBillCalculationServiceProtocol = InvestorCollectionBillCalculationService(),
        commissionCalculationService: any CommissionCalculationServiceProtocol = CommissionCalculationService(),
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil,
        statementDataProvider: (any InvestorInvestmentStatementDataProviderProtocol)? = nil
    ) {
        self.investment = investment
        self.poolTradeParticipationService = poolTradeParticipationService
        self.tradeService = tradeService
        self.invoiceService = invoiceService
        self.calculationService = calculationService
        self.commissionCalculationService = commissionCalculationService
        self.configurationService = configurationService
        self.settlementAPIService = settlementAPIService
        self.statementDataProvider = statementDataProvider

        rebuildStatement()
    }
}
