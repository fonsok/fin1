import Foundation

@MainActor
extension InvestorCashBalanceService {
    func configure(settlementAPIService: any SettlementAPIServiceProtocol) {
        self.settlementAPIService = settlementAPIService
    }

    /// Refreshes display balance from server customer timeline (`getAccountStatement` merge).
    func syncAuthoritativeBalance(for investorId: String) async {
        guard self.configurationService.investorMonetaryServerOnly,
              let settlementAPIService,
              let user = userService?.currentUser,
              user.id == investorId else {
            return
        }

        guard let balance = await InvestorCustomerClosingBalanceResolver.fetchClosingBalance(
            settlementAPIService: settlementAPIService
        ) else {
            return
        }

        self.applyAuthoritativeBalance(balance, for: investorId)
        NotificationCenter.default.post(
            name: .investorBalanceDidChange,
            object: nil,
            userInfo: ["investorId": investorId, "newBalance": balance]
        )
    }

    func applyAuthoritativeBalance(_ balance: Double, for investorId: String) {
        self.queue.sync(flags: .barrier) {
            self.authoritativeBalances[investorId] = balance
            self.balances[investorId] = balance
        }
        print(
            "💰 InvestorCashBalanceService: authoritative balance €\(balance.formatted(.currency(code: "EUR"))) for \(investorId)"
        )
    }
}
