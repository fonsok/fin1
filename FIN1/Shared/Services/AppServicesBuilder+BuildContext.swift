import Foundation

// MARK: - Build Context
/// Holds all service instances during composition; used by AppServicesBuilder extensions.
struct AppServicesBuildContext {
    var userService: UserService?
    var configurationService: ConfigurationService?
    var parseAPIClient: ParseAPIClient?
    var parseLiveQueryClient: ParseLiveQueryClient?
    var serviceFactory: ServiceFactory?
    var documentService: DocumentService?
    var auditLoggingService: AuditLoggingService?
    var cashBalanceService: CashBalanceService?
    var mockDataGenerator: MockDataGenerator?
    var searchFilterManager: SearchFilterService?
    var securitiesSearchService: SecuritiesSearchService?
    var securitiesSearchCoordinator: SecuritiesSearchCoordinator?
    var tradeAPIService: TradeAPIService?
    var marketDataService: MarketDataService?
    var priceAlertService: PriceAlertService?
    var orderAPIService: OrderAPIService?
    var watchlistAPIService: WatchlistAPIService?
    var filterAPIService: FilterAPIService?
    var filterSyncService: FilterSyncService?
    var pushTokenAPIService: PushTokenAPIService?
    var notificationAPIService: NotificationAPIService?
    var investorWatchlistAPIService: InvestorWatchlistAPIService?
    var orderManagementService: OrderManagementService?
    var orderStatusSimulationService: OrderStatusSimulationService?
    var tradingNotificationService: TradingNotificationService?
    var tradeLifecycleService: TradeLifecycleService?
    var tradeMatchingService: TradeMatchingService?
    var securitiesWatchlistService: SecuritiesWatchlistService?
    var tradingStatisticsService: TradingStatisticsService?
    var filterPersistenceRepository: FilterPersistenceRepository?
    var investmentQuantityCalculationService: InvestmentQuantityCalculationService?
    var investorCashBalanceService: InvestorCashBalanceService?
    var investmentAPIService: InvestmentAPIService?
    var poolTradeParticipationService: PoolTradeParticipationService?
    var telemetryService: TelemetryService?
    var investmentPoolLifecycleService: InvestmentPoolLifecycleService?
    var investmentStatusService: InvestmentStatusService?
    var traderDataService: TraderDataService?
    var commissionAccumulationService: CommissionAccumulationService?
    var traderCashBalanceService: TraderCashBalanceService?
    var investmentDocumentService: InvestmentDocumentService?
    var investmentCompletionService: InvestmentCompletionService?
    var investmentService: InvestmentService?
    var investorGrossProfitService: InvestorGrossProfitService?
    var commissionCalculationService: CommissionCalculationService?
    var commissionSettlementService: CommissionSettlementService?
    var profitDistributionService: ProfitDistributionService?
    var investmentActivationService: InvestmentActivationService?
    var orderLifecycleCoordinator: OrderLifecycleCoordinator?
    var tradingStateStore: LegacyTradingStateStore?
    var tradeLifecycleCoordinator: TradeLifecycleCoordinator?
    var tradingCoordinator: TradingCoordinator?
    var notificationService: NotificationService?
    var watchlistService: InvestorWatchlistService?
    var dashboardService: DashboardService?
    var testModeService: TestModeService?
    var holdingsConversionService: HoldingsConversionService?
    var termsAcceptanceService: TermsAcceptanceService?
    var termsContentService: TermsContentService?
    var riskClassCalculationService: RiskClassCalculationService?
    var investmentExperienceCalculationService: InvestmentExperienceCalculationService?
    var addressChangeService: AddressChangeRequestService?
    var nameChangeService: NameChangeRequestService?
    var unifiedOrderService: UnifiedOrderService?
    var mainTradingStateStore: TradingStateStore?
    var satisfactionSurveyService: SatisfactionSurveyService?
    var ticketAPIService: TicketAPIService?
    var customerSupportService: CustomerSupportService?
    var faqKnowledgeBaseService: FAQKnowledgeBaseService?
    var templateAPIService: TemplateAPIService?
    var slaMonitoringService: SLAMonitoringService?
    var fourEyesApprovalService: FourEyesApprovalService?
    var tokenStorage: TokenStorageProtocol?
    var authService: AuthService?
    var paymentService: MockPaymentService?
    var transactionLimitService: TransactionLimitService?
    var settlementAPIService: SettlementAPIService?
    var appLedgerService: AppLedgerService?

