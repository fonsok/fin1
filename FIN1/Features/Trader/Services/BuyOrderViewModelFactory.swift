import Foundation

@MainActor
enum BuyOrderViewModelFactory {

    static func make(
        searchResult: SearchResult,
        dependencies: BuyOrderDependencies,
        limitOrderMonitoringService: any LimitOrderMonitoringServiceProtocol = LimitOrderMonitoringService(),
        investmentCalculator: any BuyOrderInvestmentCalculatorProtocol = BuyOrderInvestmentCalculator(),
        validator: any BuyOrderValidatorProtocol = BuyOrderValidator(),
        placementService: (any BuyOrderPlacementServiceProtocol)? = nil,
        investmentDataProvider: (any BuyOrderInvestmentDataProviderProtocol)? = nil
    ) -> BuyOrderViewModel {
        BuyOrderViewModel(
            searchResult: searchResult,
            dependencies: dependencies,
            limitOrderMonitoringService: limitOrderMonitoringService,
            investmentCalculator: investmentCalculator,
            validator: validator,
            placementService: placementService,
            investmentDataProvider: investmentDataProvider
        )
    }
}
