import Foundation

extension AppServicesBuilder {

    enum Core {
        static func build(_ ctx: inout AppServicesBuildContext) {
            let mockDataGenerator = MockDataGenerator()
            let searchFilterManager = SearchFilterService()
            let securitiesSearchService = SecuritiesSearchService(mockDataGenerator: mockDataGenerator)
            let securitiesSearchCoordinator = SecuritiesSearchCoordinator(
                searchService: securitiesSearchService,
                filterManager: searchFilterManager
            )
            ctx.mockDataGenerator = mockDataGenerator
            ctx.searchFilterManager = searchFilterManager
            ctx.securitiesSearchService = securitiesSearchService
            ctx.securitiesSearchCoordinator = securitiesSearchCoordinator

            let userService = UserService()
            let configurationService = ConfigurationService(userService: userService)
            ctx.userService = userService
            ctx.configurationService = configurationService

            let defaultParseServerURL = "http://192.168.178.20/parse"
            let parseServerURL = configurationService.parseServerURL ?? defaultParseServerURL
            let parseApplicationId = configurationService.parseApplicationId ?? "fin1-app-id"

            let conflictResolver = ConflictResolutionService(strategy: .lastWriteWins)
            let networkLogger = NetworkLogger.shared
            let parseAPIClient = ParseAPIClient(
                baseURL: parseServerURL,
                applicationId: parseApplicationId,
                sessionTokenProvider: { [weak userService] in userService?.sessionToken },
                offlineQueue: nil
            )
            Task { @MainActor in
                let offlineQueue = OfflineOperationQueue.shared
                parseAPIClient.configure(offlineQueue: offlineQueue)
            }
            parseAPIClient.configure(conflictResolver: conflictResolver)
            parseAPIClient.configure(networkLogger: networkLogger)
            configurationService.configureParseAPIClient(parseAPIClient)

            Task { @MainActor in
                let healthMonitor = BackendHealthMonitor.shared
                healthMonitor.configure(parseAPIClient: parseAPIClient)
                healthMonitor.configure(parseServerURL: parseServerURL, applicationId: "fin1-app-id")
                healthMonitor.startMonitoring()
            }

            userService.configure(parseAPIClient: parseAPIClient)

            let parseLiveQueryURL = configurationService.parseLiveQueryURL ?? "wss://192.168.178.20/parse"
            let parseLiveQueryClient = ParseLiveQueryClient(
                liveQueryURL: parseLiveQueryURL,
                applicationId: parseApplicationId,
                sessionToken: userService.sessionToken
            )
            ctx.parseAPIClient = parseAPIClient
            ctx.parseLiveQueryClient = parseLiveQueryClient
            ctx.settlementAPIService = SettlementAPIService(apiClient: parseAPIClient)

            let serviceFactory = ServiceFactory(configurationService: configurationService, userService: userService)
            serviceFactory.configureInvoiceService(parseAPIClient: parseAPIClient)
            ctx.serviceFactory = serviceFactory

            let documentAPIService = DocumentAPIService(apiClient: parseAPIClient)
            let documentService = DocumentService(documentAPIService: documentAPIService)
            ctx.documentService = documentService

            let auditLoggingService = AuditLoggingService(parseAPIClient: parseAPIClient)
            ctx.auditLoggingService = auditLoggingService

            let cashBalanceService = CashBalanceService(
                configurationService: configurationService,
                parseLiveQueryClient: parseLiveQueryClient,
                userService: userService
            )
            ctx.cashBalanceService = cashBalanceService

            let tradeAPIService = TradeAPIService(apiClient: parseAPIClient)
            let marketDataService = MarketDataService(
                parseLiveQueryClient: parseLiveQueryClient,
                parseAPIClient: parseAPIClient
            )
            let priceAlertService = PriceAlertService(
                parseAPIClient: parseAPIClient,
                parseLiveQueryClient: parseLiveQueryClient,
                marketDataService: marketDataService,
                userService: userService
            )
            let orderAPIService = OrderAPIService(apiClient: parseAPIClient)
            let watchlistAPIService = WatchlistAPIService(apiClient: parseAPIClient)
            let filterAPIService = FilterAPIService(apiClient: parseAPIClient)
            let filterSyncService = FilterSyncService(filterAPIService: filterAPIService, userService: userService)
            let pushTokenAPIService = PushTokenAPIService(apiClient: parseAPIClient)
            let notificationAPIService = NotificationAPIService(apiClient: parseAPIClient)
            let investorWatchlistAPIService = InvestorWatchlistAPIService(apiClient: parseAPIClient)

            ctx.tradeAPIService = tradeAPIService
            ctx.marketDataService = marketDataService
            ctx.priceAlertService = priceAlertService
            ctx.orderAPIService = orderAPIService
            ctx.watchlistAPIService = watchlistAPIService
            ctx.filterAPIService = filterAPIService
            ctx.filterSyncService = filterSyncService
            ctx.pushTokenAPIService = pushTokenAPIService
            ctx.notificationAPIService = notificationAPIService
            ctx.investorWatchlistAPIService = investorWatchlistAPIService

            ctx.appLedgerService = AppLedgerService(parseAPIClient: parseAPIClient)

            ctx.filterPersistenceRepository = FilterPersistenceRepository()
            ctx.investmentQuantityCalculationService = InvestmentQuantityCalculationService()
            ctx.investorCashBalanceService = InvestorCashBalanceService(
                configurationService: configurationService,
                parseLiveQueryClient: parseLiveQueryClient,
                userService: userService
            )
        }
    }
}
