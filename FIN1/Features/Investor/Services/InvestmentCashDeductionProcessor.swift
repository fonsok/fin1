import Foundation

// MARK: - Investment Cash Deduction Processor

/// Handles cash deductions for investment creation
/// Extracted from InvestmentCreationService to reduce file size
final class InvestmentCashDeductionProcessor {

    private let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    private let bankContraAccountService: (any BankContraAccountPostingServiceProtocol)?
    private let invoiceService: (any InvoiceServiceProtocol)?
    private let documentService: (any DocumentServiceProtocol)?
    private let transactionIdService: any TransactionIdServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol

    init(
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?,
        bankContraAccountService: (any BankContraAccountPostingServiceProtocol)?,
        invoiceService: (any InvoiceServiceProtocol)?,
        documentService: (any DocumentServiceProtocol)?,
        transactionIdService: any TransactionIdServiceProtocol,
        configurationService: any ConfigurationServiceProtocol
    ) {
        self.investorCashBalanceService = investorCashBalanceService
        self.bankContraAccountService = bankContraAccountService
        self.invoiceService = invoiceService
        self.documentService = documentService
        self.transactionIdService = transactionIdService
        self.configurationService = configurationService
    }

    // MARK: - Public Methods

    /// Processes cash deductions for investments and platform service charge
    func processCashDeductions(
        investor: User,
        batch: InvestmentBatch,
        investments: [Investment]
    ) async {
        print("💰 InvestmentCashDeductionProcessor: Processing - Investor: \(investor.id)")
        print("   💵 Total Investment: €\(batch.totalAmount.formatted(.currency(code: "EUR")))")
        print("   💰 Platform Service Charge: €\(batch.platformServiceCharge.formatted(.currency(code: "EUR")))")

        guard let investorCashBalanceService = investorCashBalanceService else {
            print("⚠️ InvestmentCashDeductionProcessor: investorCashBalanceService is nil")
            return
        }

        // Deduct each investment amount separately
        for investment in investments {
            await investorCashBalanceService.processInvestment(
                investorId: investor.id,
                amount: investment.amount,
                investmentId: investment.id
            )
            print("   📝 Deducted investment [ID: \(investment.id)]: -€\(investment.amount.formatted(.currency(code: "EUR")))")
        }

        // Calculate VAT breakdown
        let vatRate = CalculationConstants.TaxRates.vatRate
        let netServiceCharge = batch.platformServiceCharge / (1.0 + vatRate)
        let vatAmount = batch.platformServiceCharge - netServiceCharge

        // Build service charge metadata
        let serviceChargeMetadata = buildServiceChargeMetadata(
            investor: investor,
            batch: batch,
            investments: investments,
            netServiceCharge: netServiceCharge,
            vatAmount: vatAmount
        )

        // Process service charge deduction
        await investorCashBalanceService.processPlatformServiceCharge(
            investorId: investor.id,
            chargeAmount: batch.platformServiceCharge,
            investmentId: batch.id,
            metadata: serviceChargeMetadata
        )

        // Create invoice for platform service charge
        await createServiceChargeInvoice(
            investor: investor,
            serviceChargeAmount: batch.platformServiceCharge,
            batchId: batch.id,
            investments: investments,
            netAmount: netServiceCharge,
            vatAmount: vatAmount
        )

        print("💰 InvestmentCashDeductionProcessor: Completed - \(investments.count) transactions + 1 service charge")
    }

    // MARK: - Private Methods

    private func buildServiceChargeMetadata(
        investor: User,
        batch: InvestmentBatch,
        investments: [Investment],
        netServiceCharge: Double,
        vatAmount: Double
    ) -> [String: String] {
        var metadata: [String: String] = [
            "serviceChargeNetAmount": "\(netServiceCharge)",
            "serviceChargeVatAmount": "\(vatAmount)"
        ]

        if let bankContraAccountService = bankContraAccountService {
            let contraPostings = bankContraAccountService.recordPlatformServiceChargePosting(
                investorId: investor.id,
                batchId: batch.id,
                investmentIds: investments.map { $0.id },
                grossAmount: batch.platformServiceCharge,
                netAmount: netServiceCharge,
                vatAmount: vatAmount
            )

            metadata["contraAccountNetPostingId"] = contraPostings.netPosting.id.uuidString
            metadata["contraAccountVatPostingId"] = contraPostings.vatPosting.id.uuidString

            print("🏦 InvestmentCashDeductionProcessor: Bank contra postings created")
        }

        return metadata
    }

    private func createServiceChargeInvoice(
        investor: User,
        serviceChargeAmount: Double,
        batchId: String,
        investments: [Investment],
        netAmount: Double,
        vatAmount: Double
    ) async {
        guard let invoiceService = invoiceService else {
            print("⚠️ InvestmentCashDeductionProcessor: invoiceService is nil")
            return
        }

        let customerInfo = CustomerInfo.from(user: investor)

        // Extract investment IDs and amounts for detailed invoice description
        let investmentIds = investments.map { $0.id }
        let investmentAmounts = investments.map { $0.amount }

        let invoice = Invoice.forServiceCharge(
            grossServiceChargeAmount: serviceChargeAmount,
            customerInfo: customerInfo,
            transactionIdService: transactionIdService,
            batchId: batchId,
            investmentIds: investmentIds,
            investmentAmounts: investmentAmounts,
            serviceChargeRate: configurationService.effectivePlatformServiceChargeRate
        )

        await invoiceService.addInvoice(invoice)

        print("📄 InvestmentCashDeductionProcessor: Service Charge Invoice Created")
        print("   📋 Invoice Number: \(invoice.invoiceNumber)")
        print("   💰 Gross: €\(serviceChargeAmount.formatted(.currency(code: "EUR")))")

        await createServiceChargeInvoiceDocument(invoice: invoice, investor: investor, batchId: batchId)
    }

    private func createServiceChargeInvoiceDocument(
        invoice: Invoice,
        investor: User,
        batchId: String
    ) async {
        guard let documentService = documentService else {
            print("⚠️ InvestmentCashDeductionProcessor: documentService is nil")
            return
        }

        let documentName = DocumentNamingUtility.invoiceName(for: invoice, userRole: .investor)
        let document = Document(
            userId: investor.id,
            name: documentName,
            type: .invoice,
            status: .verified,
            fileURL: "invoice://\(invoice.invoiceNumber).pdf",
            size: 1024 * 50,
            uploadedAt: Date(),
            invoiceData: invoice,
            tradeId: nil,
            investmentId: batchId,
            documentNumber: invoice.invoiceNumber
        )

        do {
            try await documentService.uploadDocument(document)
            print("📄 InvestmentCashDeductionProcessor: Invoice document added to notifications")
        } catch {
            print("❌ InvestmentCashDeductionProcessor: Failed to add invoice document: \(error)")
        }
    }
}
