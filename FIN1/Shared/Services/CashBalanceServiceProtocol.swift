import Foundation

// MARK: - Cash Balance Service Protocol

/// Protocol for managing user cash balance
protocol CashBalanceServiceProtocol: ServiceLifecycle {
    /// Current cash balance
    var currentBalance: Double { get }

    /// Formatted current balance
    var formattedBalance: String { get }

    /// Updates cash balance when a buy order is executed (decreases balance)
    func processBuyOrderExecution(amount: Double) async

    /// Updates cash balance when a sell order is executed (increases balance)
    func processSellOrderExecution(amount: Double) async

    /// Updates cash balance with Gutschrift amount (net after taxes)
    func processGutschrift(amount: Double) async

    /// Updates cash balance when a withdrawal is processed (decreases balance)
    func processWithdrawal(amount: Double) async

    /// Resets cash balance to initial amount
    func resetToInitialBalance() async

    /// Calculates estimated balance after a purchase
    func estimatedBalanceAfterPurchase(amount: Double) -> Double

    /// Checks if there are sufficient funds for a purchase with minimum reserve
    func hasSufficientFunds(for amount: Double, minimumReserve: Double?) -> Bool
}
