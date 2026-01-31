import Foundation
import Combine

// MARK: - Investor Cash Balance Service

/// Service for managing investor cash balances with per-investor tracking
final class InvestorCashBalanceService: InvestorCashBalanceServiceProtocol, ObservableObject {

    // MARK: - Properties

    /// Dictionary to store balances per investor (investorId -> balance)
    @Published private var balances: [String: Double] = [:]
    /// Ledger service for transaction recording
    private let ledgerService: InvestorCashBalanceLedgerService
    private let configurationService: any ConfigurationServiceProtocol
    private let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    private let userService: (any UserServiceProtocol)?
    private let initialInvestorBalance: Double
    private let queue = DispatchQueue(label: "com.fin.app.investorcashbalance", attributes: .concurrent)
    private var liveQuerySubscriptions: [String: LiveQuerySubscription] = [:] // investorId -> subscription
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
        self.ledgerService = InvestorCashBalanceLedgerService()
        // Investors start with a different initial balance (e.g., €25,000)
        // This could be configurable in the future
        self.initialInvestorBalance = 25000.0
        setupLiveQuerySubscription()
    }

    // MARK: - ServiceLifecycle

    func start() {
        // Initialize balances for existing investors if needed
        print("💰 InvestorCashBalanceService started with initial balance: €\(initialInvestorBalance.formatted(.currency(code: "EUR")))")
        
        // Subscribe to Live Query updates for current investor
        Task {
            await subscribeToLiveUpdates()
        }
    }

    func stop() {
        // Unsubscribe from all Live Query subscriptions
        for (investorId, subscription) in liveQuerySubscriptions {
            parseLiveQueryClient?.unsubscribe(subscription)
            print("💰 InvestorCashBalanceService: Unsubscribed from Live Query for investor \(investorId)")
        }
        liveQuerySubscriptions.removeAll()
        print("💰 InvestorCashBalanceService stopped")
    }

    func reset() {
        Task {
            // Unsubscribe from all Live Query subscriptions
            for (_, subscription) in liveQuerySubscriptions {
                parseLiveQueryClient?.unsubscribe(subscription)
            }
            liveQuerySubscriptions.removeAll()
            
            await MainActor.run {
                balances.removeAll()
            }
            ledgerService.resetLedger()
            print("💰 InvestorCashBalanceService reset - all balances and ledger cleared")
        }
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
                
                // Check if this user is an investor
                // Update balance if this investor is being tracked
                Task { @MainActor in
                    if self.balances.keys.contains(userId) {
                        self.balances[userId] = balanceAfter
                        print("💰 InvestorCashBalanceService: Balance updated via Live Query for investor \(userId): €\(balanceAfter.formatted(.currency(code: "EUR")))")
                        
                        // Post notification to update UI
                        NotificationCenter.default.post(
                            name: .investorBalanceDidChange,
                            object: nil,
                            userInfo: [
                                "investorId": userId,
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
        
        // Subscribe to WalletTransaction updates for current investor (if logged in as investor)
        if let currentUserId = userService?.currentUser?.id,
           userService?.currentUser?.role == .investor {
            await subscribeToLiveUpdates(for: currentUserId, liveQueryClient: liveQueryClient)
        }
    }
    
    /// Subscribe to Live Query updates for a specific investor
    func subscribeToLiveUpdates(for investorId: String) async {
        guard let liveQueryClient = parseLiveQueryClient else {
            return
        }
        
        // Unsubscribe from previous subscription if exists
        if let existingSubscription = liveQuerySubscriptions[investorId] {
            liveQueryClient.unsubscribe(existingSubscription)
        }
        
        await subscribeToLiveUpdates(for: investorId, liveQueryClient: liveQueryClient)
    }
    
    private func subscribeToLiveUpdates(for investorId: String, liveQueryClient: any ParseLiveQueryClientProtocol) async {
        // Subscribe to WalletTransaction updates for this investor
        let subscription = liveQueryClient.subscribe(
            className: "WalletTransaction",
            query: ["userId": investorId],
            onUpdate: { [weak self] (parseTransaction: ParseWalletTransaction) in
                Task { @MainActor in
                    // Update balance from transaction's balanceAfter if available
                    if let balanceAfter = parseTransaction.balanceAfter {
                        self?.balances[investorId] = balanceAfter
                        print("💰 InvestorCashBalanceService: Balance updated via Live Query for investor \(investorId): €\(balanceAfter.formatted(.currency(code: "EUR")))")
                        
                        // Post notification to update UI
                        NotificationCenter.default.post(
                            name: .investorBalanceDidChange,
                            object: nil,
                            userInfo: [
                                "investorId": investorId,
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
                print("⚠️ Live Query error for WalletTransaction in InvestorCashBalanceService (investor \(investorId)): \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions[investorId] = subscription
        print("💰 InvestorCashBalanceService: Subscribed to Live Query for investor \(investorId)")
    }

    // MARK: - Public Methods

    func getBalance(for investorId: String) -> Double {
        return queue.sync {
            return balances[investorId] ?? initialInvestorBalance
        }
    }

    func getFormattedBalance(for investorId: String) -> String {
        let balance = getBalance(for: investorId)
        return balance.formatted(.currency(code: "EUR"))
    }

    func processInvestment(investorId: String, amount: Double, investmentId: String) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = max(0, currentBalance - amount)
            balances[investorId] = newBalance

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Investment Reserved",
                subtitle: "Investment \(investmentId)",
                amount: amount,
                direction: .debit,
                category: .investment,
                reference: investmentId,
                metadata: [
                    "investmentId": investmentId,
                    "transactionType": "investment"
                ],
                balanceAfter: newBalance
            )

            // Post notification to update UI with investment ID for accounting linkage
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: [
                    "investorId": investorId,
                    "newBalance": newBalance,
                    "investmentId": investmentId,
                    "transactionType": "investment"
                ]
            )
        }
        let newBalance = getBalance(for: investorId)
        print("💰 Investor \(investorId) - Investment [ID: \(investmentId)]: -€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))")
    }

    /// Processes platform service charge deduction (NON-REFUNDABLE creation charge)
    /// - Note: Currently charged to investors when creating investments (not traders).
    ///   It is charged when investment is created and is NOT refunded on cancellation.
    ///   To extend to traders: implement similar method in TraderCashBalanceService.
    func processPlatformServiceCharge(
        investorId: String,
        chargeAmount: Double,
        investmentId: String,
        metadata additionalMetadata: [String: String] = [:]
    ) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = max(0, currentBalance - chargeAmount)
            balances[investorId] = newBalance

            var metadata: [String: String] = [
                "investmentId": investmentId,
                "transactionType": "platformServiceCharge",
                "isRefundable": "false"
            ]
            additionalMetadata.forEach { metadata[$0.key] = $0.value }

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Platform Service Charge",
                subtitle: "Investment \(investmentId)",
                amount: chargeAmount,
                direction: .debit,
                category: .serviceCharge,
                reference: investmentId,
                metadata: metadata,
                balanceAfter: newBalance
            )

            // Post notification to update UI with investment ID for accounting linkage
            var userInfo: [String: Any] = [
                "investorId": investorId,
                "newBalance": newBalance,
                "investmentId": investmentId,
                "transactionType": "platformServiceCharge",
                "isRefundable": false // Platform service charge is non-refundable
            ]
            additionalMetadata.forEach { userInfo[$0.key] = $0.value }

            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: userInfo
            )
        }
        let newBalance = getBalance(for: investorId)
        print("💰 Investor \(investorId) - Platform Service Charge [Investment ID: \(investmentId), NON-REFUNDABLE]: -€\(chargeAmount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))")
    }

    func processProfitDistribution(investorId: String, profitAmount: Double, investmentId: String? = nil) async {
        await processProfitDistribution(
            investorId: investorId,
            profitAmount: profitAmount,
            investmentId: investmentId,
            principalReturn: nil,
            grossProfit: nil
        )
    }

    /// Processes profit distribution with optional calculation breakdown for display
    private func processProfitDistribution(
        investorId: String,
        profitAmount: Double,
        investmentId: String?,
        principalReturn: Double?,
        grossProfit: Double?
    ) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = currentBalance + profitAmount
            balances[investorId] = newBalance

            var metadata: [String: String] = [
                "transactionType": "profitDistribution"
            ]
            if let investmentId = investmentId {
                metadata["investmentId"] = investmentId
            }

            // Store calculation breakdown for testing/display purposes
            if let principalReturn = principalReturn {
                metadata["principalReturn"] = String(format: "%.2f", principalReturn)
            }
            if let grossProfit = grossProfit {
                metadata["grossProfit"] = String(format: "%.2f", grossProfit)
            }

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Profit Distribution",
                amount: profitAmount,
                direction: .credit,
                category: .profitDistribution,
                metadata: metadata,
                balanceAfter: newBalance
            )

            // Post notification to update UI
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        let investmentInfo = investmentId.map { " [Investment ID: \($0)]" } ?? ""
        print("💰 Investor \(investorId) - Profit distribution\(investmentInfo): +€\(profitAmount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))")
    }

    /// Processes profit distribution with calculation breakdown (for investment completion)
    func processProfitDistributionWithBreakdown(
        investorId: String,
        profitAmount: Double,
        principalReturn: Double,
        grossProfit: Double,
        investmentId: String? = nil
    ) async {
        await processProfitDistribution(
            investorId: investorId,
            profitAmount: profitAmount,
            investmentId: investmentId,
            principalReturn: principalReturn,
            grossProfit: grossProfit
        )
    }

    /// Processes commission deduction from investor's cash balance
    /// Records commission as a separate debit transaction for proper accounting transparency
    /// - Parameters:
    ///   - investorId: The investor's user ID
    ///   - commissionAmount: Commission amount to deduct
    ///   - investmentId: Optional investment ID to link this commission to a specific investment
    ///   - details: Optional additional details for accounting display
    func processCommissionDeduction(
        investorId: String,
        commissionAmount: Double,
        investmentId: String? = nil,
        details: CommissionDeductionDetails? = nil
    ) async {
        guard commissionAmount > 0 else {
            print("💰 InvestorCashBalanceService.processCommissionDeduction: Commission amount is 0 or negative, skipping")
            return
        }

        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = max(0, currentBalance - commissionAmount)
            balances[investorId] = newBalance

            var metadata: [String: String] = [
                "transactionType": "commissionDeduction"
            ]
            if let investmentId = investmentId {
                metadata["investmentId"] = investmentId
            }

            // Add detailed commission information for display
            if let details = details {
                if let seqNum = details.investmentSequenceNumber {
                    metadata["investmentSequenceNumber"] = String(seqNum)
                }
                if let traderName = details.traderName, !traderName.isEmpty {
                    metadata["traderName"] = traderName
                }
                if !details.tradeNumbers.isEmpty {
                    metadata["tradeNumbers"] = details.tradeNumbers.joined(separator: ", ")
                }
                metadata["grossProfit"] = String(format: "%.2f", details.grossProfit)
                metadata["commissionRate"] = String(format: "%.0f", details.commissionRate * 100)
            }

            // Build subtitle with investment and trade info
            var subtitleParts: [String] = []
            if let details = details, let seqNum = details.investmentSequenceNumber {
                subtitleParts.append("Investment #\(seqNum)")
            } else if let investmentId = investmentId {
                subtitleParts.append("Investment \(investmentId)")
            }
            if let details = details, !details.tradeNumbers.isEmpty {
                let tradeList = details.tradeNumbers.joined(separator: ", ")
                subtitleParts.append("Trade \(tradeList)")
            }
            let subtitle = subtitleParts.isEmpty ? nil : subtitleParts.joined(separator: " · ")

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Commission",
                subtitle: subtitle,
                amount: commissionAmount,
                direction: .debit,
                category: .commission,
                reference: investmentId,
                metadata: metadata,
                balanceAfter: newBalance
            )

            // Post notification to update UI
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        let investmentInfo = investmentId.map { " [Investment ID: \($0)]" } ?? ""
        print("💰 Investor \(investorId) - Commission deduction\(investmentInfo): -€\(commissionAmount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))")
    }

    /// Convenience method without details parameter (backward compatibility)
    func processCommissionDeduction(investorId: String, commissionAmount: Double, investmentId: String? = nil) async {
        await processCommissionDeduction(
            investorId: investorId,
            commissionAmount: commissionAmount,
            investmentId: investmentId,
            details: nil
        )
    }

    func processRemainingBalanceDistribution(investorId: String, amount: Double, investmentId: String? = nil) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = currentBalance + amount
            balances[investorId] = newBalance

            var metadata: [String: String] = [
                "transactionType": "remainingBalanceDistribution"
            ]
            if let investmentId = investmentId {
                metadata["investmentId"] = investmentId
            }

            ledgerService.recordTransaction(
                investorId: investorId,
                title: "Balance Distribution",
                amount: amount,
                direction: .credit,
                category: .remainingBalance,
                metadata: metadata,
                balanceAfter: newBalance
            )

            // Post notification to update UI
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        let investmentInfo = investmentId.map { " [Investment ID: \($0)]" } ?? ""
        print("💰 Investor \(investorId) - Remaining balance distribution\(investmentInfo): +€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))")
    }

    func hasSufficientFunds(investorId: String, for amount: Double) -> Bool {
        let currentBalance = getBalance(for: investorId)
        return currentBalance >= amount
    }

    func estimatedBalanceAfterInvestment(investorId: String, amount: Double) -> Double {
        let currentBalance = getBalance(for: investorId)
        return max(0, currentBalance - amount)
    }

    func resetBalance(for investorId: String) async {
        await MainActor.run {
            balances[investorId] = initialInvestorBalance
        }
        ledgerService.clearTransactions(for: investorId)
        print("💰 Investor \(investorId) - Balance reset to initial: €\(initialInvestorBalance.formatted(.currency(code: "EUR")))")
    }
    
    func processDeposit(investorId: String, amount: Double) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = currentBalance + amount
            balances[investorId] = newBalance
            
            // NOTE: Do NOT record wallet transactions in ledger
            // Wallet transactions are stored in PaymentService and loaded separately
            // Recording here would cause duplicates in Account Statement
            
            // Post notification to update UI
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        print("💰 Investor \(investorId) - Deposit: +€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))")
    }
    
    func processWithdrawal(investorId: String, amount: Double) async {
        await MainActor.run {
            let currentBalance = balances[investorId] ?? initialInvestorBalance
            let newBalance = max(0, currentBalance - amount)
            balances[investorId] = newBalance
            
            // NOTE: Do NOT record wallet transactions in ledger
            // Wallet transactions are stored in PaymentService and loaded separately
            // Recording here would cause duplicates in Account Statement
            
            // Post notification to update UI
            NotificationCenter.default.post(
                name: .investorBalanceDidChange,
                object: nil,
                userInfo: ["investorId": investorId, "newBalance": newBalance]
            )
        }
        let newBalance = getBalance(for: investorId)
        print("💰 Investor \(investorId) - Withdrawal: -€\(amount.formatted(.currency(code: "EUR"))) | New balance: €\(newBalance.formatted(.currency(code: "EUR")))")
    }

    func getTransactions(for investorId: String) -> [AccountStatementEntry] {
        return ledgerService.getLedgerEntries(for: investorId)
    }
}
