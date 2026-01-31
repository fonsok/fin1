import Foundation
import Combine

// MARK: - Trader Cash Balance Service Protocol

/// Protocol for managing trader cash balances and commission payments
protocol TraderCashBalanceServiceProtocol: ServiceLifecycle {
    /// Gets the current cash balance for a trader
    /// - Parameter traderId: The trader's user ID
    /// - Returns: Current cash balance in EUR
    func getBalance(for traderId: String) -> Double

    /// Gets formatted balance string for a trader
    /// - Parameter traderId: The trader's user ID
    /// - Returns: Formatted balance string (e.g., "€50,000.00")
    func getFormattedBalance(for traderId: String) -> String

    /// Processes commission payment to trader (adds commission to trader balance)
    /// - Parameters:
    ///   - traderId: The trader's user ID
    ///   - commissionAmount: Commission amount to add
    ///   - tradeId: The trade ID for accounting linkage
    func processCommissionPayment(traderId: String, commissionAmount: Double, tradeId: String) async

    /// Gets total commission earned by trader
    /// - Parameter traderId: The trader's user ID
    /// - Returns: Total commission earned
    func getTotalCommissionEarned(traderId: String) -> Double
}

// MARK: - Trader Cash Balance Service Implementation

/// Service for managing trader cash balances with commission tracking
final class TraderCashBalanceService: TraderCashBalanceServiceProtocol, ObservableObject {

    // MARK: - Properties

    /// Dictionary to store balances per trader (traderId -> balance)
    @Published private var balances: [String: Double] = [:]

    /// Dictionary to store commission records per trader (traderId -> [commission amounts])
    @Published private var commissionRecords: [String: [Double]] = [:]

