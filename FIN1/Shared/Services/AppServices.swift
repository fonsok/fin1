import Foundation

// MARK: - Services Container (Composition Root)
/// Central dependency injection container that holds all service instances
/// This is the single source of truth for service dependencies in the app
///
/// `Sendable`: The composition root is created once at launch; services are not assumed thread-safe
/// as a group, but the container reference is passed read-only through SwiftUI environment.
struct AppServices: @unchecked Sendable {

    // MARK: - Core Services
    let userService: any UserServiceProtocol
    let investmentService: any InvestmentServiceProtocol
    let poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    let notificationService: any NotificationServiceProtocol
    let documentService: any DocumentServiceProtocol
    let watchlistService: any InvestorWatchlistServiceProtocol
    let traderDataService: any TraderDataServiceProtocol
    let dashboardService: any DashboardServiceProtocol
    let traderService: any TraderServiceProtocol
    let telemetryService: any TelemetryServiceProtocol
    let testModeService: any TestModeServiceProtocol

    // MARK: - Investor Feature Repositories
    let filterPersistenceRepository: any FilterPersistenceRepositoryProtocol

    // MARK: - Securities Search Services
    let securitiesSearchService: any SecuritiesSearchServiceProtocol
    let mockDataGenerator: any MockDataGeneratorProtocol
    let searchFilterManager: any SearchFilterServiceProtocol
    let securitiesSearchCoordinator: any SecuritiesSearchCoordinatorProtocol

    // MARK: - Focused Trader Services
    let orderManagementService: any OrderManagementServiceProtocol
    let tradeLifecycleService: any TradeLifecycleServiceProtocol
    let securitiesWatchlistService: any SecuritiesWatchlistServiceProtocol
    let tradingStatisticsService: any TradingStatisticsServiceProtocol
    let orderStatusSimulationService: any OrderStatusSimulationServiceProtocol
    let tradingNotificationService: any TradingNotificationServiceProtocol
    let tradeMatchingService: any TradeMatchingServiceProtocol
    let tradingCoordinator: any TradingCoordinatorProtocol
    let invoiceService: any InvoiceServiceProtocol
    let transactionIdService: any TransactionIdServiceProtocol
    let tradeNumberService: any TradeNumberServiceProtocol
    let cashBalanceService: any CashBalanceServiceProtocol
    let configurationService: any ConfigurationServiceProtocol
    let investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol
    let investorCashBalanceService: any InvestorCashBalanceServiceProtocol

    // MARK: - Unified Services (new architecture)
    let unifiedOrderService: any UnifiedOrderServiceProtocol
    let tradingStateStore: any TradingStateStoreProtocol
    let roundingDifferencesService: any RoundingDifferencesServiceProtocol

    // MARK: - Centralized Calculation Services (new architecture)
    let investorGrossProfitService: any InvestorGrossProfitServiceProtocol
    let commissionCalculationService: any CommissionCalculationServiceProtocol
    let commissionAccumulationService: any CommissionAccumulationServiceProtocol
    let commissionSettlementService: any CommissionSettlementServiceProtocol

    // MARK: - Holdings Conversion Service
    let holdingsConversionService: any HoldingsConversionServiceProtocol

    // MARK: - Legal Services
    let termsAcceptanceService: any TermsAcceptanceServiceProtocol
    let termsContentService: any TermsContentServiceProtocol

    // MARK: - Authentication Services
    let riskClassCalculationService: any RiskClassCalculationServiceProtocol
    let investmentExperienceCalculationService: any InvestmentExperienceCalculationServiceProtocol

    // MARK: - KYC Compliance Services
    let addressChangeService: any AddressChangeRequestServiceProtocol
    let nameChangeService: any NameChangeRequestServiceProtocol

    // MARK: - Payment Services
    let paymentService: any PaymentServiceProtocol

    // MARK: - Compliance Services
    let transactionLimitService: any TransactionLimitServiceProtocol

    // MARK: - Parse Server Services
    let parseAPIClient: (any ParseAPIClientProtocol)?
    let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?

    // MARK: - Market Data Services
    let marketDataService: (any MarketDataServiceProtocol)?
    let priceAlertService: (any PriceAlertServiceProtocol)?

    // MARK: - Filter Sync Services
    let filterSyncService: FilterSyncServiceProtocol?

    // MARK: - Customer Support Services
    let auditLoggingService: AuditLoggingServiceProtocol
    let customerSupportService: CustomerSupportServiceProtocol
    let satisfactionSurveyService: SatisfactionSurveyServiceProtocol
    let faqKnowledgeBaseService: FAQKnowledgeBaseServiceProtocol
    let slaMonitoringService: SLAMonitoringServiceProtocol
    let fourEyesApprovalService: FourEyesApprovalServiceProtocol
    let faqContentService: any FAQContentServiceProtocol
    let templateAPIService: TemplateAPIServiceProtocol?

    // MARK: - App Accounting Services
    let appLedgerService: any AppLedgerServiceProtocol

    // MARK: - Settlement Services (Backend-Authoritative)
    let settlementAPIService: (any SettlementAPIServiceProtocol)?

    // MARK: - Auth Provider Services
    let authService: AuthServiceProtocol
    let tokenStorage: TokenStorageProtocol

    // MARK: - Onboarding Services
    let onboardingAPIService: OnboardingAPIServiceProtocol?
    let companyKybAPIService: CompanyKybAPIServiceProtocol?

    // MARK: - Live Instance
    static let live: AppServices = {
        MainActor.assumeIsolated {
            let services = AppServicesBuilder.buildLiveServices()
            if let notificationService = services.notificationService as? NotificationService {
                print("🔔 AppServices.live: Created with NotificationService instance \(ObjectIdentifier(notificationService))")
            }
            return services
        }
    }()
}

