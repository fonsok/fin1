import Foundation

// MARK: - Service Factory
/// Centralized service creation with proper dependency injection
/// Eliminates singleton dependencies and provides clean service instantiation
final class ServiceFactory {

    // MARK: - Core Services
    private let transactionIdService: TransactionIdService
    private let tradeNumberService: TradeNumberService
    private let cashBalanceService: CashBalanceService
    private let invoiceService: InvoiceService
    private let configurationService: any ConfigurationServiceProtocol
    private let userService: any UserServiceProtocol

    // MARK: - Initialization
    init(configurationService: any ConfigurationServiceProtocol, userService: any UserServiceProtocol) {
        // Create core services first (no dependencies)
        self.transactionIdService = TransactionIdService()
        self.tradeNumberService = TradeNumberService()
        // CashBalanceService will be initialized with Live Query support in AppServicesBuilder
        // For now, create without Live Query (will be updated in AppServicesBuilder)
        self.cashBalanceService = CashBalanceService(
            configurationService: configurationService,
            parseLiveQueryClient: nil,
            userService: nil
        )
        self.invoiceService = InvoiceService(transactionIdService: transactionIdService)
        self.configurationService = configurationService
        self.userService = userService
    }

    // MARK: - Service Creation Methods

    func createOrderManagementService() -> OrderManagementService {
        return OrderManagementService(transactionIdService: transactionIdService, userService: userService)
    }

    func createTradeLifecycleService(
        tradingNotificationService: any TradingNotificationServiceProtocol,
        tradeAPIService: (any TradeAPIServiceProtocol)? = nil
    ) -> TradeLifecycleService {
        let service = TradeLifecycleService()
        // Note: auditLoggingService will be added in AppServicesBuilder after it's created
        service.attach(
            tradeNumberService: tradeNumberService,
            tradingNotificationService: tradingNotificationService,
            invoiceService: invoiceService,
            tradeAPIService: tradeAPIService,
            userService: userService
        )
        return service
    }

    func createOrderStatusSimulationService(orderManagementService: OrderManagementService) -> OrderStatusSimulationService {
        return OrderStatusSimulationService(orderManagementService: orderManagementService)
    }

    func createTradingNotificationService(documentService: any DocumentServiceProtocol) -> TradingNotificationService {
        return TradingNotificationService(
            documentService: documentService,
            invoiceService: invoiceService,
            transactionIdService: transactionIdService,
            userService: userService
        )
    }

    func createTradeMatchingService() -> TradeMatchingService {
        return TradeMatchingService()
    }

    func createSecuritiesWatchlistService(
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil,
        marketDataService: (any MarketDataServiceProtocol)? = nil
    ) -> SecuritiesWatchlistService {
        return SecuritiesWatchlistService(
            parseLiveQueryClient: parseLiveQueryClient,
            marketDataService: marketDataService
        )
    }

    func createTradingStatisticsService() -> TradingStatisticsService {
        return TradingStatisticsService()
    }

