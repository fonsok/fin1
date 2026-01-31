import Foundation

// MARK: - App Services Builder
/// Builds the complete service graph for the application
/// Handles all dependency injection and service wiring
enum AppServicesBuilder {

    /// Builds all live services with proper dependency injection
    static func buildLiveServices() -> AppServices {
        // Create search services
        let mockDataGenerator = MockDataGenerator()
        let searchFilterManager = SearchFilterService()
        let securitiesSearchService = SecuritiesSearchService(mockDataGenerator: mockDataGenerator)
        let securitiesSearchCoordinator = SecuritiesSearchCoordinator(
            searchService: securitiesSearchService,
            filterManager: searchFilterManager
        )

        // Create core service instances first
        let documentService = DocumentService()
        let userService = UserService()
        let configurationService = ConfigurationService(userService: userService)

        // Create Parse API client and Live Query client early (needed for services)
        let parseServerURL = configurationService.parseServerURL ?? "http://localhost:1337/parse"
        let parseApplicationId = configurationService.parseApplicationId ?? "fin1-app-id"
        let parseAPIClient = ParseAPIClient(
            baseURL: parseServerURL,
            applicationId: parseApplicationId,
            sessionToken: nil // TODO: Get session token from user service when authentication is implemented
        )
        let parseLiveQueryURL = configurationService.parseLiveQueryURL ?? "ws://localhost:1337/parse"
        let parseLiveQueryClient = ParseLiveQueryClient(
            liveQueryURL: parseLiveQueryURL,
            applicationId: parseApplicationId,
            sessionToken: nil // TODO: Get session token from user service when authentication is implemented
        )

        let serviceFactory = ServiceFactory(configurationService: configurationService, userService: userService)

        // Update CashBalanceService with Live Query support
        let cashBalanceService = CashBalanceService(
            configurationService: configurationService,
            parseLiveQueryClient: parseLiveQueryClient,
            userService: userService
        )
        // Replace the service in factory (if possible) or use the new instance directly

        // Parse API client and Live Query client are already created above
        let tradeAPIService = TradeAPIService(apiClient: parseAPIClient)

        // Create MarketDataService for real-time market data updates
        let marketDataService = MarketDataService(
            parseLiveQueryClient: parseLiveQueryClient,
            parseAPIClient: parseAPIClient
        )

        // Create PriceAlertService for price alerts
        let priceAlertService = PriceAlertService(
            parseAPIClient: parseAPIClient,
            parseLiveQueryClient: parseLiveQueryClient,
            marketDataService: marketDataService,
            userService: userService
        )

        // Create trader services using factory
        let orderManagementService = serviceFactory.createOrderManagementService()
        let orderStatusSimulationService = serviceFactory.createOrderStatusSimulationService(orderManagementService: orderManagementService)
        let tradingNotificationService = serviceFactory.createTradingNotificationService(documentService: documentService)
        let tradeLifecycleService = serviceFactory.createTradeLifecycleService(
            tradingNotificationService: tradingNotificationService,
            tradeAPIService: tradeAPIService
        )
        let tradeMatchingService = serviceFactory.createTradeMatchingService()
        let securitiesWatchlistService = serviceFactory.createSecuritiesWatchlistService(
            parseLiveQueryClient: parseLiveQueryClient,
            marketDataService: marketDataService
        )
        let tradingStatisticsService = serviceFactory.createTradingStatisticsService()

        // Create remaining core service instances
        let filterPersistenceRepository = FilterPersistenceRepository()
        let investmentQuantityCalculationService = InvestmentQuantityCalculationService()
        let investorCashBalanceService = InvestorCashBalanceService(
            configurationService: configurationService,
            parseLiveQueryClient: parseLiveQueryClient,
            userService: userService
        )
        let poolTradeParticipationService = PoolTradeParticipationService()
        let telemetryService = TelemetryService()
        let investmentManagementService = InvestmentManagementService()
        let traderDataService = TraderDataService()
        let commissionAccumulationService = CommissionAccumulationService()
        let traderCashBalanceService = TraderCashBalanceService(
            configurationService: configurationService,
            parseLiveQueryClient: parseLiveQueryClient,
            userService: userService
        )

        // Create investment services
        let investmentDocumentService = InvestmentDocumentService(
            documentService: documentService,
            transactionIdService: serviceFactory.coreTransactionIdService
        )
        let investmentCompletionService = InvestmentCompletionService(
            poolTradeParticipationService: poolTradeParticipationService,
            telemetryService: telemetryService,
            investorCashBalanceService: investorCashBalanceService,
            tradeLifecycleService: tradeLifecycleService,
            invoiceService: serviceFactory.coreInvoiceService,
            transactionIdService: serviceFactory.coreTransactionIdService,
            userService: userService,
            documentService: documentService,
            configurationService: configurationService
        )
        let investmentService = InvestmentService(
            investorCashBalanceService: investorCashBalanceService,
            poolTradeParticipationService: poolTradeParticipationService,
            telemetryService: telemetryService,
            documentService: documentService,
            investmentManagementService: investmentManagementService,
            investmentCompletionService: investmentCompletionService,
            investmentDocumentService: investmentDocumentService
        )

        // Create centralized services
        let investorGrossProfitService = serviceFactory.createInvestorGrossProfitService(
            poolTradeParticipationService: poolTradeParticipationService,
            tradeLifecycleService: tradeLifecycleService,
            investmentService: investmentService
        )
        let commissionCalculationService = serviceFactory.createCommissionCalculationService(
            investorGrossProfitService: investorGrossProfitService
        )

        // Configure InvestmentService with calculation services (resolves circular dependency)
        investmentService.configureCalculationServices(
            investorGrossProfitService: investorGrossProfitService,
            commissionCalculationService: commissionCalculationService
        )

        let commissionSettlementService = serviceFactory.createCommissionSettlementService(
            commissionAccumulationService: commissionAccumulationService,
            traderCashBalanceService: traderCashBalanceService,
            userService: userService
        )

        // Create services for order lifecycle
        let profitDistributionService = serviceFactory.createProfitDistributionService(
            commissionCalculationService: commissionCalculationService,
            investorGrossProfitService: investorGrossProfitService,
            commissionAccumulationService: commissionAccumulationService,
            poolTradeParticipationService: poolTradeParticipationService,
            traderCashBalanceService: traderCashBalanceService,
            investmentService: investmentService,
            userService: userService,
            traderDataService: traderDataService
        )

        let investmentActivationService = serviceFactory.createInvestmentActivationService(
            investmentService: investmentService,
            poolTradeParticipationService: poolTradeParticipationService,
            userService: userService,
            traderDataService: traderDataService
        )

        // Create coordinators
        let orderLifecycleCoordinator = serviceFactory.createOrderLifecycleCoordinator(
            orderManagementService: orderManagementService,
            orderStatusSimulationService: orderStatusSimulationService,
            tradingNotificationService: tradingNotificationService,
            tradeLifecycleService: tradeLifecycleService,
            tradeMatchingService: tradeMatchingService,
            investmentActivationService: investmentActivationService,
            profitDistributionService: profitDistributionService,
            poolTradeParticipationService: poolTradeParticipationService,
            userService: userService,
            investmentService: investmentService,
            documentService: documentService,
            investorGrossProfitService: investorGrossProfitService,
            commissionCalculationService: commissionCalculationService
        )

        let tradingStateStore = serviceFactory.createTradingStateStore(
            orderManagementService: orderManagementService,
            tradeLifecycleService: tradeLifecycleService,
            securitiesWatchlistService: securitiesWatchlistService,
            orderStatusSimulationService: orderStatusSimulationService
        )

        let tradeLifecycleCoordinator = serviceFactory.createTradeLifecycleCoordinator(tradeLifecycleService: tradeLifecycleService)

        let tradingCoordinator = serviceFactory.createTradingCoordinator(
            tradingStateStore: tradingStateStore,
            orderLifecycleCoordinator: orderLifecycleCoordinator,
            tradeLifecycleCoordinator: tradeLifecycleCoordinator,
            securitiesWatchlistService: securitiesWatchlistService,
            tradingStatisticsService: tradingStatisticsService
        )

        // Create remaining services
        // Pass the same documentService instance to NotificationService so it observes the correct instance
        let notificationService = NotificationService(documentService: documentService)
        print("🔔 AppServicesBuilder: Created NotificationService instance \(ObjectIdentifier(notificationService))")
        let watchlistService = InvestorWatchlistService()
        let dashboardService = DashboardService()
        let testModeService = TestModeService()
        let roundingDifferencesService = RoundingDifferencesService(telemetryService: telemetryService)

        // Holdings conversion service (singleton is acceptable here in composition root)
        let holdingsConversionService = HoldingsConversionService.shared

        // Legal services
        let termsAcceptanceService = TermsAcceptanceService()
        let termsContentService = TermsContentService(parseAPIClient: parseAPIClient)

        // Authentication calculation services
        let riskClassCalculationService = RiskClassCalculationService()
        let investmentExperienceCalculationService = InvestmentExperienceCalculationService()

        // KYC compliance services
        let addressChangeService = AddressChangeRequestService()
        let nameChangeService = NameChangeRequestService()

        // Customer Support services (RBAC, Audit Logging) - Create early for use in other services
        let auditLoggingService = AuditLoggingService(parseAPIClient: parseAPIClient)

        // Attach auditLoggingService to TradeLifecycleService (created earlier)
        tradeLifecycleService.attach(
            tradeNumberService: serviceFactory.coreTradeNumberService,
            tradingNotificationService: tradingNotificationService,
            invoiceService: serviceFactory.coreInvoiceService,
            tradeAPIService: tradeAPIService,
            userService: userService,
            auditLoggingService: auditLoggingService
        )

        // Initialize unified services (after auditLoggingService is created)
        let mainTradingStateStore = MainActor.assumeIsolated { TradingStateStore() }
        let unifiedOrderService: UnifiedOrderService = MainActor.assumeIsolated {
            UnifiedOrderService(
                transactionIdService: serviceFactory.coreTransactionIdService,
                orderStatusSimulationService: orderStatusSimulationService,
                tradingNotificationService: tradingNotificationService,
                cashBalanceService: cashBalanceService,
                tradeNumberService: serviceFactory.coreTradeNumberService,
                invoiceService: serviceFactory.coreInvoiceService,
                userService: userService,
                auditLoggingService: auditLoggingService
            )
        }
        let satisfactionSurveyService = SatisfactionSurveyService(notificationService: notificationService)
        let customerSupportService = CustomerSupportService(
            auditService: auditLoggingService,
            userService: userService,
            notificationService: notificationService,
            satisfactionSurveyService: satisfactionSurveyService,
            investmentService: investmentService,
            tradeLifecycleService: tradeLifecycleService
        )
        let faqKnowledgeBaseService = FAQKnowledgeBaseService(auditService: auditLoggingService)

        // Create SLA monitoring service
        let slaMonitoringService = SLAMonitoringService(
            supportService: customerSupportService,
            auditService: auditLoggingService,
            notificationService: notificationService,
            configurationService: configurationService
        )

        // Create Four-Eyes Approval service (4-Augen-Prinzip for AML/PSD2/GDPR compliance)
        let fourEyesApprovalService = FourEyesApprovalService(auditService: auditLoggingService)

        // Create Auth Provider services
        let tokenStorage: TokenStorageProtocol = {
            #if DEBUG
            return InMemoryTokenStorage()
            #else
            return KeychainTokenStorage()
            #endif
        }()

        let authProvider: AuthProviderProtocol = {
            #if DEBUG
            return MockAuthProvider(tokenStorage: tokenStorage)
            #else
            // In production, replace with real provider (Auth0, Okta, etc.)
            return MockAuthProvider(tokenStorage: tokenStorage) // Temporary
            #endif
        }()

        let authService = AuthService(authProvider: authProvider, tokenStorage: tokenStorage)

        // Create payment service
        let paymentService = MockPaymentService(
            cashBalanceService: cashBalanceService,
            userService: userService,
            investorCashBalanceService: investorCashBalanceService,
            auditLoggingService: auditLoggingService,
            parseAPIClient: parseAPIClient
        )

        // Create transaction limit service
        // Note: Risk class is stored in User.riskTolerance (calculated during signup Step 13+)
        let transactionLimitService = TransactionLimitService(
            userService: userService,
            auditLoggingService: auditLoggingService,
            parseAPIClient: parseAPIClient
        )

        return AppServices(
            userService: userService,
            investmentService: investmentService,
            poolTradeParticipationService: poolTradeParticipationService,
            notificationService: notificationService,
            documentService: documentService,
            watchlistService: watchlistService,
            traderDataService: traderDataService,
            dashboardService: dashboardService,
            traderService: TraderService(tradingCoordinator: tradingCoordinator),
            telemetryService: telemetryService,
            testModeService: testModeService,
            filterPersistenceRepository: filterPersistenceRepository,
            securitiesSearchService: securitiesSearchService,
            mockDataGenerator: mockDataGenerator,
            searchFilterManager: searchFilterManager,
            securitiesSearchCoordinator: securitiesSearchCoordinator,
            orderManagementService: orderManagementService,
            tradeLifecycleService: tradeLifecycleService,
            securitiesWatchlistService: securitiesWatchlistService,
            tradingStatisticsService: tradingStatisticsService,
            orderStatusSimulationService: orderStatusSimulationService,
            tradingNotificationService: tradingNotificationService,
            tradeMatchingService: tradeMatchingService,
            tradingCoordinator: tradingCoordinator,
            invoiceService: serviceFactory.coreInvoiceService,
            transactionIdService: serviceFactory.coreTransactionIdService,
            tradeNumberService: serviceFactory.coreTradeNumberService,
            cashBalanceService: cashBalanceService,
            configurationService: configurationService,
            investmentQuantityCalculationService: investmentQuantityCalculationService,
            investorCashBalanceService: investorCashBalanceService,
            unifiedOrderService: unifiedOrderService,
            tradingStateStore: mainTradingStateStore,
            roundingDifferencesService: roundingDifferencesService,
            investorGrossProfitService: investorGrossProfitService,
            commissionCalculationService: commissionCalculationService,
            commissionAccumulationService: commissionAccumulationService,
            commissionSettlementService: commissionSettlementService,
            holdingsConversionService: holdingsConversionService,
            termsAcceptanceService: termsAcceptanceService,
            termsContentService: termsContentService,
            riskClassCalculationService: riskClassCalculationService,
            investmentExperienceCalculationService: investmentExperienceCalculationService,
            addressChangeService: addressChangeService,
            nameChangeService: nameChangeService,
            paymentService: paymentService,
            transactionLimitService: transactionLimitService,
            parseAPIClient: parseAPIClient,
            parseLiveQueryClient: parseLiveQueryClient,
            marketDataService: marketDataService,
            priceAlertService: priceAlertService,
            auditLoggingService: auditLoggingService,
            customerSupportService: customerSupportService,
            satisfactionSurveyService: satisfactionSurveyService,
            faqKnowledgeBaseService: faqKnowledgeBaseService,
            slaMonitoringService: slaMonitoringService,
            fourEyesApprovalService: fourEyesApprovalService,
            faqContentService: FAQContentService(parseAPIClient: parseAPIClient),
            authService: authService,
            tokenStorage: tokenStorage
        )
    }
}
