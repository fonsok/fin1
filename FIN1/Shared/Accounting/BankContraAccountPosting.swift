import Foundation

// MARK: - Bank Contra Account Definitions

/// Ledger accounts used to temporarily hold cash movements against the bank
enum BankContraAccount: String, Codable, CaseIterable {
    /// Holds the net platform service charge portion before it is moved to revenue
    case platformServiceChargeNet = "BANK-PS-NET"
    /// Holds the VAT portion of the platform service charge before it is remitted
    case platformServiceChargeVAT = "BANK-PS-VAT"

    var displayName: String {
        switch self {
        case .platformServiceChargeNet:
            return "Bank Clearing – Service Charge NET"
        case .platformServiceChargeVAT:
            return "Bank Clearing – Service Charge VAT"
        }
    }
}

/// Debit/Credit indicator for contra account postings
enum BankContraPostingSide: String, Codable {
    case debit
    case credit
}

/// Represents a single posting on a bank contra account ledger
struct BankContraAccountPosting: Identifiable, Codable, Hashable {
    let id: UUID
    let account: BankContraAccount
    let side: BankContraPostingSide
    let amount: Double
    let investorId: String
    let batchId: String
    let investmentIds: [String]
    let reference: String
    let createdAt: Date
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        account: BankContraAccount,
        side: BankContraPostingSide,
        amount: Double,
        investorId: String,
        batchId: String,
        investmentIds: [String],
        reference: String,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.account = account
        self.side = side
        self.amount = amount
        self.investorId = investorId
        self.batchId = batchId
        self.investmentIds = investmentIds
        self.reference = reference
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

/// Helper structure returned when recording postings for a platform service charge
struct BankContraPostingPair {
    let netPosting: BankContraAccountPosting
    let vatPosting: BankContraAccountPosting
}

// MARK: - Service Protocol

protocol BankContraAccountPostingServiceProtocol: ServiceLifecycle {
    /// Records the contra account postings for a platform service charge (net + VAT components)
    /// - Returns: The created postings so callers can reference them in metadata
    @discardableResult
    func recordPlatformServiceChargePosting(
        investorId: String,
        batchId: String,
        investmentIds: [String],
        grossAmount: Double,
        netAmount: Double,
        vatAmount: Double
    ) -> BankContraPostingPair

    /// Retrieves all postings, optionally filtered by account or investor
    func getPostings(
        account: BankContraAccount?,
        investorId: String?
    ) -> [BankContraAccountPosting]

    /// Convenience accessor for all postings
    func getAllPostings() -> [BankContraAccountPosting]
}











