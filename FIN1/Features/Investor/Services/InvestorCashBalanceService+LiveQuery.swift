import Foundation
import Combine

@MainActor
extension InvestorCashBalanceService {
    /// Re-sync initialInvestorBalance when the config service loads server values.
    func observeConfigChanges() {
        configurationService.configurationChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    let serverValue = self.configurationService.initialAccountBalance
                    guard serverValue != self.initialInvestorBalance else { return }
                    self.initialInvestorBalance = serverValue
                    print("💰 InvestorCashBalanceService: initial balance updated to €\(serverValue.formatted(.currency(code: "EUR")))")
                    NotificationCenter.default.post(name: .investorBalanceDidChange, object: nil)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Live Query Integration

    func setupLiveQuerySubscription() {
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

                Task { @MainActor in
                    if self.balances.keys.contains(userId) {
                        self.balances[userId] = balanceAfter
                        print("💰 InvestorCashBalanceService: Balance updated via Live Query for investor \(userId): €\(balanceAfter.formatted(.currency(code: "EUR")))")
                        NotificationCenter.default.post(
                            name: .investorBalanceDidChange,
                            object: nil,
                            userInfo: ["investorId": userId, "newBalance": balanceAfter]
                        )
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .investorCashBalanceLiveQueryUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self,
                      let userInfo = notification.userInfo,
                      let investorId = userInfo["investorId"] as? String,
                      let balanceAfter = userInfo["newBalance"] as? Double else {
                    return
                }
                self.balances[investorId] = balanceAfter
                print("💰 InvestorCashBalanceService: Balance updated via Live Query for investor \(investorId): €\(balanceAfter.formatted(.currency(code: "EUR")))")
                NotificationCenter.default.post(
                    name: .investorBalanceDidChange,
                    object: nil,
                    userInfo: ["investorId": investorId, "newBalance": balanceAfter]
                )
            }
            .store(in: &cancellables)
    }

    func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient else { return }
        if let currentUserId = userService?.currentUser?.id,
           userService?.currentUser?.role == .investor {
            await subscribeToLiveUpdates(for: currentUserId, liveQueryClient: liveQueryClient)
        }
    }

    /// Subscribe to Live Query updates for a specific investor.
    func subscribeToLiveUpdates(for investorId: String) async {
        guard let liveQueryClient = parseLiveQueryClient else { return }
        if let existingSubscription = liveQuerySubscriptions[investorId] {
            liveQueryClient.unsubscribe(existingSubscription)
        }
        await subscribeToLiveUpdates(for: investorId, liveQueryClient: liveQueryClient)
    }

    func subscribeToLiveUpdates(
        for investorId: String,
        liveQueryClient: any ParseLiveQueryClientProtocol
    ) async {
        let subscription = liveQueryClient.subscribe(
            className: "WalletTransaction",
            query: ["userId": investorId],
            onUpdate: { (parseTransaction: ParseWalletTransaction) in
                guard let balanceAfter = parseTransaction.balanceAfter else { return }
                NotificationCenter.default.post(
                    name: .investorCashBalanceLiveQueryUpdate,
                    object: nil,
                    userInfo: ["investorId": investorId, "newBalance": balanceAfter]
                )
            },
            onDelete: { (_ objectId: String) in
                Task { @MainActor in
                    // Could reload balance from server here if needed.
                }
            },
            onError: { error in
                print("⚠️ Live Query error for WalletTransaction in InvestorCashBalanceService (investor \(investorId)): \(error.localizedDescription)")
            }
        )
        liveQuerySubscriptions[investorId] = subscription
        print("💰 InvestorCashBalanceService: Subscribed to Live Query for investor \(investorId)")
    }
}
