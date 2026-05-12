import Foundation

extension AppServicesBuilder {

    @MainActor
    enum Trader {
        static func build(_ ctx: inout AppServicesBuildContext) {
            guard let serviceFactory = ctx.serviceFactory,
                  let orderAPIService = ctx.orderAPIService,
                  let documentService = ctx.documentService,
                  let tradeAPIService = ctx.tradeAPIService,
                  let parseLiveQueryClient = ctx.parseLiveQueryClient,
                  let marketDataService = ctx.marketDataService,
                  let userService = ctx.userService,
                  let watchlistAPIService = ctx.watchlistAPIService else { return }

            ctx.orderManagementService = serviceFactory.createOrderManagementService(orderAPIService: orderAPIService)
            ctx.orderStatusSimulationService = serviceFactory.createOrderStatusSimulationService(
                orderManagementService: ctx.orderManagementService!
            )
            ctx.tradingNotificationService = serviceFactory.createTradingNotificationService(documentService: documentService)
            ctx.tradeLifecycleService = serviceFactory.createTradeLifecycleService(
                tradingNotificationService: ctx.tradingNotificationService!,
                tradeAPIService: tradeAPIService
            )
            ctx.tradeMatchingService = serviceFactory.createTradeMatchingService()
            ctx.securitiesWatchlistService = serviceFactory.createSecuritiesWatchlistService(
                parseLiveQueryClient: parseLiveQueryClient,
                marketDataService: marketDataService,
                userService: userService,
                watchlistAPIService: watchlistAPIService
            )
            ctx.tradingStatisticsService = serviceFactory.createTradingStatisticsService()
        }
    }
}
