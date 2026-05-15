import Foundation

// MARK: - Investment Completion Service Implementation
/// Handles investment completion checking, profit calculation, and cash distribution
/// Delegates to focused helper services for specific functionality
@MainActor
final class InvestmentCompletionService: InvestmentCompletionServiceProtocol {

    // MARK: - Dependencies
    // internal: InvestmentCompletionService+Helpers accesses these from a separate file

    let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    let telemetryService: (any TelemetryServiceProtocol)?
    let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    let tradeLifecycleService: (any TradeLifecycleServiceProtocol)?
    let invoiceService: (any InvoiceServiceProtocol)?
    let transactionIdService: (any TransactionIdServiceProtocol)?
    let userService: (any UserServiceProtocol)?
    let documentService: (any DocumentServiceProtocol)?
    let configurationService: any ConfigurationServiceProtocol
    let settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Initialization
    init(
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        telemetryService: (any TelemetryServiceProtocol)? = nil,
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        tradeLifecycleService: (any TradeLifecycleServiceProtocol)? = nil,
        invoiceService: (any InvoiceServiceProtocol)? = nil,
        transactionIdService: (any TransactionIdServiceProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.poolTradeParticipationService = poolTradeParticipationService
        self.telemetryService = telemetryService
        self.investorCashBalanceService = investorCashBalanceService
        self.tradeLifecycleService = tradeLifecycleService
        self.invoiceService = invoiceService
        self.transactionIdService = transactionIdService
        self.userService = userService
        self.documentService = documentService
        self.configurationService = configurationService
        self.settlementAPIService = settlementAPIService
    }

    // MARK: - Investment Completion Checking

    func checkAndUpdateInvestmentCompletion(
        in investments: [Investment],
        specificInvestmentIds: [String]? = nil
    ) -> [Investment] {
        let investmentsToCheck = self.filterInvestmentsToCheck(investments, specificInvestmentIds: specificInvestmentIds)
        var updatedInvestments: [Investment] = []

        for investment in investmentsToCheck {
            guard investment.status == .active else {
                print("   ⏭️ Investment \(investment.id): status=\(investment.status.rawValue), skipping")
                continue
            }

            if let updatedInvestment = checkAndMarkCompletion(for: investment) {
                updatedInvestments.append(updatedInvestment)
            }
        }

        self.logCompletionResults(updatedInvestments: updatedInvestments)
        return updatedInvestments
    }

    // MARK: - Profit Updates

    func updateInvestmentProfitsFromTrades(in investments: [Investment]) -> [Investment] {
        guard let poolTradeParticipationService = poolTradeParticipationService else {
            print("⚠️ InvestmentCompletionService.updateInvestmentProfitsFromTrades: poolTradeParticipationService is nil")
            return []
        }

        var updatedInvestments: [Investment] = []

        for investment in investments {
            if let updatedInvestment = updateProfitForInvestment(
                investment,
                poolTradeParticipationService: poolTradeParticipationService
            ) {
                updatedInvestments.append(updatedInvestment)
            }
        }

        if !updatedInvestments.isEmpty {
            print("✅ InvestmentCompletionService: Updated \(updatedInvestments.count) investment profits from trades")
        }

        return updatedInvestments
    }

    // MARK: - Cash Distribution

    func distributeInvestmentCompletionCash(
        investment: Investment,
        investmentReservation: InvestmentReservation
    ) async {
        guard let investorCashBalanceService = investorCashBalanceService else {
            print("⚠️ InvestmentCompletionService.distributeInvestmentCompletionCash: investorCashBalanceService is nil")
            return
        }

        await InvestmentCashDistributor.distributeCash(
            investment: investment,
            investmentReservation: investmentReservation,
            investorCashBalanceService: investorCashBalanceService,
            poolTradeParticipationService: self.poolTradeParticipationService,
            tradeLifecycleService: self.tradeLifecycleService,
            invoiceService: self.invoiceService,
            configurationService: self.configurationService,
            settlementAPIService: self.settlementAPIService
        )
    }
}