    func createProfitDistributionService(
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        commissionAccumulationService: (any CommissionAccumulationServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        traderCashBalanceService: (any TraderCashBalanceServiceProtocol)? = nil,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil
    ) -> ProfitDistributionService {
        return ProfitDistributionService(
            commissionCalculationService: commissionCalculationService,
            investorGrossProfitService: investorGrossProfitService,
            commissionAccumulationService: commissionAccumulationService,
            poolTradeParticipationService: poolTradeParticipationService,
            traderCashBalanceService: traderCashBalanceService,
            investmentService: investmentService,
            userService: userService,
            traderDataService: traderDataService,
            configurationService: configurationService
        )
    }

    func createInvestmentActivationService(
        investmentService: (any InvestmentServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil
    ) -> InvestmentActivationService {
        return InvestmentActivationService(
            investmentService: investmentService,
            poolTradeParticipationService: poolTradeParticipationService,
            userService: userService,
            traderDataService: traderDataService
        )
    }

    func createOrderLifecycleCoordinator(
        orderManagementService: OrderManagementService,
        orderStatusSimulationService: OrderStatusSimulationService,
        tradingNotificationService: TradingNotificationService,
        tradeLifecycleService: TradeLifecycleService,
        tradeMatchingService: TradeMatchingService,
        investmentActivationService: (any InvestmentActivationServiceProtocol)? = nil,
        profitDistributionService: (any ProfitDistributionServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        userService: any UserServiceProtocol,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil
    ) -> OrderLifecycleCoordinator {
        return OrderLifecycleCoordinator(
            orderManagementService: orderManagementService,
            orderStatusSimulationService: orderStatusSimulationService,
            tradingNotificationService: tradingNotificationService,
            tradeLifecycleService: tradeLifecycleService,
            tradeMatchingService: tradeMatchingService,
            cashBalanceService: cashBalanceService,
            investmentActivationService: investmentActivationService,
            profitDistributionService: profitDistributionService,
            poolTradeParticipationService: poolTradeParticipationService,
            userService: userService,
            investmentService: investmentService,
            documentService: documentService,
            configurationService: configurationService,
            investorGrossProfitService: investorGrossProfitService,
            commissionCalculationService: commissionCalculationService
        )
    }

    func createTradingStateStore(
        orderManagementService: OrderManagementService,
        tradeLifecycleService: TradeLifecycleService,
        securitiesWatchlistService: SecuritiesWatchlistService,
        orderStatusSimulationService: OrderStatusSimulationService
    ) -> LegacyTradingStateStore {
        return LegacyTradingStateStore(
            orderManagementService: orderManagementService,
            tradeLifecycleService: tradeLifecycleService,
            securitiesWatchlistService: securitiesWatchlistService,
            orderStatusSimulationService: orderStatusSimulationService
        )
    }

    func createTradeLifecycleCoordinator(tradeLifecycleService: TradeLifecycleService) -> TradeLifecycleCoordinator {
        return TradeLifecycleCoordinator(tradeLifecycleService: tradeLifecycleService)
    }

    func createTradingCoordinator(
        tradingStateStore: LegacyTradingStateStore,
        orderLifecycleCoordinator: OrderLifecycleCoordinator,
        tradeLifecycleCoordinator: TradeLifecycleCoordinator,
        securitiesWatchlistService: SecuritiesWatchlistService,
        tradingStatisticsService: TradingStatisticsService
    ) -> TradingCoordinator {
        return TradingCoordinator(
            tradingStateStore: tradingStateStore,
            orderLifecycleCoordinator: orderLifecycleCoordinator,
            tradeLifecycleCoordinator: tradeLifecycleCoordinator,
            securitiesWatchlistService: securitiesWatchlistService,
            tradingStatisticsService: tradingStatisticsService
        )
    }

    func createTraderService(tradingCoordinator: TradingCoordinator) -> TraderService {
        return TraderService(tradingCoordinator: tradingCoordinator)
    }

    // MARK: - Commission Services

    func createCommissionSettlementService(
        commissionAccumulationService: any CommissionAccumulationServiceProtocol,
        traderCashBalanceService: any TraderCashBalanceServiceProtocol,
        userService: any UserServiceProtocol
    ) -> CommissionSettlementService {
        return CommissionSettlementService(
            commissionAccumulationService: commissionAccumulationService,
            traderCashBalanceService: traderCashBalanceService,
            documentService: nil,
            invoiceService: invoiceService,
            transactionIdService: transactionIdService,
            userService: userService
        )
    }

    // MARK: - New Centralized Services

    /// Creates InvestorGrossProfitService - single source of truth for investor gross profit
    func createInvestorGrossProfitService(
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        investmentService: any InvestmentServiceProtocol
    ) -> InvestorGrossProfitService {
        let calculationService = InvestorCollectionBillCalculationService()
        return InvestorGrossProfitService(
            poolTradeParticipationService: poolTradeParticipationService,
            tradeLifecycleService: tradeLifecycleService,
            invoiceService: invoiceService,
            investmentService: investmentService,
            calculationService: calculationService
        )
    }

    /// Creates enhanced CommissionCalculationService with investor-specific methods
    func createCommissionCalculationService(
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?
    ) -> CommissionCalculationService {
        return CommissionCalculationService(investorGrossProfitService: investorGrossProfitService)
    }

    // MARK: - Access to Core Services
    var coreTransactionIdService: TransactionIdService { transactionIdService }
    var coreTradeNumberService: TradeNumberService { tradeNumberService }
    var coreCashBalanceService: CashBalanceService { cashBalanceService }
    var coreInvoiceService: InvoiceService { invoiceService }
}
