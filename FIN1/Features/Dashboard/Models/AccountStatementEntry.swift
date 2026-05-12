import Foundation

// MARK: - Account Statement Entry
/// Represents a single entry in an account statement (credit or debit)
struct AccountStatementEntry: Identifiable, Hashable {

    // MARK: - Nested Types

    enum Direction: String, Hashable {
        case debit
        case credit

        var multiplier: Double {
            self == .credit ? 1 : -1
        }
    }

    enum Category: String, Hashable {
        case investment
        case serviceCharge
        case profitDistribution
        case remainingBalance
        case tradeSettlement
        case commission
        case adjustment
        case walletDeposit
        case walletWithdrawal
        case other
    }

    // MARK: - Properties

    let id: UUID
    let title: String
    let subtitle: String?
    let occurredAt: Date
    let amount: Double
    let direction: Direction
    let category: Category
    let reference: String?
    let referenceDocumentId: String?
    let referenceDocumentNumber: String?
    let metadata: [String: String]
    let balanceAfter: Double?
    let valueDate: Date?

    // MARK: - Initialization

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        occurredAt: Date,
        amount: Double,
        direction: Direction,
        category: Category,
        reference: String? = nil,
        referenceDocumentId: String? = nil,
        referenceDocumentNumber: String? = nil,
        metadata: [String: String] = [:],
        balanceAfter: Double? = nil,
        valueDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.occurredAt = occurredAt
        self.amount = amount
        self.direction = direction
        self.category = category
        self.reference = reference
        self.referenceDocumentId = referenceDocumentId
        self.referenceDocumentNumber = referenceDocumentNumber
        self.metadata = metadata
        self.balanceAfter = balanceAfter
        self.valueDate = valueDate
    }

    // MARK: - Computed Properties

    var signedAmount: Double {
        amount * direction.multiplier
    }

    var postingDate: Date { occurredAt }

    var valueDateOrPosting: Date { valueDate ?? occurredAt }

    var hasDocumentReference: Bool {
        let hasDirectId = !(referenceDocumentId ?? "").isEmpty
        let hasDirectNumber = !(referenceDocumentNumber ?? "").isEmpty
        let hasMetadataId = !(metadata["referenceDocumentId"] ?? "").isEmpty
        let hasMetadataNumber = !(metadata["referenceDocumentNumber"] ?? "").isEmpty
        return hasDirectId || hasDirectNumber || hasMetadataId || hasMetadataNumber
    }
}

// MARK: - AccountStatementEntry Extensions

extension AccountStatementEntry {
    /// Creates an AccountStatementEntry from a Wallet Transaction
    static func from(transaction: Transaction) -> AccountStatementEntry {
        let direction: Direction
        let category: Category

        switch transaction.type {
        case .deposit:
            direction = .credit
            category = .walletDeposit
        case .withdrawal:
            direction = .debit
            category = .walletWithdrawal
        case .profitDistribution:
            direction = .credit
            category = .profitDistribution
        case .commission:
            direction = .debit
            category = .commission
        case .tradeBuy:
            direction = .debit
            category = .tradeSettlement
        case .tradeSell:
            direction = .credit
            category = .tradeSettlement
        case .adjustment:
            direction = transaction.signedAmount >= 0 ? .credit : .debit
            category = .adjustment
        case .other:
            direction = transaction.signedAmount >= 0 ? .credit : .debit
            category = .other
        }

        return AccountStatementEntry(
            id: UUID(uuidString: transaction.id) ?? UUID(),
            title: transaction.description ?? transaction.type.displayName,
            subtitle: transaction.status.displayName,
            occurredAt: transaction.timestamp,
            amount: transaction.amount,
            direction: direction,
            category: category,
            reference: transaction.reference,
            referenceDocumentId: nil,
            referenceDocumentNumber: nil,
            metadata: transaction.metadata,
            balanceAfter: transaction.balanceAfter,
            valueDate: transaction.timestamp
        )
    }
}

// Transaction.TransactionStatus.displayName is already defined in Transaction.swift

// MARK: - Range Selection

enum AccountStatementRange: String, CaseIterable, Identifiable {
    case lastMonth
    case lastThreeMonths

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lastMonth: return "Last 30 Days"
        case .lastThreeMonths: return "Last 90 Days"
        }
    }

    func startDate(referenceDate: Date = Date()) -> Date {
        let calendar = Calendar.current
        switch self {
        case .lastMonth:
            return calendar.date(byAdding: .day, value: -30, to: referenceDate) ?? referenceDate
        case .lastThreeMonths:
            return calendar.date(byAdding: .month, value: -3, to: referenceDate) ?? referenceDate
        }
    }
}











