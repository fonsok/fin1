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
    var investmentManagementService: InvestmentManagementService?
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
    var roundingDifferencesService: RoundingDifferencesService?
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

    func toAppServices() -> AppServices {
        AppServices(
            userService: userService!,
            investmentService: investmentService!,
            poolTradeParticipationService: poolTradeParticipationService!,
            notificationService: notificationService!,
            documentService: documentService!,
            watchlistService: watchlistService!,
            traderDataService: traderDataService!,
            dashboardService: dashboardService!,
            traderService: TraderService(tradingCoordinator: tradingCoordinator!),
            telemetryService: telemetryService!,
            testModeService: testModeService!,
            filterPersistenceRepository: filterPersistenceRepository!,
            securitiesSearchService: securitiesSearchService!,
            mockDataGenerator: mockDataGenerator!,
            searchFilterManager: searchFilterManager!,
            securitiesSearchCoordinator: securitiesSearchCoordinator!,
            orderManagementService: orderManagementService!,
            tradeLifecycleService: tradeLifecycleService!,
            securitiesWatchlistService: securitiesWatchlistService!,
            tradingStatisticsService: tradingStatisticsService!,
            orderStatusSimulationService: orderStatusSimulationService!,
            tradingNotificationService: tradingNotificationService!,
            tradeMatchingService: tradeMatchingService!,
            tradingCoordinator: tradingCoordinator!,
            invoiceService: serviceFactory!.coreInvoiceService,
            transactionIdService: serviceFactory!.coreTransactionIdService,
            tradeNumberService: serviceFactory!.coreTradeNumberService,
            cashBalanceService: cashBalanceService!,
            configurationService: configurationService!,
            investmentQuantityCalculationService: investmentQuantityCalculationService!,
            investorCashBalanceService: investorCashBalanceService!,
            unifiedOrderService: unifiedOrderService!,
            tradingStateStore: mainTradingStateStore!,
            roundingDifferencesService: roundingDifferencesService!,
            investorGrossProfitService: investorGrossProfitService!,
            commissionCalculationService: commissionCalculationService!,
            commissionAccumulationService: commissionAccumulationService!,
            commissionSettlementService: commissionSettlementService!,
            holdingsConversionService: holdingsConversionService!,
            termsAcceptanceService: termsAcceptanceService!,
            termsContentService: termsContentService!,
            riskClassCalculationService: riskClassCalculationService!,
            investmentExperienceCalculationService: investmentExperienceCalculationService!,
            addressChangeService: addressChangeService!,
            nameChangeService: nameChangeService!,
            paymentService: paymentService!,
            transactionLimitService: transactionLimitService!,
            parseAPIClient: parseAPIClient,
            parseLiveQueryClient: parseLiveQueryClient,
            marketDataService: marketDataService,
            priceAlertService: priceAlertService,
            filterSyncService: filterSyncService,
            auditLoggingService: auditLoggingService!,
            customerSupportService: customerSupportService!,
            satisfactionSurveyService: satisfactionSurveyService!,
            faqKnowledgeBaseService: faqKnowledgeBaseService!,
            slaMonitoringService: slaMonitoringService!,
            fourEyesApprovalService: fourEyesApprovalService!,
            faqContentService: FAQContentService(
                parseAPIClient: parseAPIClient!,
                cacheTTL: {
                    #if DEBUG
                    return 60 * 5 // 5 minutes in debug to reflect admin-portal edits quickly
                    #else
                    return 60 * 60 * 24 // 24h in release
                    #endif
                }()
            ),
            templateAPIService: templateAPIService,
            appLedgerService: appLedgerService!,
            settlementAPIService: settlementAPIService,
            authService: authService!,
            tokenStorage: tokenStorage!,
            onboardingAPIService: OnboardingAPIService(apiClient: parseAPIClient!)
        )
    }
}
