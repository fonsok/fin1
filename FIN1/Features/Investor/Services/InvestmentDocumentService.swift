import Foundation

// MARK: - Investment Document Service Implementation
/// Handles investment document generation and upload
final class InvestmentDocumentService: InvestmentDocumentServiceProtocol {

    private let documentService: (any DocumentServiceProtocol)?
    private let transactionIdService: (any TransactionIdServiceProtocol)?

    init(
        documentService: (any DocumentServiceProtocol)? = nil,
        transactionIdService: (any TransactionIdServiceProtocol)? = nil
    ) {
        self.documentService = documentService
        self.transactionIdService = transactionIdService
    }

    // MARK: - ServiceLifecycle

    func start() { /* preload if needed */ }

    func stop() { /* noop */ }

    func reset() { /* noop */ }

    // MARK: - Document Generation

    /// Generates investment document and notification for a batch
    func generateInvestmentDocument(for batch: InvestmentBatch, investments: [Investment]) async {
        // CRITICAL: Use proper document number generation for accounting compliance
        // Generate structured document number from TransactionIdService (not UUID)
        let documentNumber = transactionIdService?.generateInvestorDocumentNumber() ?? TransactionIdService().generateInvestorDocumentNumber()
        print("📄 InvestmentDocumentService: Investment Document Generated: \(documentNumber) for Batch #\(batch.id)")

        // Create document for the Batch with industry-standard naming
        let documentName = DocumentNamingUtility.investorCollectionBillBatchName(for: batch)
        let primaryInvestmentId = investments
            .min(by: { ($0.sequenceNumber ?? Int.max) < ($1.sequenceNumber ?? Int.max) })?
            .id ?? investments.first?.id

        let document = Document(
            userId: batch.investorId,
            name: documentName,
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "investment://\(documentNumber).pdf",
            size: 1024 * 60, // Mock 60KB PDF size
            uploadedAt: Date(),
            investmentId: primaryInvestmentId,
            documentNumber: documentNumber
        )

        // Add document to document service
        if let documentService = documentService {
            do {
                try await documentService.uploadDocument(document)
                print("📄 InvestmentDocumentService: Investment batch document added to notifications")
                print("   📦 Batch ID: \(batch.id)")
                print("   📊 Investments: \(investments.count)")
            } catch {
                print("❌ InvestmentDocumentService: Failed to add Investment document: \(error)")
            }
        } else {
            print("⚠️ InvestmentDocumentService: documentService is nil - document not uploaded")
        }

        // Send notification
        print("🔔 InvestmentDocumentService: Notification: Investment Document \(documentNumber) is ready for download")
    }

    /// Generates investment document for a single investment (backward compatibility)
    func generateInvestmentDocument(for investment: Investment) async {
        // CRITICAL: Use proper document number generation for accounting compliance
        // Generate structured document number from TransactionIdService (not UUID)
        let documentNumber = transactionIdService?.generateInvestorDocumentNumber() ?? TransactionIdService().generateInvestorDocumentNumber()
        let documentName = DocumentNamingUtility.investorCollectionBillName(for: investment)

        print("📄 InvestmentDocumentService: Investor Collection Bill Generated: \(documentNumber) for Investment \(investment.id)")

        if let documentService,
           documentService.documents.contains(where: { $0.investmentId == investment.id && $0.type == .investorCollectionBill }) {
            print("ℹ️ InvestmentDocumentService: Collection Bill already exists for investment \(investment.id); skipping regeneration.")
            return
        }

        let document = Document(
            userId: investment.investorId,
            name: documentName,
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "collectionbill://\(documentNumber).pdf",
            size: 1024 * 60,
            uploadedAt: Date(),
            investmentId: investment.id,
            documentNumber: documentNumber
        )

        if let documentService = documentService {
            do {
                try await documentService.uploadDocument(document)
                print("📄 InvestmentDocumentService: Investor Collection Bill document added to notifications")
                print("   👤 Investor ID: \(investment.investorId)")
                print("   💵 Amount: €\(investment.amount)")
            } catch {
                print("❌ InvestmentDocumentService: Failed to add investor Collection Bill document: \(error)")
            }
        } else {
            print("⚠️ InvestmentDocumentService: documentService is nil - investor Collection Bill not uploaded")
        }

        print("🔔 InvestmentDocumentService: Notification: Investor Collection Bill \(documentNumber) is ready for download")
    }

    func regenerateInvestmentDocuments(for investments: [Investment]) async {
        print("📄 InvestmentDocumentService: Checking for missing documents for \(investments.count) investments")
        for investment in investments where investment.reservationStatus == .completed {
            // generateInvestmentDocument already checks if document exists
            await generateInvestmentDocument(for: investment)
        }
    }
}
