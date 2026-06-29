import Foundation

/// Injected services for the buy-order flow — keeps `BuyOrderViewModel` free of composition-root wiring.
@MainActor
struct BuyOrderDependencies {
    let traderService: any TraderServiceProtocol
    let cashBalanceService: any CashBalanceServiceProtocol
    let configurationService: any ConfigurationServiceProtocol
    let investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol
    let investmentService: any InvestmentServiceProtocol
    let userService: any UserServiceProtocol
    let traderDataService: (any TraderDataServiceProtocol)?
    let auditLoggingService: any AuditLoggingServiceProtocol
    let transactionLimitService: (any TransactionLimitServiceProtocol)?
    let parseAPIClient: (any ParseAPIClientProtocol)?

    init(
        traderService: any TraderServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil,
        auditLoggingService: any AuditLoggingServiceProtocol,
        transactionLimitService: (any TransactionLimitServiceProtocol)? = nil,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil
    ) {
        self.traderService = traderService
        self.cashBalanceService = cashBalanceService
        self.configurationService = configurationService
        self.investmentQuantityCalculationService = investmentQuantityCalculationService
        self.investmentService = investmentService
        self.userService = userService
        self.traderDataService = traderDataService
        self.auditLoggingService = auditLoggingService
        self.transactionLimitService = transactionLimitService
        self.parseAPIClient = parseAPIClient
    }

    init(services: AppServices) {
        self.init(
            traderService: services.traderService,
            cashBalanceService: services.cashBalanceService,
            configurationService: services.configurationService,
            investmentQuantityCalculationService: services.investmentQuantityCalculationService,
            investmentService: services.investmentService,
            userService: services.userService,
            traderDataService: services.traderDataService,
            auditLoggingService: services.auditLoggingService,
            transactionLimitService: services.transactionLimitService,
            parseAPIClient: services.parseAPIClient
        )
    }

    func resolvedParseAPIClient() -> (any ParseAPIClientProtocol)? {
        self.parseAPIClient ?? (self.configurationService as? ConfigurationService)?.getParseAPIClient()
    }
}
