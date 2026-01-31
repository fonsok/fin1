import Foundation

// MARK: - Parse Wallet Transaction Model
/// Parse Server model for persisting wallet transactions
struct ParseWalletTransaction: Codable {
    let objectId: String?
    let userId: String
    let type: String // Transaction.TransactionType rawValue
    let amount: Double
    let currency: String
    let status: String // Transaction.TransactionStatus rawValue
    let timestamp: Date
    let description: String?
    let reference: String?
    let metadata: [String: String]
    let balanceAfter: Double?
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case objectId
        case userId
        case type
        case amount
        case currency
        case status
        case timestamp
        case description
        case reference
        case metadata
        case balanceAfter
        case createdAt
        case updatedAt
    }
    
    init(
        objectId: String? = nil,
        userId: String,
        type: String,
        amount: Double,
        currency: String = "EUR",
        status: String,
        timestamp: Date = Date(),
        description: String? = nil,
        reference: String? = nil,
        metadata: [String: String] = [:],
        balanceAfter: Double? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.objectId = objectId
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    func toTransaction() -> Transaction {
        Transaction(
            id: objectId ?? UUID().uuidString,
            userId: userId,
            type: Transaction.TransactionType(rawValue: type) ?? .other,
            amount: amount,
            currency: currency,
            status: Transaction.TransactionStatus(rawValue: status) ?? .completed,
            timestamp: timestamp,
            description: description,
            reference: reference,
            metadata: metadata,
            balanceAfter: balanceAfter
        )
    }
    
    static func from(_ transaction: Transaction) -> ParseWalletTransaction {
        ParseWalletTransaction(
            objectId: nil, // Will be set by Parse Server
            userId: transaction.userId,
            type: transaction.type.rawValue,
            amount: transaction.amount,
            currency: transaction.currency,
            status: transaction.status.rawValue,
            timestamp: transaction.timestamp,
            description: transaction.description,
            reference: transaction.reference,
            metadata: transaction.metadata,
            balanceAfter: transaction.balanceAfter
        )
    }
}
