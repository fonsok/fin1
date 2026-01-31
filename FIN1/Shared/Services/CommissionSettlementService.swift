import Foundation

// MARK: - Commission Settlement Service Protocol

protocol CommissionSettlementServiceProtocol: ServiceLifecycle {
    /// Processes batch settlement of accumulated commissions for a trader
    /// Creates credit note for trader and commission invoices for investors
    func settleCommissions(for traderId: String) async throws -> CommissionSettlement

    /// Processes batch settlement for all traders with unsettled commissions
    func settleAllCommissions() async throws -> [CommissionSettlement]
}

// MARK: - Commission Settlement Service Implementation

final class CommissionSettlementService: CommissionSettlementServiceProtocol {

    // MARK: - Dependencies

    private let commissionAccumulationService: any CommissionAccumulationServiceProtocol
    private let traderCashBalanceService: (any TraderCashBalanceServiceProtocol)?
    private let documentService: (any DocumentServiceProtocol)?
    private let invoiceService: (any InvoiceServiceProtocol)?
    private let transactionIdService: any TransactionIdServiceProtocol
    private let userService: any UserServiceProtocol

    // MARK: - Initialization

    init(
        commissionAccumulationService: any CommissionAccumulationServiceProtocol,
        traderCashBalanceService: (any TraderCashBalanceServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        invoiceService: (any InvoiceServiceProtocol)? = nil,
        transactionIdService: any TransactionIdServiceProtocol,
        userService: any UserServiceProtocol
    ) {
        self.commissionAccumulationService = commissionAccumulationService
        self.traderCashBalanceService = traderCashBalanceService
        self.documentService = documentService
        self.invoiceService = invoiceService
        self.transactionIdService = transactionIdService
        self.userService = userService
    }

    // MARK: - ServiceLifecycle

    func start() async {
        print("💰 CommissionSettlementService started")
    }

    func stop() async {
        print("💰 CommissionSettlementService stopped")
    }

    func reset() async {
        print("💰 CommissionSettlementService reset")
    }

    // MARK: - Public Methods

    func settleCommissions(for traderId: String) async throws -> CommissionSettlement {
        // 1. Get all unsettled commissions for this trader
        let unsettledCommissions = commissionAccumulationService.getUnsettledCommissions(for: traderId)

        guard !unsettledCommissions.isEmpty else {
            throw CommissionSettlementError.noUnsettledCommissions
        }

        // 2. Calculate totals
        let totalCommission = unsettledCommissions.reduce(0.0) { $0 + $1.commissionAmount }
        let tradeIds = Array(Set(unsettledCommissions.map { $0.tradeId }))
        let tradeNumbers = Array(Set(unsettledCommissions.map { $0.tradeNumber })).sorted()
        let investorIds = Set(unsettledCommissions.map { $0.investorId })

        print("💰 CommissionSettlementService: Processing settlement for trader \(traderId)")
        print("   📊 Total Commission: €\(totalCommission.formatted(.currency(code: "EUR")))")
        print("   📊 Number of Commissions: \(unsettledCommissions.count)")
        print("   📊 Number of Trades: \(tradeIds.count)")
        print("   📊 Number of Investors: \(investorIds.count)")

        // 3. Create credit note for trader
        let creditNote = try await createCreditNoteForTrader(
            traderId: traderId,
            totalCommission: totalCommission,
            tradeNumbers: tradeNumbers,
            unsettledCommissions: unsettledCommissions
        )

        // 4. Create commission invoices for each investor
        var invoiceIds: [String] = []
        for investorId in investorIds {
            let investorCommissions = unsettledCommissions.filter { $0.investorId == investorId }
            let invoice = try await createCommissionInvoiceForInvestor(
                investorId: investorId,
                commissions: investorCommissions
            )
            invoiceIds.append(invoice.id)
        }

        // 5. Create settlement record
        let settlement = CommissionSettlement(
            traderId: traderId,
            totalCommissionAmount: totalCommission,
            commissionCount: unsettledCommissions.count,
            tradeIds: tradeIds,
            tradeNumbers: tradeNumbers,
            investorIds: investorIds,
            creditNoteId: creditNote.id
        )

        // 6. Mark commissions as settled
        let commissionIds = unsettledCommissions.map { $0.id }
        await commissionAccumulationService.markCommissionsAsSettled(
            commissionIds: commissionIds,
            settlementId: settlement.id
        )

        // 7. Update trader balance with credit note amount
        if let traderCashBalanceService = traderCashBalanceService {
            await traderCashBalanceService.processCommissionPayment(
                traderId: traderId,
                commissionAmount: totalCommission,
                tradeId: settlement.id // Use settlement ID as tradeId reference
            )
        }

        print("✅ CommissionSettlementService: Settlement completed")
        print("   📋 Settlement ID: \(settlement.id)")
        print("   📄 Credit Note ID: \(creditNote.id)")
        print("   📄 Commission Invoices: \(invoiceIds.count)")

        return settlement
    }

    func settleAllCommissions() async throws -> [CommissionSettlement] {
        let commissionsByTrader = commissionAccumulationService.getUnsettledCommissionsByTrader()

        var settlements: [CommissionSettlement] = []

        for (traderId, _) in commissionsByTrader {
            do {
                let settlement = try await settleCommissions(for: traderId)
                settlements.append(settlement)
            } catch {
                print("⚠️ CommissionSettlementService: Failed to settle commissions for trader \(traderId): \(error)")
                // Continue with other traders
            }
        }

        return settlements
    }

    // MARK: - Private Methods

    private func createCreditNoteForTrader(
        traderId: String,
        totalCommission: Double,
        tradeNumbers: [Int],
        unsettledCommissions: [CommissionAccumulation]
    ) async throws -> Invoice {
        // Get trader user info - use current user if it matches, otherwise create default
        let customerInfo: CustomerInfo
        if let currentUser = userService.currentUser, currentUser.id == traderId {
            customerInfo = CustomerInfo.from(user: currentUser)
        } else {
            // Create default customer info for trader (in production, this would fetch from database)
            customerInfo = CustomerInfo(
                name: "Trader",
                address: "Nicht angegeben",
                city: "Nicht angegeben",
                postalCode: "00000",
                taxNumber: "Nicht angegeben",
                depotNumber: "DE\(String(format: "%020d", abs(traderId.hashValue)))",
                bank: LegalIdentity.bankName,
                customerNumber: traderId
            )
        }

        // Create credit note invoice
        let creditNote = Invoice.creditNote(
            totalCommissionAmount: totalCommission,
            customerInfo: customerInfo,
            transactionIdService: transactionIdService,
            tradeNumbers: tradeNumbers,
            commissions: unsettledCommissions
        )

        // Save credit note as document
        if let documentService = documentService {
            let document = Document(
                userId: traderId,
                name: "Gutschrift \(creditNote.invoiceNumber)",
                type: .invoice,
                status: .pending,
                fileURL: "",
                size: 0,
                uploadedAt: Date(),
                invoiceData: creditNote,
                documentNumber: creditNote.invoiceNumber
            )

            do {
                try await documentService.uploadDocument(document)
            } catch {
                print("⚠️ CommissionSettlementService: Failed to save credit note document: \(error)")
            }
        }

        // Save invoice if invoice service is available
        if let invoiceService = invoiceService {
            await invoiceService.addInvoice(creditNote)
        }

        return creditNote
    }

    private func createCommissionInvoiceForInvestor(
        investorId: String,
        commissions: [CommissionAccumulation]
    ) async throws -> Invoice {
        // Get investor user info - use current user if it matches, otherwise create default
        let customerInfo: CustomerInfo
        if let currentUser = userService.currentUser, currentUser.id == investorId {
            customerInfo = CustomerInfo.from(user: currentUser)
        } else {
            // Create default customer info for investor (in production, this would fetch from database)
            customerInfo = CustomerInfo(
                name: "Investor",
                address: "Nicht angegeben",
                city: "Nicht angegeben",
                postalCode: "00000",
                taxNumber: "Nicht angegeben",
                depotNumber: "DE\(String(format: "%020d", abs(investorId.hashValue)))",
                bank: LegalIdentity.bankName,
                customerNumber: investorId
            )
        }

        // Calculate total commission for this investor
        let totalCommission = commissions.reduce(0.0) { $0 + $1.commissionAmount }

        // Create commission invoice
        let invoice = Invoice.commissionInvoice(
            totalCommissionAmount: totalCommission,
            customerInfo: customerInfo,
            transactionIdService: transactionIdService,
            commissions: commissions
        )

        // Save commission invoice as document
        if let documentService = documentService {
            let document = Document(
                userId: investorId,
                name: "Rechnung - Provision \(invoice.invoiceNumber)",
                type: .invoice,
                status: .pending,
                fileURL: "",
                size: 0,
                uploadedAt: Date(),
                invoiceData: invoice,
                documentNumber: invoice.invoiceNumber
            )

            do {
                try await documentService.uploadDocument(document)
            } catch {
                print("⚠️ CommissionSettlementService: Failed to save commission invoice document: \(error)")
            }
        }

        // Save invoice if invoice service is available
        if let invoiceService = invoiceService {
            await invoiceService.addInvoice(invoice)
        }

        return invoice
    }
}

// MARK: - Commission Settlement Errors

enum CommissionSettlementError: LocalizedError {
    case noUnsettledCommissions
    case traderNotFound
    case investorNotFound

    var errorDescription: String? {
        switch self {
        case .noUnsettledCommissions:
            return "No unsettled commissions found"
        case .traderNotFound:
            return "Trader not found"
        case .investorNotFound:
            return "Investor not found"
        }
    }
}
