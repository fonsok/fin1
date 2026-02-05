import Foundation
import Combine

// MARK: - Cash Balance Service

/// Service for managing user cash balance with real-time updates
final class CashBalanceService: CashBalanceServiceProtocol, ObservableObject {

    // MARK: - Properties

    @Published private(set) var currentBalance: Double
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
        self.currentBalance = configurationService.initialAccountBalance
        setupConfigurationObservation()
        setupLiveQuerySubscription()
    }

    // MARK: - ServiceLifecycle

    func start() async {
        // Initialize with starting balance
        currentBalance = configurationService.initialAccountBalance
        print("💰 CashBalanceService started with balance: €\(formattedBalance)")

        // Subscribe to Live Query updates
        await subscribeToLiveUpdates()
    }

    func stop() async {
        // Unsubscribe from Live Query
        if let subscription = liveQuerySubscription {
            parseLiveQueryClient?.unsubscribe(subscription)
            liveQuerySubscription = nil
        }
        print("💰 CashBalanceService stopped")
    }

    func reset() async {
        currentBalance = configurationService.initialAccountBalance
        print("💰 CashBalanceService reset to initial balance: €\(formattedBalance)")
    }

    // MARK: - Public Methods

    var formattedBalance: String {
        currentBalance.formatted(.currency(code: "EUR"))
    }

    func processBuyOrderExecution(amount: Double) async {
        await MainActor.run {
            currentBalance -= amount
        }
        print("💰 Buy order executed: -€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(formattedBalance)")
    }

    func processSellOrderExecution(amount: Double) async {
        await MainActor.run {
            currentBalance += amount
        }
        print("💰 Sell order executed: +€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(formattedBalance)")
    }

    func processGutschrift(amount: Double) async {
        await MainActor.run {
            currentBalance += amount
        }
        print("💰 Gutschrift processed: +€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(formattedBalance)")
    }

    func processWithdrawal(amount: Double) async {
        await MainActor.run {
            currentBalance -= amount
        }
        print("💰 Withdrawal processed: -€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(formattedBalance)")
    }

    func resetToInitialBalance() async {
        await MainActor.run {
            currentBalance = configurationService.initialAccountBalance
        }
        print("💰 Cash balance reset to initial: €\(formattedBalance)")
    }

    // MARK: - Validation Methods

    /// Calculates estimated balance after a purchase
    func estimatedBalanceAfterPurchase(amount: Double) -> Double {
        return currentBalance - amount
    }

    /// Checks if there are sufficient funds for a purchase with minimum reserve
    func hasSufficientFunds(for amount: Double, minimumReserve: Double? = nil) -> Bool {
        let estimatedBalance = estimatedBalanceAfterPurchase(amount: amount)
        let effectiveMinimumReserve = minimumReserve ?? configurationService.minimumCashReserve
        let hasSufficientFunds = estimatedBalance >= effectiveMinimumReserve

        print("💰 Cash balance validation - Current: €\(formattedBalance), Purchase: €\(amount.formatted(.currency(code: "EUR"))), Estimated: €\(estimatedBalance.formatted(.currency(code: "EUR"))), Minimum: €\(effectiveMinimumReserve.formatted(.currency(code: "EUR"))), Sufficient: \(hasSufficientFunds)")

        return hasSufficientFunds
    }

    // MARK: - Private Methods

    private func setupConfigurationObservation() {
        // Observe configuration changes to update initial balance if needed
        // Note: We can't observe @Published properties from protocols directly
        // This would need to be implemented differently in a real app
        // For now, we'll rely on the service being restarted when configuration changes
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
            .store(in: &cancellables)
    }

    private func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient,
              let userId = userService?.currentUser?.id else {
            return
        }

        // Subscribe to WalletTransaction updates for current user
        liveQuerySubscription = liveQueryClient.subscribe(
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
