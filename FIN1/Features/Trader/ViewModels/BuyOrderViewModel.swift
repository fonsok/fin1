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
        let resolvedDataProvider = investmentDataProvider ?? BuyOrderInvestmentDataProvider(
            investmentService: investmentService,
            traderDataService: traderDataService
        )
        self.investmentDataProvider = resolvedDataProvider
        let resolvedInvestmentAPIService = parseAPIClient.map { InvestmentAPIService(apiClient: $0) }

        // Create placement service with audit logging and transaction limits if not provided
        if let providedService = placementService {
            self.placementService = providedService
        } else if let auditService = auditLoggingService {
            self.placementService = BuyOrderPlacementService(
                auditLoggingService: auditService,
                userService: userService,
                transactionLimitService: transactionLimitService,
                parseAPIClient: parseAPIClient,
                investmentAPIService: resolvedInvestmentAPIService,
                investmentService: investmentService,
                investmentDataProvider: resolvedDataProvider
            )
        } else {
            // Fallback: Create without audit logging (for backward compatibility)
            // This should not happen in production - audit logging should always be provided
            self.placementService = BuyOrderPlacementService(
                auditLoggingService: AuditLoggingService(),
                userService: userService,
                transactionLimitService: transactionLimitService,
                parseAPIClient: parseAPIClient,
                investmentAPIService: resolvedInvestmentAPIService,
                investmentService: investmentService,
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
        guard self.placementSession.phase.isEditing else {
            print("🔍 DEBUG: placeOrder ignored - already placing")
            return
        }

        self.normalizeQuantityTextAfterEditing()
        let orderQuantity = Int(self.quantity)
        guard orderQuantity > 0 else {
            self.mutatePlacementSession { $0.completeFailure(.validationError("Ungültige Stückzahl.")) }
            return
        }

        self.pausePriceValidityTimer()

        let clientOrderIntentId = self.mutatePlacementSessionReturning {
            $0.ensureClientOrderIntentId()
        }
        let snapshot = BuyOrderPlacementSnapshot(
            quantity: orderQuantity,
            searchResult: self.searchResult,
            orderMode: self.orderMode,
            limit: self.limit,
            priceValidityProgress: self.priceValidityProgress,
            investmentOrderCalculation: self.investmentOrderCalculation,
            clientOrderIntentId: clientOrderIntentId
        )
        self.mutatePlacementSession { $0.beginPlacing(snapshot) }

        await self.refreshPlacementPoolContext()

        let placementCalculation = self.investmentOrderCalculation ?? snapshot.investmentOrderCalculation

        do {
            let result = try await placementService.placeOrder(
                searchResult: snapshot.searchResult,
                quantity: snapshot.quantity,
                orderMode: snapshot.orderMode,
                limit: snapshot.limit,
                priceValidityProgress: snapshot.priceValidityProgress,
                investmentOrderCalculation: placementCalculation,
                clientOrderIntentId: snapshot.clientOrderIntentId,
                traderService: self.traderService
            )

            if result.success {
                self.mutatePlacementSession { $0.completeSuccess() }
                self.shouldShowDepotView = true
            } else if let error = result.error {
                self.mutatePlacementSession { $0.completeFailure(error) }
                self.resumePriceValidityAfterFailure()
            } else {
                self.mutatePlacementSession {
                    $0.completeFailure(.unknown("Unbekannter Fehler bei der Orderplatzierung."))
                }
                self.resumePriceValidityAfterFailure()
            }
        } catch is CancellationError {
            print("⚠️ BuyOrderViewModel: placeOrder cancelled — snapshot quantity \(snapshot.quantity)")
            self.mutatePlacementSession {
                $0.completeFailure(
                    .validationError(
                        "Die Übermittlung wurde unterbrochen. Bitte prüfen Sie das Depot und versuchen Sie es ggf. erneut."
                    )
                )
            }
            self.resumePriceValidityAfterFailure()
        } catch let appError as AppError {
            self.mutatePlacementSession { $0.completeFailure(appError) }
            self.resumePriceValidityAfterFailure()
        } catch {
            self.mutatePlacementSession { $0.completeFailure(error.toAppError()) }
            self.resumePriceValidityAfterFailure()
        }
    }

    func resetOrderStatus() {
        self.mutatePlacementSession { $0.resetToEditing() }
    }

    @discardableResult
    private func mutatePlacementSessionReturning<T>(_ body: (inout BuyOrderPlacementSession) -> T) -> T {
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
