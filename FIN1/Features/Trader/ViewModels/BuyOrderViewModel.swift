import Combine
import Foundation

@MainActor
final class BuyOrderViewModel: ObservableObject, LimitOrderMonitor {
    // MARK: - Published Properties
    @Published var searchResult: SearchResult
    @Published var quantity: Double = 1_000
    @Published var quantityText: String = "1.000"
    @Published var orderMode: OrderMode = .market
    @Published var limit: String = ""
    @Published var estimatedCost: Double = 0.0
    @Published var placementSession = BuyOrderPlacementSession()
    @Published var showMaxValueWarning: Bool = false
    @Published var shouldShowDepotView: Bool = false
    @Published var showInsufficientFundsWarning: Bool = false
    @Published var quantityConstraintMessage: String?
    @Published var investmentOrderCalculation: CombinedOrderCalculationResult?
    @Published var showInvestmentCalculation = false
    @Published var isInvestmentLimited = false
    @Published var reservedInvestments: [Investment] = []
    @Published var isMonitoringLimitOrder: Bool = false

    // MARK: - Price Validity
    var priceValidityProgress: Double {
        get { self.priceValidityTimerManager.priceValidityProgress }
        set { self.priceValidityTimerManager.priceValidityProgress = newValue }
    }
    let priceValidityTimerManager: PriceValidityTimerManager
    let quantityInputManager: QuantityInputManager
    private var limitOrderMonitor: BuyOrderMonitorImpl?
    private let limitOrderMonitoringService: any LimitOrderMonitoringServiceProtocol