    private let configurationService: any ConfigurationServiceProtocol
    private let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private let userService: (any UserServiceProtocol)?
    private let initialTraderBalance: Double
    private let queue = DispatchQueue(label: "com.fin.app.tradercashbalance", attributes: .concurrent)
    private var liveQuerySubscriptions: [String: LiveQuerySubscription] = [:] // traderId -> subscription
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
        // Traders start with initial balance (e.g., €50,000)
        self.initialTraderBalance = configurationService.initialAccountBalance
        setupLiveQuerySubscription()
    }

    // MARK: - ServiceLifecycle

    func start() async {
        print("💰 TraderCashBalanceService started with initial balance: €\(initialTraderBalance.formatted(.currency(code: "EUR")))")
        
        // Subscribe to Live Query updates for current trader
        await subscribeToLiveUpdates()
    }

    func stop() async {
        // Unsubscribe from all Live Query subscriptions
        for (traderId, subscription) in liveQuerySubscriptions {
            parseLiveQueryClient?.unsubscribe(subscription)
            print("💰 TraderCashBalanceService: Unsubscribed from Live Query for trader \(traderId)")
        }
        liveQuerySubscriptions.removeAll()
        print("💰 TraderCashBalanceService stopped")
    }

    func reset() async {
        // Unsubscribe from all Live Query subscriptions
        for (_, subscription) in liveQuerySubscriptions {
            parseLiveQueryClient?.unsubscribe(subscription)
        }
        liveQuerySubscriptions.removeAll()
        
        await MainActor.run {
            balances.removeAll()
            commissionRecords.removeAll()
        }
        print("💰 TraderCashBalanceService reset - all balances and commission records cleared")
    }
    
    // MARK: - Live Query Integration
    
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
                      let balanceAfter = object["balanceAfter"] as? Double else {
                    return
                }
                
                // Check if this user is a trader
                // Update balance if this trader is being tracked
                Task { @MainActor in
                    if self.balances.keys.contains(userId) {
                        self.balances[userId] = balanceAfter
                        print("💰 TraderCashBalanceService: Balance updated via Live Query for trader \(userId): €\(balanceAfter.formatted(.currency(code: "EUR")))")
                        
                        // Post notification to update UI
                        // Note: Using walletTransactionCompleted as trader balance changes are typically from wallet transactions
                        NotificationCenter.default.post(
                            name: .walletTransactionCompleted,
                            object: nil,
                            userInfo: [
                                "userId": userId,
                                "newBalance": balanceAfter
                            ]
                        )
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient else {
            return
        }
        
        // Subscribe to WalletTransaction updates for current trader (if logged in as trader)
        if let currentUserId = userService?.currentUser?.id,
           userService?.currentUser?.role == .trader {
            await subscribeToLiveUpdates(for: currentUserId, liveQueryClient: liveQueryClient)
        }
    }
    
    /// Subscribe to Live Query updates for a specific trader
    func subscribeToLiveUpdates(for traderId: String) async {
        guard let liveQueryClient = parseLiveQueryClient else {
            return
        }
        
        // Unsubscribe from previous subscription if exists
        if let existingSubscription = liveQuerySubscriptions[traderId] {
            liveQueryClient.unsubscribe(existingSubscription)
        }
        
        await subscribeToLiveUpdates(for: traderId, liveQueryClient: liveQueryClient)
    }
    
    private func subscribeToLiveUpdates(for traderId: String, liveQueryClient: any ParseLiveQueryClientProtocol) async {
        // Subscribe to WalletTransaction updates for this trader
        let subscription = liveQueryClient.subscribe(
            className: "WalletTransaction",
            query: ["userId": traderId],
            onUpdate: { [weak self] (parseTransaction: ParseWalletTransaction) in
                Task { @MainActor in
                    // Update balance from transaction's balanceAfter if available
                    if let balanceAfter = parseTransaction.balanceAfter {
                        self?.balances[traderId] = balanceAfter
                        print("💰 TraderCashBalanceService: Balance updated via Live Query for trader \(traderId): €\(balanceAfter.formatted(.currency(code: "EUR")))")
                        
                        // Post notification to update UI
                        // Note: Using walletTransactionCompleted as trader balance changes are typically from wallet transactions
                        NotificationCenter.default.post(
                            name: .walletTransactionCompleted,
                            object: nil,
                            userInfo: [
                                "userId": traderId,
                                "newBalance": balanceAfter
                            ]
                        )
                    }
                }
            },
            onDelete: { [weak self] (_ objectId: String) in
                // Balance might change if transaction is deleted, but we'll reload from server
                Task { @MainActor in
                    // Could reload balance from server here if needed
                }
            },
            onError: { error in
                print("⚠️ Live Query error for WalletTransaction in TraderCashBalanceService (trader \(traderId)): \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions[traderId] = subscription
        print("💰 TraderCashBalanceService: Subscribed to Live Query for trader \(traderId)")
    }

    // MARK: - Public Methods

    func getBalance(for traderId: String) -> Double {
        return queue.sync {
            return balances[traderId] ?? initialTraderBalance
        }
    }

    func getFormattedBalance(for traderId: String) -> String {
        let balance = getBalance(for: traderId)
        return balance.formatted(.currency(code: "EUR"))
    }

    func processCommissionPayment(traderId: String, commissionAmount: Double, tradeId: String) async {
        guard commissionAmount > 0 else {
            print("💰 TraderCashBalanceService: Commission amount is 0 or negative, skipping payment")
            return
        }

        await MainActor.run {
            let currentBalance = balances[traderId] ?? initialTraderBalance
            let newBalance = currentBalance + commissionAmount
            balances[traderId] = newBalance

            // Track commission record
            if commissionRecords[traderId] == nil {
                commissionRecords[traderId] = []
            }
            commissionRecords[traderId]?.append(commissionAmount)

            // Post notification to update UI
            NotificationCenter.default.post(
                name: .traderBalanceDidChange,
                object: nil,
                userInfo: ["traderId": traderId, "newBalance": newBalance]
            )
        }

        let newBalance = getBalance(for: traderId)
        print("💰 TraderCashBalanceService: Commission payment processed")
        print("   👤 Trader ID: \(traderId)")
        print("   📊 Trade ID: \(tradeId)")
        print("   💰 Commission: +€\(commissionAmount.formatted(.currency(code: "EUR")))")
        print("   💵 New Balance: €\(newBalance.formatted(.currency(code: "EUR")))")
    }

    func getTotalCommissionEarned(traderId: String) -> Double {
        return queue.sync {
            return commissionRecords[traderId]?.reduce(0.0, +) ?? 0.0
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let traderBalanceDidChange = Notification.Name("traderBalanceDidChange")
}
