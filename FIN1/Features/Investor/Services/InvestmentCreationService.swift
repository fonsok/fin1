import Foundation

// MARK: - Investment Creation Service Implementation
/// Handles investment creation operations
final class InvestmentCreationService: InvestmentCreationServiceProtocol {

    private let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    private let investmentManagementService: (any InvestmentManagementServiceProtocol)?
    private let investmentDocumentService: (any InvestmentDocumentServiceProtocol)?
    private let documentService: (any DocumentServiceProtocol)?
    private let invoiceService: (any InvoiceServiceProtocol)?
    private let bankContraAccountService: (any BankContraAccountPostingServiceProtocol)?
    private let transactionIdService: any TransactionIdServiceProtocol
    private let cashDeductionProcessor: InvestmentCashDeductionProcessor

    init(
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        investmentManagementService: (any InvestmentManagementServiceProtocol)? = nil,
        investmentDocumentService: (any InvestmentDocumentServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        invoiceService: (any InvoiceServiceProtocol)? = nil,
        bankContraAccountService: (any BankContraAccountPostingServiceProtocol)? = nil,
        transactionIdService: any TransactionIdServiceProtocol = TransactionIdService()
    ) {
        self.investorCashBalanceService = investorCashBalanceService
        self.investmentManagementService = investmentManagementService
        self.investmentDocumentService = investmentDocumentService
        self.documentService = documentService
        self.invoiceService = invoiceService
        self.bankContraAccountService = bankContraAccountService
        self.transactionIdService = transactionIdService

        // Create cash deduction processor with same dependencies
        self.cashDeductionProcessor = InvestmentCashDeductionProcessor(
            investorCashBalanceService: investorCashBalanceService,
            bankContraAccountService: bankContraAccountService,
            invoiceService: invoiceService,
            documentService: documentService,
            transactionIdService: transactionIdService
        )
    }

    /// Creates a new investment batch with individual investments
    /// Each investment is now a first-class Investment entity
    func createInvestment(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        potSelection: InvestmentSelectionStrategy,
        repository: any InvestmentRepositoryProtocol
    ) async throws {
        // Step 1: Validate input
        try validateInvestmentInput(
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments,
            specialization: specialization,
            investor: investor,
            trader: trader
        )

        // Step 2: Create investment batch
        let batch = try await createInvestmentBatch(
            investor: investor,
            trader: trader,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments,
            specialization: specialization,
            repository: repository
        )

        // Step 3: Create individual investments
        let investments = try await createIndividualInvestments(
            investor: investor,
            trader: trader,
            batch: batch,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments,
            specialization: specialization,
            repository: repository
        )

        // Step 4: Process cash deductions (investment amounts + platform service charge)
        await cashDeductionProcessor.processCashDeductions(
            investor: investor,
            batch: batch,
            investments: investments
        )

        // Step 5: Create investment pools and generate document
        await finalizeInvestmentCreation(
            batch: batch,
            investments: investments,
            trader: trader,
            repository: repository
        )
    }

    // MARK: - Investment Creation Helpers

    /// Validates investment input parameters
    private func validateInvestmentInput(
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        investor: User,
        trader: MockTrader
    ) throws {
        // Basic input validation
        guard amountPerInvestment > 0 else {
            throw AppError.validationError("Investment amount must be greater than zero")
        }
        guard numberOfInvestments > 0 else {
            throw AppError.validationError("Number of investments must be greater than zero")
        }
        guard !specialization.isEmpty else {
            throw AppError.validationError("Specialization is required")
        }

        // Validate the investment using existing validation
        if let error = Investment.validateInvestment(
            investor: investor,
            trader: trader,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments
        ) {
            // Convert InvestmentValidationError to AppError
            switch error {
            case .traderCannotInvestInTrader:
                throw AppError.validationError("Traders cannot invest in other traders")
            case .invalidAmount:
                throw AppError.validationError("Invalid investment amount")
            case .invalidNumberOfInvestments:
                throw AppError.validationError("Invalid number of investments")
            case .minimumAmountNotMet:
                throw AppError.validationError("Minimum investment amount not met")
            case .investmentNotAvailable:
                throw AppError.serviceError(.dataNotFound)
            case .insufficientFunds:
                throw AppError.validationError("Insufficient funds")
            }
        }

        // Check sufficient funds before creating investment (including platform service charge)
        // Note: Platform service charge applies ONLY to investors (not traders)
        if let investorCashBalanceService = investorCashBalanceService {
            let totalInvestmentAmount = amountPerInvestment * Double(numberOfInvestments)
            let platformServiceCharge = totalInvestmentAmount * CalculationConstants.ServiceCharges.platformServiceChargeRate
            let totalRequired = totalInvestmentAmount + platformServiceCharge
            if !investorCashBalanceService.hasSufficientFunds(investorId: investor.id, for: totalRequired) {
                throw AppError.validationError("Insufficient funds (including platform service charge)")
            }
        }
    }

    /// Creates an investment batch to group related investments
    private func createInvestmentBatch(
        investor: User,
        trader: MockTrader,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        repository: any InvestmentRepositoryProtocol
    ) async throws -> InvestmentBatch {
        // Simulate API call
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds

        // Simulate service errors
        if investor.email.lowercased().contains("permission") {
            throw AppError.serviceError(.permissionDenied)
        }

        if investor.email.lowercased().contains("rate") {
            throw AppError.serviceError(.rateLimited)
        }

        // Calculate batch totals
        let totalAmount = amountPerInvestment * Double(numberOfInvestments)
        let platformServiceCharge = totalAmount * CalculationConstants.ServiceCharges.platformServiceChargeRate
        // Use numberOfInvestments directly

        // Create the batch
        print("🔍 InvestmentCreationService.createInvestmentBatch:")
        print("   👤 Investor ID: '\(investor.id)'")
        print("   👤 Trader ID: '\(trader.id.uuidString)'")
        print("   👤 Trader Name: \(trader.name)")
        print("   💵 Total Amount: €\(totalAmount.formatted(.currency(code: "EUR")))")
        print("   📦 Number of Investments: \(numberOfInvestments)")

        let batch = InvestmentBatch.createBatch(
            investor: investor,
            trader: trader,
            totalAmount: totalAmount,
            platformServiceCharge: platformServiceCharge,
            specialization: specialization
        )

        print("   ✅ Created batch:")
        print("      Batch ID: \(batch.id)")
        print("      Batch totalAmount: €\(batch.totalAmount.formatted(.currency(code: "EUR")))")
        print("      Batch platformServiceCharge: €\(batch.platformServiceCharge.formatted(.currency(code: "EUR")))")

        // Add to repository
        repository.investmentBatches.append(batch)
        print("   📊 Total batches after append: \(repository.investmentBatches.count)")

        return batch
    }

    /// Creates individual investments
    private func createIndividualInvestments(
        investor: User,
        trader: MockTrader,
        batch: InvestmentBatch,
        amountPerInvestment: Double,
        numberOfInvestments: Int,
        specialization: String,
        repository: any InvestmentRepositoryProtocol
    ) async throws -> [Investment] {
        // Use numberOfInvestments directly
        print("🔍 InvestmentCreationService.createIndividualInvestments:")
        print("   📦 Creating \(numberOfInvestments) individual investments for batch \(batch.id)")

        // Create investments from batch
        let investments = try Investment.createInvestmentsFromBatch(
            investor: investor,
            trader: trader,
            batchId: batch.id,
            amountPerInvestment: amountPerInvestment,
            numberOfInvestments: numberOfInvestments,
            specialization: specialization
        )

        // Add all investments to repository
        repository.investments.append(contentsOf: investments)
        print("   ✅ Created \(investments.count) investments")
        print("   📊 Total investments after append: \(repository.investments.count)")

        for (index, investment) in investments.enumerated() {
            print("      [\(index + 1)] Investment \(investment.id): sequenceNumber=\(investment.sequenceNumber ?? 0), amount=€\(investment.amount.formatted(.currency(code: "EUR"))), status=\(investment.reservationStatus.rawValue)")
        }

        return investments
    }

    // MARK: - Cash Deduction Methods
    // Note: processCashDeductions, createServiceChargeInvoice, and createServiceChargeInvoiceDocument
    // have been extracted to InvestmentCashDeductionProcessor to reduce file size.

    /// Finalizes investment creation: creates pools and generates document
    private func finalizeInvestmentCreation(
        batch: InvestmentBatch,
        investments: [Investment],
        trader: MockTrader,
        repository: any InvestmentRepositoryProtocol
    ) async {
        // Create investment pools (one per investment)
        createInvestmentPools(
            investments: investments,
            trader: trader,
            repository: repository
        )

        // Generate investment document for the batch
        if let investmentDocumentService = investmentDocumentService {
            // Generate document for the batch (representing all investments)
            await investmentDocumentService.generateInvestmentDocument(for: batch, investments: investments)
        } else {
            // Fallback to direct call if service not available
            await generateInvestmentDocument(for: batch, investments: investments)
        }
    }

    /// Creates investment pools (one per investment)
    /// Investment numbers are calculated per trader based on existing pools
    private func createInvestmentPools(
        investments: [Investment],
        trader: MockTrader,
        repository: any InvestmentRepositoryProtocol
    ) {
        guard let investmentManagementService = investmentManagementService else {
            print("⚠️ InvestmentCreationService: investmentManagementService is nil - cannot create pools")
            return
        }

        // Get existing pools for this trader to calculate next investment number
        let existingPools = repository.investmentPools.filter { $0.traderId == trader.id.uuidString }
        let maxInvestmentNumber = existingPools.map { $0.poolNumber }.max() ?? 0
        var nextInvestmentNumber = maxInvestmentNumber + 1

        print("🔍 InvestmentCreationService.createInvestmentPools:")
        print("   👤 Trader ID: \(trader.id.uuidString)")
        print("   📊 Existing pools for trader: \(existingPools.count)")
        print("   🔢 Max investment number: \(maxInvestmentNumber), starting from: \(nextInvestmentNumber)")

        // Create one pool per investment with sequential investment numbers per trader
        for investment in investments {
            let newPool = investmentManagementService.createNewInvestmentPool(
                for: trader.id.uuidString,
                sequenceNumber: nextInvestmentNumber,
                amountPerInvestment: investment.amount
            )
            repository.investmentPools.append(newPool)
            print("✅ InvestmentCreationService: Created pool for investment \(investment.id), investmentNumber=\(nextInvestmentNumber) (trader-specific)")

            // Note: The investment's poolNumber (1, 2, 3...) is for batch display only.
            // The actual trader-specific investment number is stored in the pool.
            // This ensures each trader has their own sequential investment numbers.

            nextInvestmentNumber += 1
        }
    }

    /// Generates investment document and notification (fallback implementation)
    private func generateInvestmentDocument(for batch: InvestmentBatch, investments: [Investment]) async {
        // CRITICAL: Use proper document number generation for accounting compliance
        let documentNumber = transactionIdService.generateInvestorDocumentNumber()
        print("📄 InvestmentCreationService: Investment Document Generated: \(documentNumber) for Batch #\(batch.id)")

        // Create document for the Batch with industry-standard naming
        let documentName = DocumentNamingUtility.investorCollectionBillBatchName(for: batch)
        
        let document = Document(
            userId: batch.investorId,
            name: documentName,
            type: .investorCollectionBill,
            status: .verified,
            fileURL: "investment://\(documentNumber).pdf",
            size: 1024 * 60, // Mock 60KB PDF size
            uploadedAt: Date(),
            documentNumber: documentNumber
        )

        // Add document to document service
        if let documentService = documentService {
            do {
                try await documentService.uploadDocument(document)
                print("📄 InvestmentCreationService: Investment batch document added to notifications")
                print("   📦 Batch ID: \(batch.id)")
                print("   📊 Investments: \(investments.count)")
            } catch {
                print("❌ InvestmentCreationService: Failed to add Investment document: \(error)")
            }
        } else {
            print("⚠️ InvestmentCreationService: documentService is nil - document not uploaded")
        }

        // Send notification
        print("🔔 InvestmentCreationService: Notification: Investment Document \(documentNumber) is ready for download")
    }
}
