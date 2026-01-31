import Foundation
import Combine

enum BuyOrderStatus: Equatable {
    case idle
    case transmitting
    case orderPlaced(executedPrice: Double, finalCost: Double)
    case failed(AppError)
}

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
    private let quantityInputManager: QuantityInputManager
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

    private var cancellables = Set<AnyCancellable>()
    private let traderService: any TraderServiceProtocol
    private let cashBalanceService: any CashBalanceServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let investmentQuantityCalculationService: any InvestmentQuantityCalculationServiceProtocol
    private let investmentService: any InvestmentServiceProtocol
    private let userService: any UserServiceProtocol
    private let traderDataService: (any TraderDataServiceProtocol)?
    private let investmentCalculator: any BuyOrderInvestmentCalculatorProtocol
    private let validator: any BuyOrderValidatorProtocol
    private let placementService: any BuyOrderPlacementServiceProtocol
    private let investmentDataProvider: any BuyOrderInvestmentDataProviderProtocol
    private let transactionLimitService: (any TransactionLimitServiceProtocol)?
    
    // MARK: - Transaction Limit State
    @Published var transactionLimitCheckResult: TransactionLimitCheckResult?
    @Published var remainingDailyLimit: Double?
    @Published var showLimitWarning: Bool = false
    @Published var limitWarningMessage: String?

    // Helpers (extracted for file size reduction)
    private var quantityConstraintHelper: BuyOrderQuantityConstraintHelper {
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
        // Create placement service with audit logging and transaction limits if not provided
        if let providedService = placementService {
            self.placementService = providedService
        } else if let auditService = auditLoggingService {
            self.placementService = BuyOrderPlacementService(
                auditLoggingService: auditService,
                userService: userService,
                transactionLimitService: transactionLimitService
            )
        } else {
            // Fallback: Create without audit logging (for backward compatibility)
            // This should not happen in production - audit logging should always be provided
            self.placementService = BuyOrderPlacementService(
                auditLoggingService: AuditLoggingService(),
                userService: userService,
                transactionLimitService: transactionLimitService
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

        // Setup investment observation
        setupInvestmentObservation()

        // Calculate investment order when quantity or price changes
        Task {
            await calculateInvestmentOrder()
        }
    }

    // MARK: - Investment Calculation Methods

    @MainActor
    func calculateInvestmentOrder() async {
        // Extract price from SearchResult (German format: "2,98" -> 2.98)
        let price = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let desiredQuantity = Int(quantity)

        // Only calculate investment order for traders, not investors
        guard let currentUser = userService.currentUser,
              currentUser.role == .trader else {
            investmentOrderCalculation = nil
            showInvestmentCalculation = false
            return
        }

        guard let result = await investmentCalculator.calculateInvestmentOrder(
            quantity: desiredQuantity,
            price: price,
            searchResult: searchResult,
            userService: userService,
            investmentService: investmentService,
            cashBalanceService: cashBalanceService,
            investmentQuantityCalculationService: investmentQuantityCalculationService
        ) else {
            investmentOrderCalculation = nil
            showInvestmentCalculation = false
            return
        }

        await MainActor.run {
            investmentOrderCalculation = result.calculation
            isInvestmentLimited = result.isInvestmentLimited
            showInvestmentCalculation = result.showInvestmentCalculation
            // Update quantity to total maximized quantity (trader + investment)
            quantity = Double(result.calculation.totalQuantity)
        }
    }

    // MARK: - Private Setup Methods

    private func updateInsufficientFundsWarning() {
        guard let currentUser = userService.currentUser else {
            showInsufficientFundsWarning = false
            return
        }
        let minimumReserve = configurationService.getMinimumCashReserve(for: currentUser.id)
        let hasSufficientFunds = cashBalanceService.hasSufficientFunds(for: estimatedCost, minimumReserve: minimumReserve)
        showInsufficientFundsWarning = !hasSufficientFunds
    }
    
    // MARK: - Transaction Limit Checking
    
    @MainActor
    private func checkTransactionLimits() async {
        guard let limitService = transactionLimitService,
              let userId = userService.currentUser?.id,
              estimatedCost > 0 else {
            transactionLimitCheckResult = nil
            showLimitWarning = false
            limitWarningMessage = nil
            remainingDailyLimit = nil
            return
        }
        
        do {
            let checkResult = try await limitService.checkAllLimits(userId: userId, amount: estimatedCost)
            transactionLimitCheckResult = checkResult
            remainingDailyLimit = checkResult.remainingDaily
            
            if !checkResult.isAllowed {
                showLimitWarning = true
                limitWarningMessage = checkResult.errorMessage
            } else {
                showLimitWarning = false
                limitWarningMessage = nil
            }
        } catch {
            // If limit check fails, don't block the user - just log the error
            print("⚠️ Transaction limit check failed: \(error.localizedDescription)")
            transactionLimitCheckResult = nil
            showLimitWarning = false
            limitWarningMessage = nil
        }
    }

    private func setupBindings() {
        $quantityText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .map { [weak self] text -> (value: Double?, message: String?) in
                guard let self = self else { return (0.0, nil) }
                let processedValue = self.quantityInputManager.processQuantityText(text)
                return self.quantityConstraintHelper.evaluateQuantityConstraints(for: processedValue)
            }
            .handleEvents(receiveOutput: { [weak self] result in
                self?.quantityConstraintMessage = result.message
            })
            .compactMap { $0.value }
            .assign(to: \.quantity, on: self)
            .store(in: &cancellables)

        $quantityText
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self else { return }
                _ = self.quantityInputManager.processQuantityText(text)
                self.showMaxValueWarning = self.quantityInputManager.showMaxValueWarning
            }
            .store(in: &cancellables)

        $quantity
            .map { NumberFormatter.localizedIntegerFormatter.string(from: NSNumber(value: $0)) ?? "\(Int($0))" }
            .assign(to: \.quantityText, on: self)
            .store(in: &cancellables)

        Publishers.orderCalculation(
            quantityText: $quantityText.eraseToAnyPublisher(),
            orderMode: $orderMode.eraseToAnyPublisher(),
            limitText: $limit.eraseToAnyPublisher(),
            marketPrice: $searchResult.map {
                Double($0.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
            }.eraseToAnyPublisher(),
            isSellOrder: false
        )
        .assign(to: \.estimatedCost, on: self)
        .store(in: &cancellables)

        // Update insufficient funds warning when estimated cost changes
        $estimatedCost
            .sink { [weak self] _ in
                self?.updateInsufficientFundsWarning()
                Task { @MainActor [weak self] in
                    await self?.checkTransactionLimits()
                }
            }
            .store(in: &cancellables)

        // Recalculate investment order when quantity or price changes
        Publishers.CombineLatest($quantity, $searchResult)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _, _ in
                Task { @MainActor [weak self] in
                    await self?.calculateInvestmentOrder()
                }
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.removeAll()
        quantityInputManager.cleanup()
        priceValidityTimerManager.cleanup()
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

    @MainActor
    func placeOrder() async {
        orderStatus = .transmitting

        // Calculate investment order if not already calculated
        if investmentOrderCalculation == nil {
            await calculateInvestmentOrder()
        }

        let result = try? await placementService.placeOrder(
            searchResult: searchResult,
            quantity: Int(quantity),
            orderMode: orderMode,
            limit: limit,
            priceValidityProgress: priceValidityProgress,
            investmentOrderCalculation: investmentOrderCalculation,
            traderService: traderService,
            investmentCalculator: investmentCalculator
        )

        if let result = result {
            if result.success {
                // Order was successfully created and will appear in ongoing transactions
                // The status progression will happen automatically via the timer
                // Set status to idle to dismiss the view immediately
                orderStatus = .idle
                // Trigger navigation to depot view for successful order placement
                shouldShowDepotView = true
            } else if let error = result.error {
                orderStatus = .failed(error)
            }
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

    // MARK: - Pool/Investment Data for Display

    /// Total investment amount from all reserved investments
    var totalInvestmentAmount: Double {
        reservedInvestments.reduce(0.0) { $0 + $1.amount }
    }

    /// Updates the reserved investments list using the investment data provider
    /// Delegates complex fetching and filtering logic to BuyOrderInvestmentDataProvider
    private func updateReservedInvestments() {
        let currentUser = userService.currentUser
        let traderId = investmentDataProvider.findTraderIdForMatching(currentUser: currentUser)
        reservedInvestments = investmentDataProvider.fetchReservedInvestments(
            traderId: traderId,
            currentUser: currentUser
        )
    }

    /// Public method to refresh investments (called from view)
    func refreshInvestments() {
        updateReservedInvestments()
    }

    /// Total investment quantity calculated from total investment amount and ask price
    /// Applies denomination constraint (round down) but NOT subscriptionRatio for display purposes
    var totalInvestmentQuantity: Int {
        TotalInvestmentQuantityCalculator.calculate(
            investments: reservedInvestments,
            askPrice: searchResult.askPrice,
            denomination: searchResult.denomination
        )
    }

    // MARK: - Investment Observation

    private func setupInvestmentObservation() {
        // Observe investment changes from the service
        investmentService.investmentsPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateReservedInvestments()
            }
            .store(in: &cancellables)

        // Initial update and delayed updates to catch late-loading investments
        updateReservedInvestments()
        [0.1, 0.5, 1.0].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.updateReservedInvestments()
            }
        }
    }

    // MARK: - Limit Price Management

    /// Called when the user changes the limit price input
    func onLimitPriceChanged() {
        if isMonitoringLimitOrder {
            stopLimitOrderMonitoring()
        }
    }

}
