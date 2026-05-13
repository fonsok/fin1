import Combine
import Foundation

// MARK: - Cash Balance Service

/// Service for managing user cash balance with real-time updates
@MainActor
final class CashBalanceService: CashBalanceServiceProtocol, ObservableObject {

    // MARK: - Properties

    @Published private(set) var currentBalance: Double
    /// Last known admin-configured initial balance; used to sync `currentBalance` when it still matches that baseline.
    private var baselineInitialFromConfig: Double
    private let configurationService: any ConfigurationServiceProtocol
    private let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private let userService: (any UserServiceProtocol)?
    private let queue = DispatchQueue(label: "com.fin.app.cashbalance", attributes: .concurrent)
    private var liveQuerySubscription: LiveQuerySubscription?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        configurationService: any ConfigurationServiceProtocol,
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil
    ) {
        self.configurationService = configurationService
        self.parseLiveQueryClient = parseLiveQueryClient
        self.userService = userService
        let initial = configurationService.initialAccountBalance
        self.currentBalance = initial
        self.baselineInitialFromConfig = initial
        self.setupConfigurationObservation()
        self.setupLiveQuerySubscription()
    }

    // MARK: - ServiceLifecycle

    func start() async {
        // Initialize with starting balance
        let initial = self.configurationService.initialAccountBalance
        self.currentBalance = initial
        self.baselineInitialFromConfig = initial
        print("💰 CashBalanceService started with balance: €\(self.formattedBalance)")

        // Subscribe to Live Query updates
        await self.subscribeToLiveUpdates()
    }

    func stop() async {
        // Unsubscribe from Live Query
        if let subscription = liveQuerySubscription {
            self.parseLiveQueryClient?.unsubscribe(subscription)
            self.liveQuerySubscription = nil
        }
        print("💰 CashBalanceService stopped")
    }

    func reset() async {
        let initial = self.configurationService.initialAccountBalance
        self.currentBalance = initial
        self.baselineInitialFromConfig = initial
        print("💰 CashBalanceService reset to initial balance: €\(self.formattedBalance)")
    }

    // MARK: - Public Methods

    var formattedBalance: String {
        self.currentBalance.formatted(.currency(code: "EUR"))
    }

    func processBuyOrderExecution(amount: Double) async {
        await MainActor.run {
            self.currentBalance -= amount
        }
        print("💰 Buy order executed: -€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(self.formattedBalance)")
    }

    func processSellOrderExecution(amount: Double) async {
        await MainActor.run {
            self.currentBalance += amount
        }
        print("💰 Sell order executed: +€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(self.formattedBalance)")
    }

    func processGutschrift(amount: Double) async {
        await MainActor.run {
            self.currentBalance += amount
        }
        print("💰 Gutschrift processed: +€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(self.formattedBalance)")
    }

    func processWithdrawal(amount: Double) async {
        await MainActor.run {
            self.currentBalance -= amount
        }
        print("💰 Withdrawal processed: -€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(self.formattedBalance)")
    }

    func resetToInitialBalance() async {
        await MainActor.run {
            let initial = self.configurationService.initialAccountBalance
            self.currentBalance = initial
            self.baselineInitialFromConfig = initial
        }
        print("💰 Cash balance reset to initial: €\(self.formattedBalance)")
    }

    // MARK: - Validation Methods

    /// Calculates estimated balance after a purchase
    func estimatedBalanceAfterPurchase(amount: Double) -> Double {
        return self.currentBalance - amount
    }

    /// Checks if there are sufficient funds for a purchase with minimum reserve
    func hasSufficientFunds(for amount: Double, minimumReserve: Double? = nil) -> Bool {
        let estimatedBalance = self.estimatedBalanceAfterPurchase(amount: amount)
        let effectiveMinimumReserve = minimumReserve ?? self.configurationService.minimumCashReserve
        let hasSufficientFunds = estimatedBalance >= effectiveMinimumReserve

        print(
            "💰 Cash balance validation - Current: €\(self.formattedBalance), Purchase: €\(amount.formatted(.currency(code: "EUR"))), Estimated: €\(estimatedBalance.formatted(.currency(code: "EUR"))), Minimum: €\(effectiveMinimumReserve.formatted(.currency(code: "EUR"))), Sufficient: \(hasSufficientFunds)"
        )

        return hasSufficientFunds
    }

    // MARK: - Private Methods

    private func setupConfigurationObservation() {
        self.configurationService.configurationChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let serverValue = self.configurationService.initialAccountBalance
                    guard serverValue != self.baselineInitialFromConfig else { return }
                    if self.currentBalance == self.baselineInitialFromConfig {
                        self.currentBalance = serverValue
                        print("💰 CashBalanceService: balance synced to admin initial €\(serverValue.formatted(.currency(code: "EUR")))")
                    }
                    self.baselineInitialFromConfig = serverValue
                }
            }
            .store(in: &self.cancellables)
    }

    private func setupLiveQuerySubscription() {
        // Observe Parse Live Query updates for Wallet Transactions
        NotificationCenter.default.publisher(for: .parseLiveQueryObjectUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let className = userInfo["className"] as? String,
                      className == "WalletTransaction",
                      let object = userInfo["object"] as? [String: Any],
                      let userId = object["userId"] as? String,
                      userId == self.userService?.currentUser?.id,
                      let balanceAfter = object["balanceAfter"] as? Double else {
                    return
                }

                // Update balance from WalletTransaction balanceAfter
                Task { @MainActor in
                    self.currentBalance = balanceAfter
                    print("💰 CashBalanceService: Balance updated via Live Query: €\(self.formattedBalance)")
                }
            }
            .store(in: &self.cancellables)
    }

    private func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient,
              let userId = userService?.currentUser?.id else {
            return
        }

        // Subscribe to WalletTransaction updates for current user
        self.liveQuerySubscription = liveQueryClient.subscribe(
            className: "WalletTransaction",
            query: ["userId": userId],
            onUpdate: { [weak self] (parseTransaction: ParseWalletTransaction) in
                Task { @MainActor in
                    // Update balance from transaction's balanceAfter if available
                    if let balanceAfter = parseTransaction.balanceAfter {
                        self?.currentBalance = balanceAfter
                        print("💰 CashBalanceService: Balance updated via Live Query: €\(balanceAfter.formatted(.currency(code: "EUR")))")
                    }
                }
            },
            onDelete: { (_ objectId: String) in
                // Balance might change if transaction is deleted, but we'll reload from server
                Task { @MainActor in
                    // Could reload balance from server here if needed
                }
            },
            onError: { error in
                print("⚠️ Live Query error for WalletTransaction in CashBalanceService: \(error.localizedDescription)")
            }
        )
    }
}
