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
        get { self.priceValidityTimerManager.priceValidityProgress }
        set { self.priceValidityTimerManager.priceValidityProgress = newValue }
    }
    private let priceValidityTimerManager: PriceValidityTimerManager
    let quantityInputManager: QuantityInputManager
    private var limitOrderMonitor: BuyOrderMonitorImpl?
    private let limitOrderMonitoringService: any LimitOrderMonitoringServiceProtocol

    var currentPriceValue: Double {
        Double(self.searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    }
    var exceedsMaximum: Bool { self.quantityInputManager.exceedsMaximum }
    var hasInsufficientFunds: Bool { self.showInsufficientFundsWarning }
    var insufficientFundsMessage: String {
        guard let currentUser = userService.currentUser else { return "Please log in to check your balance." }
        let currentBalance = self.cashBalanceService.currentBalance
        let estimatedBalance = self.cashBalanceService.estimatedBalanceAfterPurchase(amount: self.estimatedCost)
        let minimumReserve = self.configurationService.getMinimumCashReserve(for: currentUser.id)
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

    var canPlaceOrder: Bool {
        return self.validator.validateOrderPlacement(
            quantity: self.quantity,
            orderMode: self.orderMode,
            limit: self.limit,
            priceValidityProgress: self.priceValidityProgress,
            estimatedCost: self.estimatedCost,
            userService: self.userService,
            cashBalanceService: self.cashBalanceService,
            configurationService: self.configurationService,
            maxQuantity: self.maxQuantity
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
        self.reloadPrice()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-test-prefill-limit-order") {
            self.quantityText = "100"
            self.orderMode = .limit
            self.limit = "1,00"
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

    func placeOrder() async {
        if case .transmitting = self.orderStatus {
            print("🔍 DEBUG: placeOrder ignored - already transmitting")
            return
        }
        self.orderStatus = .transmitting

        // Calculate investment order if not already calculated
        if self.investmentOrderCalculation == nil {
            await calculateInvestmentOrder()
        }

        do {
            let result = try await placementService.placeOrder(
                searchResult: self.searchResult,
                quantity: Int(self.quantity),
                orderMode: self.orderMode,
                limit: self.limit,
                priceValidityProgress: self.priceValidityProgress,
                investmentOrderCalculation: self.investmentOrderCalculation,
                traderService: self.traderService
            )

            if result.success {
                // Order was successfully created and will appear in ongoing transactions
                // The status progression will happen automatically via the timer
                // Set status to idle to dismiss the view immediately
                self.orderStatus = .idle
                // Trigger navigation to depot view for successful order placement
                self.shouldShowDepotView = true
            } else if let error = result.error {
                self.orderStatus = .failed(error)
            } else {
                self.orderStatus = .failed(.unknown("Unbekannter Fehler bei der Orderplatzierung."))
            }
        } catch is CancellationError {
            // If task gets cancelled (e.g. view lifecycle), avoid leaving UI in transmitting state.
            self.orderStatus = .idle
        } catch let appError as AppError {
            orderStatus = .failed(appError)
        } catch {
            self.orderStatus = .failed(error.toAppError())
        }
    }

    func resetOrderStatus() {
        self.orderStatus = .idle
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