    @MainActor
    func toAppServices() -> AppServices {
        AppServices(
            userService: self.userService!,
            investmentService: self.investmentService!,
            poolTradeParticipationService: self.poolTradeParticipationService!,
            notificationService: self.notificationService!,
            documentService: self.documentService!,
            watchlistService: self.watchlistService!,
            traderDataService: self.traderDataService!,
            dashboardService: self.dashboardService!,
            traderService: TraderService(tradingCoordinator: self.tradingCoordinator!),
            telemetryService: self.telemetryService!,
            testModeService: self.testModeService!,
            filterPersistenceRepository: self.filterPersistenceRepository!,
            securitiesSearchService: self.securitiesSearchService!,
            mockDataGenerator: self.mockDataGenerator!,
            searchFilterManager: self.searchFilterManager!,
            securitiesSearchCoordinator: self.securitiesSearchCoordinator!,
            orderManagementService: self.orderManagementService!,
            tradeLifecycleService: self.tradeLifecycleService!,
            securitiesWatchlistService: self.securitiesWatchlistService!,
            tradingStatisticsService: self.tradingStatisticsService!,
            orderStatusSimulationService: self.orderStatusSimulationService!,
            tradingNotificationService: self.tradingNotificationService!,
            tradeMatchingService: self.tradeMatchingService!,
            tradingCoordinator: self.tradingCoordinator!,
            invoiceService: self.serviceFactory!.coreInvoiceService,
            transactionIdService: self.serviceFactory!.coreTransactionIdService,
            tradeNumberService: self.serviceFactory!.coreTradeNumberService,
            cashBalanceService: self.cashBalanceService!,
            configurationService: self.configurationService!,
            investmentQuantityCalculationService: self.investmentQuantityCalculationService!,
            investorCashBalanceService: self.investorCashBalanceService!,
            unifiedOrderService: self.unifiedOrderService!,
            tradingStateStore: self.mainTradingStateStore!,
            investorGrossProfitService: self.investorGrossProfitService!,
            commissionCalculationService: self.commissionCalculationService!,
            commissionAccumulationService: self.commissionAccumulationService!,
            commissionSettlementService: self.commissionSettlementService!,
            holdingsConversionService: self.holdingsConversionService!,
            termsAcceptanceService: self.termsAcceptanceService!,
            termsContentService: self.termsContentService!,
            riskClassCalculationService: self.riskClassCalculationService!,
            investmentExperienceCalculationService: self.investmentExperienceCalculationService!,
            addressChangeService: self.addressChangeService!,
            nameChangeService: self.nameChangeService!,
            paymentService: self.paymentService!,
            transactionLimitService: self.transactionLimitService!,
            parseAPIClient: self.parseAPIClient,
            parseLiveQueryClient: self.parseLiveQueryClient,
            marketDataService: self.marketDataService,
            priceAlertService: self.priceAlertService,
            filterSyncService: self.filterSyncService,
            auditLoggingService: self.auditLoggingService!,
            customerSupportService: self.customerSupportService!,
            satisfactionSurveyService: self.satisfactionSurveyService!,
            faqKnowledgeBaseService: self.faqKnowledgeBaseService!,
            slaMonitoringService: self.slaMonitoringService!,
            fourEyesApprovalService: self.fourEyesApprovalService!,
            faqContentService: FAQContentService(
                parseAPIClient: self.parseAPIClient!,
                configurationService: self.configurationService!,
                cacheTTL: {
                    #if DEBUG
                    return 60 * 5 // 5 minutes in debug to reflect admin-portal edits quickly
                    #else
                    return 60 * 60 * 24 // 24h in release
                    #endif
                }()
            ),
            templateAPIService: self.templateAPIService,
            appLedgerService: self.appLedgerService!,
            settlementAPIService: self.settlementAPIService,
            authService: self.authService!,
            tokenStorage: self.tokenStorage!,
            onboardingAPIService: OnboardingAPIService(apiClient: self.parseAPIClient!),
            companyKybAPIService: CompanyKybAPIService(apiClient: self.parseAPIClient!)
        )
    }
}
