import Foundation

// MARK: - Rounding Differences Models
struct RoundingDifference: Identifiable, Codable, Equatable {
    let id: UUID
    let transactionId: String
    let originalAmount: Double
    let roundedAmount: Double
    let difference: Double
    let transactionType: RoundingTransactionType
    let createdAt: Date
    var isReconciled: Bool
}

enum RoundingTransactionType: String, Codable, CaseIterable, Equatable {
    case tradeProfit = "trade_profit"
    case taxCalculation = "tax_calculation"
    case feeCalculation = "fee_calculation"
    case invoiceTotal = "invoice_total"
    case accountBalance = "account_balance"
}
