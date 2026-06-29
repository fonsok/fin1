import SwiftUI

// MARK: - Buy Order View Wrapper

struct BuyOrderViewWrapper: View {
    let searchResult: SearchResult
    let traderService: any TraderServiceProtocol
    let cashBalanceService: any CashBalanceServiceProtocol
    let configurationService: any ConfigurationServiceProtocol
    let investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol
    let investmentService: any InvestmentServiceProtocol
    let userService: any UserServiceProtocol
    let traderDataService: (any TraderDataServiceProtocol)?
    let onOrderPlaced: (() -> Void)?
    @StateObject private var viewModel: BuyOrderViewModel

    init(
        searchResult: SearchResult,
        traderService: any TraderServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil,
        transactionLimitService: (any TransactionLimitServiceProtocol)? = nil,
        viewModel: BuyOrderViewModel? = nil,
        onOrderPlaced: (() -> Void)? = nil
    ) {
        self.searchResult = searchResult
        self.traderService = traderService
        self.cashBalanceService = cashBalanceService
        self.configurationService = configurationService
        self.investmentQuantityCalculationService = investmentQuantityCalculationService
        self.investmentService = investmentService
        self.userService = userService
        self.traderDataService = traderDataService
        self.onOrderPlaced = onOrderPlaced
        self._viewModel = StateObject(
            wrappedValue: viewModel ?? Self.makeViewModel(
                searchResult: searchResult,
                traderService: traderService,
                cashBalanceService: cashBalanceService,
                configurationService: configurationService,
                investmentQuantityCalculationService: investmentQuantityCalculationService,
                investmentService: investmentService,
                userService: userService,
                traderDataService: traderDataService,
                auditLoggingService: auditLoggingService,
                transactionLimitService: transactionLimitService
            )
        )
    }

    var body: some View {
        BuyOrderView(viewModel: self.viewModel, onOrderPlaced: self.onOrderPlaced)
            .id(self.searchResult.wkn)
    }

    @MainActor
    static func makeViewModel(
        searchResult: SearchResult,
        traderService: any TraderServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil,
        transactionLimitService: (any TransactionLimitServiceProtocol)? = nil
    ) -> BuyOrderViewModel {
        BuyOrderViewModelFactory.make(
            searchResult: searchResult,
            dependencies: BuyOrderDependencies(
                traderService: traderService,
                cashBalanceService: cashBalanceService,
                configurationService: configurationService,
                investmentQuantityCalculationService: investmentQuantityCalculationService,
                investmentService: investmentService,
                userService: userService,
                traderDataService: traderDataService,
                auditLoggingService: auditLoggingService ?? AuditLoggingService(),
                transactionLimitService: transactionLimitService
            )
        )
    }

    /// Sheet entry: ViewModel is owned by `@StateObject` here — avoids empty sheets from split `@State` + `.sheet(item:)`.
    init(searchResult: SearchResult, services: AppServices, onOrderPlaced: (() -> Void)? = nil) {
        self.init(
            searchResult: searchResult,
            traderService: services.traderService,
            cashBalanceService: services.cashBalanceService,
            configurationService: services.configurationService,
            investmentQuantityCalculationService: services.investmentQuantityCalculationService,
            investmentService: services.investmentService,
            userService: services.userService,
            traderDataService: services.traderDataService,
            auditLoggingService: services.auditLoggingService,
            transactionLimitService: services.transactionLimitService,
            onOrderPlaced: onOrderPlaced
        )
    }
}
