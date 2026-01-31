import Foundation

// MARK: - Core DTOs

public enum CKTransactionType: String, Codable {
    case buy
    case sell
}

public enum CKInvoiceType: String, Codable {
    case regular
    case creditNote
}

public enum CKInvoiceItemType: String, Codable {
    case securities
    case tax
    case orderFee
    case exchangeFee
    case foreignCosts
    case commission
}

public struct CKInvoiceItem: Codable {
    public let itemType: CKInvoiceItemType
    public let quantity: Double
    public let unitPrice: Double
    public let totalAmount: Double
    public let description: String
}

public struct CKInvoice: Codable {
    public let id: String
    public let tradeId: String?
    public let tradeNumber: Int?
    public let transactionType: CKTransactionType?
    public let type: CKInvoiceType
    public let totalAmount: Double
    public let nonTaxTotal: Double
    public let createdAt: Date
    public let customerId: String
    public let invoiceNumber: String
    public let items: [CKInvoiceItem]
}

public struct CKOrder: Codable {
    public let price: Double
    public let quantity: Double
    public let wknIsin: String?
    public let optionDirection: String?
    public let underlyingAsset: String?
    public let strike: Double?
    public let symbol: String?
}

public struct CKTrade: Codable {
    public let id: String
    public let tradeNumber: Int?
    public let buyOrder: CKOrder
    public let sellOrders: [CKOrder]
    public let totalQuantity: Double
    public let totalSoldQuantity: Double
    public let entryPrice: Double
    public let displayROI: Double
}

public struct CKParticipation: Codable {
    public let tradeId: String
    public let investmentId: String
    public let ownershipPercentage: Double
    public let allocatedAmount: Double
}

public enum CKInvestmentReservationStatus: String, Codable {
    case pending
    case completed
    case cancelled
}

public enum CKInvestmentStatus: String, Codable {
    case active
    case completed
    case cancelled
}

public struct CKInvestment: Codable {
    public let id: String
    public let amount: Double
    public let reservationStatus: CKInvestmentReservationStatus
    public let status: CKInvestmentStatus
}

public enum CKAccountStatementDirection: String, Codable {
    case credit
    case debit
}

public enum CKAccountStatementCategory: String, Codable {
    case tradeSettlement
    case commission
    case cashMovement
    case adjustment
}

public struct CKAccountStatementEntry: Codable {
    public let title: String
    public let subtitle: String?
    public let occurredAt: Date
    public let amount: Double
    public let direction: CKAccountStatementDirection
    public let category: CKAccountStatementCategory
    public let reference: String
    public let metadata: [String: String]
    public let balanceAfter: Double

    public var signedAmount: Double {
        direction == .credit ? amount : -amount
    }
}

public enum CKUserRole: String, Codable {
    case investor
    case trader
    case admin
}

public struct CKUser: Codable {
    public let id: String
    public let username: String
    public let firstName: String
    public let lastName: String
    public let role: CKUserRole
    public let customerId: String
}

// MARK: - Documents

public enum CKDocumentType: String, Codable {
    case monthlyAccountStatement
}

public struct CKDocument: Codable {
    public let userId: String
    public let name: String
    public let type: CKDocumentType
    public let fileURL: String
    public let size: Int
    public let uploadedAt: Date
    public let verifiedAt: Date?
    public let statementYear: Int?
    public let statementMonth: Int?
    public let statementRole: CKUserRole?
}














