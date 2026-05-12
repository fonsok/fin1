import Foundation
import Combine

@MainActor
final class BuyOrderViewModel: ObservableObject, LimitOrderMonitor {
    // MARK: - Published Properties
    @Published var searchResult: SearchResult
    @Published var quantity: Double = 1000
    @Published var quantityText: String = "1.000"
    @Published var orderMode: OrderMode = .market
    @Published var limit: String = ""
    @Published var estimatedCost: Double = 0.0
    @Published var orderStatus: BuyOrderStatus = .idle
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
        get { priceValidityTimerManager.priceValidityProgress }
        set { priceValidityTimerManager.priceValidityProgress = newValue }
    }
    private let priceValidityTimerManager: PriceValidityTimerManager
    let quantityInputManager: QuantityInputManager
    private var limitOrderMonitor: BuyOrderMonitorImpl?
    private let limitOrderMonitoringService: any LimitOrderMonitoringServiceProtocol

    var currentPriceValue: Double {
        Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }
    var exceedsMaximum: Bool { quantityInputManager.exceedsMaximum }
    var hasInsufficientFunds: Bool { showInsufficientFundsWarning }
    var insufficientFundsMessage: String {
        guard let currentUser = userService.currentUser else { return "Please log in to check your balance." }
        let currentBalance = cashBalanceService.currentBalance
        let estimatedBalance = cashBalanceService.estimatedBalanceAfterPurchase(amount: estimatedCost)
        let minimumReserve = configurationService.getMinimumCashReserve(for: currentUser.id)
        let shortfall = minimumReserve - estimatedBalance
        return "Insufficient funds. Current balance: €\(currentBalance.formatted(.currency(code: "EUR"))), Estimated after purchase: €\(estimatedBalance.formatted(.currency(code: "EUR"))). Need €\(shortfall.formatted(.currency(code: "EUR"))) more to maintain minimum reserve of €\(minimumReserve.formatted(.currency(code: "EUR")))."
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
    private let placementService: any BuyOrderPlacementServiceProtocol
    let investmentDataProvider: any BuyOrderInvestmentDataProviderProtocol
    let transactionLimitService: (any TransactionLimitServiceProtocol)?

    // MARK: - Transaction Limit State
    @Published var transactionLimitCheckResult: TransactionLimitCheckResult?
    @Published var remainingDailyLimit: Double?
    @Published var showLimitWarning: Bool = false
    @Published var limitWarningMessage: String?

    // Helpers (extracted for file size reduction; internal for extensions)
    var quantityConstraintHelper: BuyOrderQuantityConstraintHelper {
        BuyOrderQuantityConstraintHelper(searchResult: searchResult)
    }

    // Maximum allowed quantity
    private let maxQuantity: Int = 10_000_000

    // MARK: - Computed Properties
    var limitPrice: Double? {
        guard orderMode == .limit, !limit.isEmpty, validator.validateLimitPrice(limit) else {
            return nil
        }
        return Double(limit.replacingOccurrences(of: ",", with: "."))
    }

    var canPlaceOrder: Bool {
        return validator.validateOrderPlacement(
            quantity: quantity,
            orderMode: orderMode,
            limit: limit,
            priceValidityProgress: priceValidityProgress,
            estimatedCost: estimatedCost,
            userService: userService,
            cashBalanceService: cashBalanceService,
            configurationService: configurationService,
            maxQuantity: maxQuantity
        )
    }

    init(
        searchResult: SearchResult,
        traderService: any TraderServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        userService: any UserServiceProtocol,
        traderDataService: (any TraderDataServiceProtocol)? = nil,
        limitOrderMonitoringService: any LimitOrderMonitoringServiceProtocol = LimitOrderMonitoringService(),
        investmentCalculator: any BuyOrderInvestmentCalculatorProtocol = BuyOrderInvestmentCalculator(),
        validator: any BuyOrderValidatorProtocol = BuyOrderValidator(),
        placementService: (any BuyOrderPlacementServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil,
        transactionLimitService: (any TransactionLimitServiceProtocol)? = nil,
        investmentDataProvider: (any BuyOrderInvestmentDataProviderProtocol)? = nil
    ) {
        self.searchResult = searchResult
        self.traderService = traderService
        self.cashBalanceService = cashBalanceService
        self.configurationService = configurationService
        self.investmentQuantityCalculationService = investmentQuantityCalculationService
        self.investmentService = investmentService
        self.userService = userService
        self.traderDataService = traderDataService
        self.limitOrderMonitoringService = limitOrderMonitoringService
        self.investmentCalculator = investmentCalculator
        self.validator = validator
        self.transactionLimitService = transactionLimitService
        let parseAPIClient = (configurationService as? ConfigurationService)?.getParseAPIClient()
        // Create placement service with audit logging and transaction limits if not provided
        if let providedService = placementService {
            self.placementService = providedService
        } else if let auditService = auditLoggingService {
            self.placementService = BuyOrderPlacementService(
                auditLoggingService: auditService,
                userService: userService,
                transactionLimitService: transactionLimitService,
                parseAPIClient: parseAPIClient
            )
        } else {
            // Fallback: Create without audit logging (for backward compatibility)
            // This should not happen in production - audit logging should always be provided
            self.placementService = BuyOrderPlacementService(
                auditLoggingService: AuditLoggingService(),
                userService: userService,
                transactionLimitService: transactionLimitService,
                parseAPIClient: parseAPIClient
            )
        }
        // Create provider with default implementation if not provided
        self.investmentDataProvider = investmentDataProvider ?? BuyOrderInvestmentDataProvider(
            investmentService: investmentService,
            traderDataService: traderDataService
        )
        self.quantityInputManager = QuantityInputManager(initialQuantity: 1000)
        self.priceValidityTimerManager = PriceValidityTimerManager()

        // Forward price validity progress changes
        priceValidityTimerManager.$priceValidityProgress
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Initialize the limit order monitor through service
        self.limitOrderMonitor = limitOrderMonitoringService.createBuyOrderMonitor(for: self)

        setupBindings()
        reloadPrice()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-prefill-limit-order") {
            quantityText = "100"
            orderMode = .limit
            limit = "1,00"
        }
        #endif

        // Setup investment observation
        setupInvestmentObservation()

        // Calculate investment order when quantity or price changes
        Task {
            await calculateInvestmentOrder()
        }
    }

    func reloadPrice() {
        // Simulate price update by a small random amount (+/- 1%)
        if let currentPrice = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) {
            var updatedResult = searchResult
            updatedResult.askPrice = String(format: "%.2f", currentPrice * Double.random(in: 0.99...1.01))
                .replacingOccurrences(of: ".", with: ",")
            searchResult = updatedResult
        }
        startPriceValidityTimer()
        if orderMode == .limit, let price = limitPrice, price > 0, !isMonitoringLimitOrder {
            startLimitOrderMonitoring()
        }
    }

    func startPriceValidityTimer() {
        priceValidityTimerManager.startTimer()
    }

    func placeOrder() async {
        if case .transmitting = orderStatus {
            print("🔍 DEBUG: placeOrder ignored - already transmitting")
            return
        }
        orderStatus = .transmitting

        // Calculate investment order if not already calculated
        if investmentOrderCalculation == nil {
            await calculateInvestmentOrder()
        }

        do {
            let result = try await placementService.placeOrder(
                searchResult: searchResult,
                quantity: Int(quantity),
                orderMode: orderMode,
                limit: limit,
                priceValidityProgress: priceValidityProgress,
                investmentOrderCalculation: investmentOrderCalculation,
                traderService: traderService
            )

            if result.success {
                // Order was successfully created and will appear in ongoing transactions
                // The status progression will happen automatically via the timer
                // Set status to idle to dismiss the view immediately
                orderStatus = .idle
                // Trigger navigation to depot view for successful order placement
                shouldShowDepotView = true
            } else if let error = result.error {
                orderStatus = .failed(error)
            } else {
                orderStatus = .failed(.unknown("Unbekannter Fehler bei der Orderplatzierung."))
            }
        } catch is CancellationError {
            // If task gets cancelled (e.g. view lifecycle), avoid leaving UI in transmitting state.
            orderStatus = .idle
        } catch let appError as AppError {
            orderStatus = .failed(appError)
        } catch {
            orderStatus = .failed(error.toAppError())
        }
    }

    func resetOrderStatus() {
        orderStatus = .idle
    }

    // MARK: - Automatic Limit Order Monitoring

    func startLimitOrderMonitoring() {
        limitOrderMonitor?.startLimitOrderMonitoring()
    }

    func stopLimitOrderMonitoring() {
        limitOrderMonitor?.stopLimitOrderMonitoring()
    }

    // MARK: - Limit Price Management

    /// Called when the user changes the limit price input
    func onLimitPriceChanged() {
        if isMonitoringLimitOrder {
            stopLimitOrderMonitoring()
        }
    }

}
