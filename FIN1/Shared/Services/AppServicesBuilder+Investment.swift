import Foundation

extension AppServicesBuilder {

    enum Investment {
        static func build(_ ctx: inout AppServicesBuildContext) {
            guard let serviceFactory = ctx.serviceFactory,
                  let parseAPIClient = ctx.parseAPIClient,
                  let documentService = ctx.documentService,
                  let configurationService = ctx.configurationService,
                  let userService = ctx.userService,
                  let investorCashBalanceService = ctx.investorCashBalanceService,
                  let tradeLifecycleService = ctx.tradeLifecycleService,
                  let orderManagementService = ctx.orderManagementService,
                  let orderStatusSimulationService = ctx.orderStatusSimulationService,
                  let tradingNotificationService = ctx.tradingNotificationService,
                  let tradeMatchingService = ctx.tradeMatchingService,
                  let securitiesWatchlistService = ctx.securitiesWatchlistService,
                  let tradingStatisticsService = ctx.tradingStatisticsService,
                  let auditLoggingService = ctx.auditLoggingService else { return }

            let investmentAPIService = InvestmentAPIService(apiClient: parseAPIClient)
            ctx.investmentAPIService = investmentAPIService

            let poolTradeParticipationService = PoolTradeParticipationService(investmentAPIService: investmentAPIService)
            ctx.poolTradeParticipationService = poolTradeParticipationService

            ctx.telemetryService = TelemetryService()
            ctx.investmentManagementService = InvestmentManagementService()
            ctx.traderDataService = TraderDataService()
            ctx.commissionAccumulationService = CommissionAccumulationService()
            ctx.traderCashBalanceService = TraderCashBalanceService(
                configurationService: configurationService,
                parseLiveQueryClient: ctx.parseLiveQueryClient!,
                userService: userService
            )

            ctx.investmentDocumentService = InvestmentDocumentService(
                documentService: documentService,
                transactionIdService: serviceFactory.coreTransactionIdService
            )
            ctx.investmentCompletionService = InvestmentCompletionService(
                poolTradeParticipationService: poolTradeParticipationService,
                telemetryService: ctx.telemetryService!,
                investorCashBalanceService: investorCashBalanceService,
                tradeLifecycleService: tradeLifecycleService,
                invoiceService: serviceFactory.coreInvoiceService,
                transactionIdService: serviceFactory.coreTransactionIdService,
                userService: userService,
                documentService: documentService,
                configurationService: configurationService,
                settlementAPIService: ctx.settlementAPIService
            )
            ctx.investmentService = InvestmentService(
                investorCashBalanceService: investorCashBalanceService,
                poolTradeParticipationService: poolTradeParticipationService,
                telemetryService: ctx.telemetryService!,
                documentService: documentService,
                investmentManagementService: ctx.investmentManagementService!,
                investmentCompletionService: ctx.investmentCompletionService!,
                investmentDocumentService: ctx.investmentDocumentService!,
                invoiceService: serviceFactory.coreInvoiceService,
                transactionIdService: serviceFactory.coreTransactionIdService,
                configurationService: configurationService,
                investmentAPIService: investmentAPIService
            )

            ctx.investorGrossProfitService = serviceFactory.createInvestorGrossProfitService(
                poolTradeParticipationService: poolTradeParticipationService,
                tradeLifecycleService: tradeLifecycleService,
                investmentService: ctx.investmentService!
            )
            ctx.commissionCalculationService = serviceFactory.createCommissionCalculationService(
                investorGrossProfitService: ctx.investorGrossProfitService!
            )
            if let settlementAPI = ctx.settlementAPIService {
                ctx.commissionCalculationService!.configure(settlementAPIService: settlementAPI)
            }
            ctx.investmentService!.configureCalculationServices(
                investorGrossProfitService: ctx.investorGrossProfitService!,
                commissionCalculationService: ctx.commissionCalculationService!
            )

            ctx.commissionSettlementService = serviceFactory.createCommissionSettlementService(
                commissionAccumulationService: ctx.commissionAccumulationService!,
                traderCashBalanceService: ctx.traderCashBalanceService!,
                userService: userService
            )

            ctx.profitDistributionService = serviceFactory.createProfitDistributionService(
                commissionCalculationService: ctx.commissionCalculationService!,
                investorGrossProfitService: ctx.investorGrossProfitService!,
                commissionAccumulationService: ctx.commissionAccumulationService!,
                poolTradeParticipationService: poolTradeParticipationService,
                traderCashBalanceService: ctx.traderCashBalanceService!,
                investmentService: ctx.investmentService!,
                userService: userService,
                traderDataService: ctx.traderDataService!,
                settlementAPIService: ctx.settlementAPIService
            )

            ctx.investmentActivationService = serviceFactory.createInvestmentActivationService(
                investmentService: ctx.investmentService!,
                poolTradeParticipationService: poolTradeParticipationService,
                userService: userService,
                traderDataService: ctx.traderDataService!
            )

            ctx.orderLifecycleCoordinator = serviceFactory.createOrderLifecycleCoordinator(
                orderManagementService: orderManagementService,
                orderStatusSimulationService: orderStatusSimulationService,
                tradingNotificationService: tradingNotificationService,
                tradeLifecycleService: tradeLifecycleService,
                tradeMatchingService: tradeMatchingService,
                investmentActivationService: ctx.investmentActivationService!,
                profitDistributionService: ctx.profitDistributionService!,
                poolTradeParticipationService: poolTradeParticipationService,
                userService: userService,
                investmentService: ctx.investmentService!,
                documentService: documentService,
                investorGrossProfitService: ctx.investorGrossProfitService!,
                commissionCalculationService: ctx.commissionCalculationService!,
                auditLoggingService: auditLoggingService,
                settlementAPIService: ctx.settlementAPIService
            )

            ctx.tradingStateStore = serviceFactory.createTradingStateStore(
                orderManagementService: orderManagementService,
                tradeLifecycleService: tradeLifecycleService,
                securitiesWatchlistService: securitiesWatchlistService,
                orderStatusSimulationService: orderStatusSimulationService
            )

            ctx.tradeLifecycleCoordinator = serviceFactory.createTradeLifecycleCoordinator(
                tradeLifecycleService: tradeLifecycleService
            )

            ctx.tradingCoordinator = serviceFactory.createTradingCoordinator(
                tradingStateStore: ctx.tradingStateStore!,
                orderLifecycleCoordinator: ctx.orderLifecycleCoordinator!,
                tradeLifecycleCoordinator: ctx.tradeLifecycleCoordinator!,
                securitiesWatchlistService: securitiesWatchlistService,
                tradingStatisticsService: tradingStatisticsService
            )
        }
    }
}
