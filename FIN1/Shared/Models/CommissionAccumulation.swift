import Foundation

// MARK: - Commission Accumulation Model

/// Represents accumulated commission for a specific investor from a specific trade
struct CommissionAccumulation: Identifiable, Codable, Hashable {
    let id: String
    let investorId: String
    let traderId: String
    let tradeId: String
    let tradeNumber: Int
    let commissionAmount: Double
    let grossProfit: Double
    let createdAt: Date
    let settledAt: Date?
    let settlementId: String? // Links to the settlement batch that processed this commission

    init(
        id: String = UUID().uuidString,
        investorId: String,
        traderId: String,
        tradeId: String,
        tradeNumber: Int,
        commissionAmount: Double,
        grossProfit: Double,
        createdAt: Date = Date(),
        settledAt: Date? = nil,
        settlementId: String? = nil
    ) {
        self.id = id
        self.investorId = investorId
        self.traderId = traderId
        self.tradeId = tradeId
        self.tradeNumber = tradeNumber
        self.commissionAmount = commissionAmount
        self.grossProfit = grossProfit
        self.createdAt = createdAt
        self.settledAt = settledAt
        self.settlementId = settlementId
    }

    var isSettled: Bool {
        return self.settledAt != nil && self.settlementId != nil
    }
}

// MARK: - Commission Settlement Summary

/// Represents a batch settlement of accumulated commissions for a trader
struct CommissionSettlement: Identifiable, Codable {
    let id: String
    let traderId: String
    let totalCommissionAmount: Double
    let commissionCount: Int
    let tradeIds: [String]
    let tradeNumbers: [Int]
    let investorIds: Set<String>
    let createdAt: Date
    let creditNoteId: String? // Links to the credit note document

    init(
        id: String = UUID().uuidString,
        traderId: String,
        totalCommissionAmount: Double,
        commissionCount: Int,
        tradeIds: [String],
        tradeNumbers: [Int],
        investorIds: Set<String>,
        createdAt: Date = Date(),
        creditNoteId: String? = nil
    ) {
        self.id = id
        self.traderId = traderId
        self.totalCommissionAmount = totalCommissionAmount
        self.commissionCount = commissionCount
        self.tradeIds = tradeIds
        self.tradeNumbers = tradeNumbers
        self.investorIds = investorIds
        self.createdAt = createdAt
        self.creditNoteId = creditNoteId
    }
}











