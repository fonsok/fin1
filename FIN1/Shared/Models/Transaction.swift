import Foundation

// MARK: - Transaction Model
/// Represents a wallet transaction (deposit, withdrawal, trade-related, profit distribution)
struct Transaction: Identifiable, Codable, Hashable {

    // MARK: - Transaction Type

    enum TransactionType: String, Codable, CaseIterable {
        case deposit = "deposit"
        case withdrawal = "withdrawal"
        case tradeBuy = "trade_buy"
        case tradeSell = "trade_sell"
        case profitDistribution = "profit_distribution"
        case commission = "commission"
        case adjustment = "adjustment"
        case other = "other"

        var displayName: String {
            switch self {
            case .deposit: return "Einzahlung"
            case .withdrawal: return "Auszahlung"
            case .tradeBuy: return "Kauf"
            case .tradeSell: return "Verkauf"
            case .profitDistribution: return "Gewinnausschüttung"
            case .commission: return "Provision"
            case .adjustment: return "Korrektur"
            case .other: return "Sonstiges"
            }
        }

        var icon: String {
            switch self {
            case .deposit: return "arrow.down.circle.fill"
            case .withdrawal: return "arrow.up.circle.fill"
            case .tradeBuy: return "arrow.down.square.fill"
            case .tradeSell: return "arrow.up.square.fill"
            case .profitDistribution: return "gift.fill"
            case .commission: return "percent"
            case .adjustment: return "arrow.triangle.2.circlepath"
            case .other: return "ellipsis.circle.fill"
            }
        }

        var color: String {
            switch self {
            case .deposit, .profitDistribution: return "green"
            case .withdrawal, .commission: return "red"
            case .tradeBuy: return "blue"
            case .tradeSell: return "orange"
            case .adjustment, .other: return "gray"
            }
        }
    }

    // MARK: - Transaction Status

    enum TransactionStatus: String, Codable {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"
        case cancelled = "cancelled"

        var displayName: String {
            switch self {
            case .pending: return "Ausstehend"
            case .processing: return "In Bearbeitung"
            case .completed: return "Abgeschlossen"
            case .failed: return "Fehlgeschlagen"
            case .cancelled: return "Storniert"
            }
        }
    }

    // MARK: - Properties

    let id: String
    let userId: String
    let type: TransactionType
    let amount: Double
    let currency: String
    let status: TransactionStatus
    let timestamp: Date
    let description: String?
    let reference: String? // External reference (e.g., order ID, trade ID)
    let metadata: [String: String]
    let balanceAfter: Double? // Balance after this transaction

    // MARK: - Initialization

    init(
        id: String = UUID().uuidString,
        userId: String,
        type: TransactionType,
        amount: Double,
        currency: String = "EUR",
        status: TransactionStatus = .completed,
        timestamp: Date = Date(),
        description: String? = nil,
        reference: String? = nil,
        metadata: [String: String] = [:],
        balanceAfter: Double? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.amount = amount
        self.currency = currency
        self.status = status
        self.timestamp = timestamp
        self.description = description
        self.reference = reference
        self.metadata = metadata
        self.balanceAfter = balanceAfter
    }

    // MARK: - Computed Properties

    var formattedAmount: String {
        amount.formatted(.currency(code: currency))
    }

    var signedAmount: Double {
        switch type {
        case .deposit, .profitDistribution, .tradeSell:
            return amount
        case .withdrawal, .tradeBuy, .commission:
            return -amount
        case .adjustment, .other:
            return amount // Can be positive or negative based on metadata
        }
    }

    var formattedSignedAmount: String {
        let signed = signedAmount
        if signed >= 0 {
            return "+\(signed.formatted(.currency(code: currency)))"
        } else {
            return signed.formatted(.currency(code: currency))
        }
    }

    var isPositive: Bool {
        signedAmount >= 0
    }
}

// MARK: - Transaction Extensions

extension Transaction {
    /// Creates a transaction from an AccountStatementEntry
    static func from(entry: AccountStatementEntry, userId: String) -> Transaction {
        let type: TransactionType
        switch entry.category {
        case .investment:
            type = entry.direction == .credit ? .deposit : .withdrawal
        case .walletDeposit:
            type = .deposit
        case .walletWithdrawal:
            type = .withdrawal
        case .profitDistribution:
            type = .profitDistribution
        case .commission, .serviceCharge:
            type = .commission
        case .tradeSettlement:
            type = entry.direction == .credit ? .tradeSell : .tradeBuy
        case .adjustment:
            type = .adjustment
        case .other, .remainingBalance:
            type = .other
        }

        return Transaction(
            id: entry.id.uuidString,
            userId: userId,
            type: type,
            amount: entry.amount,
            status: .completed,
            timestamp: entry.occurredAt,
            description: entry.title,
            reference: entry.reference,
            metadata: entry.metadata,
            balanceAfter: entry.balanceAfter
        )
    }
}
