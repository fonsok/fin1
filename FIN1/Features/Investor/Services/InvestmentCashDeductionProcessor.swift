import Foundation

// MARK: - Investment Cash Deduction Processor

/// Handles cash deductions for investment creation
/// Extracted from InvestmentCreationService to reduce file size
@MainActor
final class InvestmentCashDeductionProcessor {

    private let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    private let bankContraAccountService: (any BankContraAccountPostingServiceProtocol)?
    private let invoiceService: (any InvoiceServiceProtocol)?
    private let documentUploadBridge: UncheckedDocumentServiceBridge?
    private let transactionIdService: any TransactionIdServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    /// ADR-007 Phase-2 dependency. When
    /// `configurationService.serviceChargeInvoiceFromBackend` is `true`, the
    /// processor routes Invoice creation through `bookAppServiceCharge`
    /// instead of writing the `Invoice` locally via `invoiceService`.
    private let investmentAPIService: (any InvestmentAPIServiceProtocol)?

    init(
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?,
        bankContraAccountService: (any BankContraAccountPostingServiceProtocol)?,
        invoiceService: (any InvoiceServiceProtocol)?,
        documentUploadBridge: UncheckedDocumentServiceBridge?,
        transactionIdService: any TransactionIdServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        investmentAPIService: (any InvestmentAPIServiceProtocol)? = nil
    ) {
        self.investorCashBalanceService = investorCashBalanceService
        self.bankContraAccountService = bankContraAccountService
        self.invoiceService = invoiceService
        self.documentUploadBridge = documentUploadBridge
        self.transactionIdService = transactionIdService
        self.configurationService = configurationService
        self.investmentAPIService = investmentAPIService
    }

    // MARK: - Public Methods

    /// Processes cash deductions for investments and app service charge
    func processCashDeductions(
        investor: User,
        batch: InvestmentBatch,
        investments: [Investment]
    ) async {
        print("💰 InvestmentCashDeductionProcessor: Processing - Investor: \(investor.id)")
        print("   💵 Total Investment: €\(batch.totalAmount.formatted(.currency(code: "EUR")))")
        print("   💰 App Service Charge: €\(batch.appServiceCharge.formatted(.currency(code: "EUR")))")

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
        let isCompany = investor.accountType == .company
        let vatRate = CalculationConstants.TaxRates.vatRate
        let netServiceCharge = isCompany
            ? batch.appServiceCharge
            : (batch.appServiceCharge / (1.0 + vatRate))
        let vatAmount = isCompany
            ? 0
            : (batch.appServiceCharge - netServiceCharge)

        // Build service charge metadata
        let serviceChargeMetadata = self.buildServiceChargeMetadata(
            investor: investor,
            batch: batch,
            investments: investments,
            netServiceCharge: netServiceCharge,
            vatAmount: vatAmount
        )

        // Process service charge deduction
        await investorCashBalanceService.processAppServiceCharge(
            investorId: investor.id,
            chargeAmount: batch.appServiceCharge,
            investmentId: batch.id,
            metadata: serviceChargeMetadata
        )

        // Create invoice for app service charge
        await self.createServiceChargeInvoice(
            investor: investor,
            serviceChargeAmount: batch.appServiceCharge,
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
            let contraPostings = bankContraAccountService.recordAppServiceChargePosting(
                investorId: investor.id,
                batchId: batch.id,
                investmentIds: investments.map { $0.id },
                grossAmount: batch.appServiceCharge,
                netAmount: netServiceCharge,
                vatAmount: vatAmount
            )

            metadata["contraAccountNetPostingId"] = contraPostings.netPosting.id.uuidString
            metadata["contraAccountVatPostingId"] = contraPostings.vatPosting.id.uuidString

            print("🏦 InvestmentCashDeductionProcessor: Bank contra postings created")
        }

        // Platform ledger (AppLedgerEntry + BankContraPosting) for service charge is
        // recorded server-side in triggers/invoice/ when the Invoice is saved.

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

        // A local `Invoice` value is always built: it backs the display
        // `Document` (PDF) shown in "Documents & Invoices" regardless of
        // where the ledger-side Parse `Invoice` is written. Only the
        // write-path differs between the legacy client path and the
        // ADR-007 Phase-2 server path.
        let invoice = Invoice.forServiceCharge(
            grossServiceChargeAmount: serviceChargeAmount,
            customerInfo: customerInfo,
            transactionIdService: self.transactionIdService,
            batchId: batchId,
            investmentIds: investmentIds,
            investmentAmounts: investmentAmounts,
            serviceChargeRate: self.configurationService.effectiveAppServiceChargeRate(
                for: investor.accountType.rawValue
            ),
            includeVAT: investor.accountType != .company
        )

        var shouldCreateInvoiceDocument = true
        if self.configurationService.serviceChargeInvoiceFromBackend,
           let apiService = investmentAPIService,
           let representativeInvestmentId = investments.first?.id,
           canAttemptServerServiceChargeBooking(with: representativeInvestmentId) {
            // ADR-007 Phase 2: route Invoice creation through the backend
            // Cloud function. The server-side function is idempotent
            // (`batchId + invoiceType`) and the `afterSave Invoice` trigger
            // books BankContra + AppLedger entries — exactly one Invoice
            // per batch, no double-posting risk. The display `Document`
            // below is still created locally so the PDF stays available.
            do {
                let invoiceId = try await apiService.bookAppServiceCharge(
                    // Use batchId as canonical business key; backend resolves both
                    // Parse objectId and batchId for backward compatibility.
                    investmentId: batchId.isEmpty ? representativeInvestmentId : batchId
                )
                print("📄 InvestmentCashDeductionProcessor: Service Charge Invoice booked server-side")
                print("   🆔 Server invoice id: \(invoiceId)")
                print("   💰 Gross: €\(serviceChargeAmount.formatted(.currency(code: "EUR")))")
            } catch {
                if self.isDuplicateServiceChargeInvoiceError(error) {
                    print("ℹ️ InvestmentCashDeductionProcessor: Service charge invoice already exists server-side — skipping client fallback")
                } else {
                    if self.configurationService.serviceChargeLegacyClientFallbackEnabled {
                        // Fail-safe: on transient technical error, use legacy fallback path.
                        print(
                            "⚠️ InvestmentCashDeductionProcessor: bookAppServiceCharge failed, falling back to client path — \(error.localizedDescription)"
                        )
                        await invoiceService.addInvoice(invoice)
                    } else {
                        // Stability guard: fallback is disabled by admin configuration.
                        print(
                            "❌ InvestmentCashDeductionProcessor: bookAppServiceCharge failed and legacy fallback is disabled — \(error.localizedDescription)"
                        )
                        shouldCreateInvoiceDocument = false
                    }
                }
            }
        } else {
            // Legacy client path: persist the Invoice directly via Parse.
            await invoiceService.addInvoice(invoice)
            print("📄 InvestmentCashDeductionProcessor: Service Charge Invoice Created (client path)")
            print("   📋 Invoice Number: \(invoice.invoiceNumber)")
            print("   💰 Gross: €\(serviceChargeAmount.formatted(.currency(code: "EUR")))")
            if self.configurationService.serviceChargeInvoiceFromBackend {
                print(
                    "ℹ️ InvestmentCashDeductionProcessor: Skipping server-side bookAppServiceCharge for local-only investment id; using client path"
                )
            }
        }

        if shouldCreateInvoiceDocument {
            await self.createServiceChargeInvoiceDocument(invoice: invoice, investor: investor, batchId: batchId)
        }
    }