    var currentPriceValue: Double {
        Double(self.searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }
    var exceedsMaximum: Bool { self.quantityInputManager.exceedsMaximum }
    var hasInsufficientFunds: Bool { self.showInsufficientFundsWarning }
    var insufficientFundsMessage: String {
        BuyOrderFundsWarningBuilder.insufficientFundsMessage(
            userService: self.userService,
            cashBalanceService: self.cashBalanceService,
            configurationService: self.configurationService,
            estimatedCost: self.estimatedCost
        )
    }

    var cancellables = Set<AnyCancellable>()
    let traderService: any TraderServiceProtocol
    let cashBalanceService: any CashBalanceServiceProtocol
    let configurationService: any ConfigurationServiceProtocol
    let investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol
    let investmentService: any InvestmentServiceProtocol
    let userService: any UserServiceProtocol
    let traderDataService: (any TraderDataServiceProtocol)?
    let investmentCalculator: any BuyOrderInvestmentCalculatorProtocol
    private let validator: any BuyOrderValidatorProtocol
    let placementService: any BuyOrderPlacementServiceProtocol
    let investmentDataProvider: any BuyOrderInvestmentDataProviderProtocol
    let transactionLimitService: (any TransactionLimitServiceProtocol)?

    // MARK: - Transaction Limit State
    @Published var transactionLimitCheckResult: TransactionLimitCheckResult?
    @Published var remainingDailyLimit: Double?
    @Published var showLimitWarning: Bool = false
    @Published var limitWarningMessage: String?

    /// Coalesces concurrent pool-investment refreshes (`.task` + placeOrder).
    var poolInvestmentsRefreshTask: Task<Void, Never>?
    var transactionLimitCheckTask: Task<Void, Never>?
    var investmentCalculationTask: Task<Void, Never>?
    /// Guards `.task` pool reload when SwiftUI re-enters the buy sheet.
    var didLoadPoolInvestments = false

    var orderStatus: BuyOrderStatus {
        self.placementSession.buyOrderStatus
    }

    // Helpers (extracted for file size reduction; internal for extensions)
    var quantityConstraintHelper: BuyOrderQuantityConstraintHelper {
        BuyOrderQuantityConstraintHelper(searchResult: self.searchResult)
    }

    // Maximum allowed quantity
    private let maxQuantity: Int = 10_000_000

    // MARK: - Computed Properties
    var limitPrice: Double? {
        guard self.orderMode == .limit, !self.limit.isEmpty, self.validator.validateLimitPrice(self.limit) else {
            return nil
        }
        return Double(self.limit.replacingOccurrences(of: ",", with: "."))
    }

    /// Gross EUR for the trader-owned buy leg only (pool-mirror portion excluded).
    var traderLegEstimatedCost: Double {
        let price = self.limitPrice ?? self.currentPriceValue
        let traderQty = self.investmentOrderCalculation?.traderQuantity ?? max(Int(self.quantity), 0)
        return OrderCashAmount.grossAmount(quantity: traderQty, briefPricePerPiece: price)
    }

    var showMinBuyOrderWarning: Bool {
        let minimum = self.configurationService.minTraderBuyOrderAmount
        guard minimum > 0 else { return false }
        return self.traderLegEstimatedCost + 1e-6 < minimum
    }

    var minBuyOrderWarningMessage: String {
        let minimum = self.configurationService.minTraderBuyOrderAmount
        return "Der Trader-Anteil muss mindestens \(minimum.formattedAsLocalizedCurrency()) betragen "
            + "(aktuell: \(self.traderLegEstimatedCost.formattedAsLocalizedCurrency())). "
            + "Investoren-Kapital (Pool-Mirror) ist hiervon ausgenommen."
    }

    var canPlaceOrder: Bool {
        return self.validator.validateOrderPlacement(
            quantity: self.quantity,
            orderMode: self.orderMode,
            limit: self.limit,
            priceValidityProgress: self.priceValidityProgress,
            estimatedCost: self.estimatedCost,
            traderLegGrossAmount: self.traderLegEstimatedCost,
            userService: self.userService,
            cashBalanceService: self.cashBalanceService,
            configurationService: self.configurationService,
            maxQuantity: self.maxQuantity
        )
    }

    var isPlacingOrder: Bool {
        self.placementSession.phase.isPlacing
    }

    func mutatePlacementSession(_ body: (inout BuyOrderPlacementSession) -> Void) {
        var session = self.placementSession
        body(&session)
        self.placementSession = session
    }

    init(
        searchResult: SearchResult,
        dependencies: BuyOrderDependencies,
        limitOrderMonitoringService: any LimitOrderMonitoringServiceProtocol = LimitOrderMonitoringService(),
        investmentCalculator: any BuyOrderInvestmentCalculatorProtocol = BuyOrderInvestmentCalculator(),
        validator: any BuyOrderValidatorProtocol = BuyOrderValidator(),
        placementService: (any BuyOrderPlacementServiceProtocol)? = nil,
        investmentDataProvider: (any BuyOrderInvestmentDataProviderProtocol)? = nil
    ) {
        self.searchResult = searchResult
        self.traderService = dependencies.traderService
        self.cashBalanceService = dependencies.cashBalanceService
        self.configurationService = dependencies.configurationService
        self.investmentQuantityCalculationService = dependencies.investmentQuantityCalculationService
        self.investmentService = dependencies.investmentService
        self.userService = dependencies.userService
        self.traderDataService = dependencies.traderDataService
        self.limitOrderMonitoringService = limitOrderMonitoringService
        self.investmentCalculator = investmentCalculator
        self.validator = validator
        self.transactionLimitService = dependencies.transactionLimitService

        let parseAPIClient = dependencies.resolvedParseAPIClient()
        let resolvedDataProvider = investmentDataProvider ?? BuyOrderInvestmentDataProvider(
            investmentService: dependencies.investmentService,
            traderDataService: dependencies.traderDataService
        )
        self.investmentDataProvider = resolvedDataProvider
        let resolvedInvestmentAPIService = parseAPIClient.map { InvestmentAPIService(apiClient: $0) }

        if let providedService = placementService {
            self.placementService = providedService
        } else {
            self.placementService = BuyOrderPlacementService(
                auditLoggingService: dependencies.auditLoggingService,
                userService: dependencies.userService,
                transactionLimitService: dependencies.transactionLimitService,
                parseAPIClient: parseAPIClient,
                investmentAPIService: resolvedInvestmentAPIService,
                investmentService: dependencies.investmentService,
                investmentDataProvider: resolvedDataProvider
            )
        }

        self.quantityInputManager = QuantityInputManager(initialQuantity: 1_000)
        self.priceValidityTimerManager = PriceValidityTimerManager()

        // Forward price validity progress changes
        self.priceValidityTimerManager.$priceValidityProgress
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &self.cancellables)

        // Initialize the limit order monitor through service
        self.limitOrderMonitor = limitOrderMonitoringService.createBuyOrderMonitor(for: self)

        setupBindings()
        // Brief-Kurs timer starts after pool investments load (see `loadPoolInvestmentsIfNeeded`).
        self.priceValidityProgress = 1.0

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-prefill-limit-order") {
            self.quantityText = "100"
            self.orderMode = .limit
            self.limit = "1,00"
        }
        #endif

        // Setup investment observation
        setupInvestmentObservation()
    }

    func reloadPrice() {
        // Simulate price update by a small random amount (+/- 1%)
        if let currentPrice = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) {
            var updatedResult = self.searchResult
            updatedResult.askPrice = String(format: "%.2f", currentPrice * Double.random(in: 0.99...1.01))
                .replacingOccurrences(of: ".", with: ",")
            self.searchResult = updatedResult
        }
        self.startPriceValidityTimer()
        if self.orderMode == .limit, let price = limitPrice, price > 0, !isMonitoringLimitOrder {
            self.startLimitOrderMonitoring()
        }
    }

    func startPriceValidityTimer() {
        self.priceValidityTimerManager.startTimer()
    }

    @discardableResult
    func mutatePlacementSessionReturning<T>(_ body: (inout BuyOrderPlacementSession) -> T) -> T {
        var session = self.placementSession
        let value = body(&session)
        self.placementSession = session
        return value
    }

    // MARK: - Automatic Limit Order Monitoring

    func startLimitOrderMonitoring() {
        self.limitOrderMonitor?.startLimitOrderMonitoring()
    }

    func stopLimitOrderMonitoring() {
        self.limitOrderMonitor?.stopLimitOrderMonitoring()
    }

    // MARK: - Limit Price Management

    /// Called when the user changes the limit price input
    func onLimitPriceChanged() {
        if self.isMonitoringLimitOrder {
            self.stopLimitOrderMonitoring()
        }
    }
}