    /// A duplicate invoice on `(invoiceType, batchId)` means the server path
    /// already persisted the canonical row. Running the client fallback would
    /// just trigger an avoidable second write attempt.
    private func isDuplicateServiceChargeInvoiceError(_ error: Error) -> Bool {
        func matches(_ message: String) -> Bool {
            let normalized = message.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            return normalized.contains("existiert bereits")
                || normalized.contains("already exists")
                || normalized.contains("duplicate")
        }

        if let networkError = error as? NetworkError {
            if case .badRequest(let message) = networkError {
                return matches(message)
            }
            return false
        }
        return matches(error.localizedDescription)
    }

    private func createServiceChargeInvoiceDocument(
        invoice: Invoice,
        investor: User,
        batchId: String
    ) async {
        guard let documentUploadBridge = documentUploadBridge else {
            print("⚠️ InvestmentCashDeductionProcessor: documentUploadBridge is nil")
            return
        }

        let documentName = DocumentNamingUtility.invoiceName(for: invoice, userRole: .investor)
        let document = Document(
            userId: investor.id,
            name: documentName,
            type: .invoice,
            status: .verified,
            fileURL: "invoice://\(invoice.invoiceNumber).pdf",
            size: 1_024 * 50,
            uploadedAt: Date(),
            invoiceData: invoice,
            tradeId: nil,
            investmentId: batchId,
            documentNumber: invoice.invoiceNumber
        )

        do {
            try await documentUploadBridge.uploadDocument(document)
            print("📄 InvestmentCashDeductionProcessor: Invoice document added to notifications")
        } catch {
            print("❌ InvestmentCashDeductionProcessor: Failed to add invoice document: \(error)")
        }
    }

    /// Parse objectIds are short alphanumeric strings; local UUIDs indicate
    /// a legacy/local-only investment row and would cause predictable 404 on
    /// `bookAppServiceCharge`. Skip that call to keep logs/monitoring clean.
    private func canAttemptServerServiceChargeBooking(with investmentId: String) -> Bool {
        let trimmed = investmentId.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return false }
        let isUuidLike = trimmed.count == 36 && trimmed.contains("-")
        return !isUuidLike
    }
}
