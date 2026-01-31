import Foundation
import OSLog

// MARK: - PDF Backend Service Protocol

/// Protocol for backend PDF generation service
protocol PDFBackendServiceProtocol: Sendable {
    /// Generates an invoice PDF from the backend
    func generateInvoicePDF(from invoice: Invoice) async throws -> Data

    /// Generates a trade statement PDF from the backend
    func generateTradeStatementPDF(
        for displayData: TradeStatementDisplayData,
        trade: TradeOverviewItem
    ) async throws -> Data

    /// Generates a credit note PDF from the backend
    func generateCreditNotePDF(from invoice: Invoice) async throws -> Data

    /// Generates an account statement PDF from the backend
    func generateAccountStatementPDF(
        statementNumber: String,
        customerInfo: CustomerInfo,
        period: String,
        entries: [AccountStatementEntry],
        openingBalance: Double,
        closingBalance: Double
    ) async throws -> Data
}

// MARK: - PDF Backend Service

/// Service for generating PDFs via the backend (WeasyPrint)
/// Professional DIN A4 documents following German business standards
final class PDFBackendService: PDFBackendServiceProtocol, @unchecked Sendable {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.fin1.app", category: "PDFBackendService")
    private let baseURL: URL
    private let session: URLSession

    // MARK: - Initialization

    init(baseURL: URL? = nil) {
        // Use configured server URL or default to local network Ubuntu server
        if let customURL = baseURL {
            self.baseURL = customURL
        } else {
            // Prefer Info.plist override (works on device), otherwise derive from Parse URL host.
            if let value = Bundle.main.object(forInfoDictionaryKey: "FIN1PDFServiceBaseURL") as? String,
               let url = URL(string: value),
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.baseURL = url
            } else {
                // Use same server host as Parse Server (ConfigurationService default is 1338 per server port mapping)
                let parseURL = Bundle.main.object(forInfoDictionaryKey: "FIN1ParseServerURL") as? String
                    ?? ProcessInfo.processInfo.environment["PARSE_SERVER_URL"]
                    ?? "http://192.168.178.24/parse"
                let serverHost = URL(string: parseURL)?.host ?? "192.168.178.24"

                // In production, route PDFs via nginx (PORT-CONFIGURATION: external 8086)
                self.baseURL = URL(string: "http://\(serverHost):8086")!
            }
        }

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 120
        self.session = URLSession(configuration: configuration)

        logger.info("PDFBackendService initialized with base URL: \(self.baseURL.absoluteString)")
    }

    // MARK: - Invoice PDF Generation

    func generateInvoicePDF(from invoice: Invoice) async throws -> Data {
        logger.info("Generating invoice PDF via backend: \(invoice.invoiceNumber)")

        let requestBody = InvoicePDFRequest(from: invoice)
        let endpoint = baseURL.appendingPathComponent("/api/pdf/invoice")

        return try await sendPDFRequest(to: endpoint, body: requestBody)
    }

    // MARK: - Trade Statement PDF Generation

    func generateTradeStatementPDF(
        for displayData: TradeStatementDisplayData,
        trade: TradeOverviewItem
    ) async throws -> Data {
        logger.info("Generating trade statement PDF via backend: Trade #\(trade.tradeNumber)")

        let requestBody = TradeStatementPDFRequest(from: displayData, trade: trade)
        let endpoint = baseURL.appendingPathComponent("/api/pdf/trade-statement")

        return try await sendPDFRequest(to: endpoint, body: requestBody)
    }

    // MARK: - Credit Note PDF Generation

    func generateCreditNotePDF(from invoice: Invoice) async throws -> Data {
        logger.info("Generating credit note PDF via backend: \(invoice.invoiceNumber)")

        let requestBody = CreditNotePDFRequest(from: invoice)
        let endpoint = baseURL.appendingPathComponent("/api/pdf/credit-note")

        return try await sendPDFRequest(to: endpoint, body: requestBody)
    }

    // MARK: - Account Statement PDF Generation

    func generateAccountStatementPDF(
        statementNumber: String,
        customerInfo: CustomerInfo,
        period: String,
        entries: [AccountStatementEntry],
        openingBalance: Double,
        closingBalance: Double
    ) async throws -> Data {
        logger.info("Generating account statement PDF via backend: \(statementNumber)")

        let requestBody = AccountStatementPDFRequest(
            statementNumber: statementNumber,
            customerInfo: customerInfo,
            period: period,
            entries: entries,
            openingBalance: openingBalance,
            closingBalance: closingBalance
        )
        let endpoint = baseURL.appendingPathComponent("/api/pdf/account-statement")

        return try await sendPDFRequest(to: endpoint, body: requestBody)
    }

    // MARK: - Private Methods

    private func sendPDFRequest<T: Encodable>(to url: URL, body: T) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/pdf", forHTTPHeaderField: "Accept")

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw PDFBackendError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            logger.error("PDF generation failed with status \(httpResponse.statusCode): \(errorMessage)")
            throw PDFBackendError.serverError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        guard httpResponse.mimeType == "application/pdf" else {
            throw PDFBackendError.invalidContentType(httpResponse.mimeType ?? "unknown")
        }

        logger.info("PDF generated successfully, size: \(data.count) bytes")
        return data
    }
}

// MARK: - PDF Backend Errors

enum PDFBackendError: Error, LocalizedError {
    case invalidResponse
    case serverError(statusCode: Int, message: String)
    case invalidContentType(String)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from PDF service"
        case let .serverError(statusCode, message):
            return "PDF service error (\(statusCode)): \(message)"
        case let .invalidContentType(contentType):
            return "Unexpected content type: \(contentType)"
        case .encodingError:
            return "Failed to encode request data"
        }
    }
}

// MARK: - Company Info DTO (from LegalIdentity)

/// Company information sent to backend for PDF header
/// Uses values from LegalIdentity and CompanyContactInfo
private struct CompanyInfoDTO: Encodable {
    let name: String
    let address: String
    let city: String
    let email: String
    let phone: String
    let website: String
    let businessHours: String
    let registerNumber: String
    let vatId: String
    let management: String
    let bankName: String
    let bankIban: String
    let bankBic: String

    /// Creates company info from LegalIdentity (reads from Bundle/Info.plist)
    static func fromLegalIdentity() -> CompanyInfoDTO {
        CompanyInfoDTO(
            name: CompanyContactInfo.companyName,
            address: CompanyContactInfo.address,
            city: CompanyContactInfo.city,
            email: CompanyContactInfo.email,
            phone: CompanyContactInfo.phone,
            website: CompanyContactInfo.website,
            businessHours: CompanyContactInfo.businessHours,
            registerNumber: CompanyContactInfo.registerNumber,
            vatId: CompanyContactInfo.vatId,
            management: "Geschäftsführung: \(CompanyContactInfo.management)",
            bankName: CompanyContactInfo.bankName,
            bankIban: CompanyContactInfo.bankIBAN,
            bankBic: CompanyContactInfo.bic
        )
    }
}

// MARK: - Request DTOs

/// Request body for invoice PDF generation
private struct InvoicePDFRequest: Encodable {
    let invoiceNumber: String
    let invoiceType: String
    let customerInfo: CustomerInfoDTO
    let items: [InvoiceItemDTO]
    let subtotal: Double
    let totalTax: Double
    let totalAmount: Double
    let createdAt: String?
    let tradeId: String?
    let tradeNumber: Int?
    let orderId: String?
    let transactionType: String?
    let taxNote: String?
    let legalNote: String?
    let companyInfo: CompanyInfoDTO

    init(from invoice: Invoice) {
        self.invoiceNumber = invoice.invoiceNumber
        self.invoiceType = invoice.type.rawValue
        self.customerInfo = CustomerInfoDTO(from: invoice.customerInfo)
        self.items = invoice.items.map { InvoiceItemDTO(from: $0) }
        self.subtotal = invoice.subtotal
        self.totalTax = invoice.totalTax
        self.totalAmount = invoice.totalAmount
        self.createdAt = ISO8601DateFormatter().string(from: invoice.createdAt)
        self.tradeId = invoice.tradeId
        self.tradeNumber = invoice.tradeNumber
        self.orderId = invoice.orderId
        self.transactionType = invoice.transactionType?.rawValue
        self.taxNote = invoice.taxNote
        self.legalNote = invoice.legalNote
        self.companyInfo = CompanyInfoDTO.fromLegalIdentity()
    }
}

/// Request body for trade statement PDF generation
private struct TradeStatementPDFRequest: Encodable {
    let tradeNumber: Int
    let depotNumber: String
    let depotHolder: String
    let securityIdentifier: String
    let accountNumber: String
    let buyTransaction: BuyTransactionDTO?
    let sellTransactions: [SellTransactionDTO]
    let calculationBreakdown: CalculationBreakdownDTO
    let taxSummary: TaxSummaryDTO
    let legalDisclaimer: String
    let companyInfo: CompanyInfoDTO

    init(from displayData: TradeStatementDisplayData, trade: TradeOverviewItem) {
        self.tradeNumber = trade.tradeNumber
        self.depotNumber = displayData.depotNumber
        self.depotHolder = displayData.depotHolder
        self.securityIdentifier = displayData.securityIdentifier
        self.accountNumber = displayData.accountNumber
        self.buyTransaction = displayData.buyTransaction.map { BuyTransactionDTO(from: $0) }
        self.sellTransactions = displayData.sellTransactions.map { SellTransactionDTO(from: $0) }
        self.calculationBreakdown = CalculationBreakdownDTO(from: displayData.calculationBreakdown)
        self.taxSummary = TaxSummaryDTO(from: displayData.taxSummary)
        self.legalDisclaimer = displayData.legalDisclaimer
        self.companyInfo = CompanyInfoDTO.fromLegalIdentity()
    }
}

/// Request body for credit note PDF generation
private struct CreditNotePDFRequest: Encodable {
    let creditNoteNumber: String
    let customerInfo: CustomerInfoDTO
    let items: [InvoiceItemDTO]
    let totalAmount: Double
    let reason: String
    let originalInvoiceNumber: String?
    let createdAt: String?
    let companyInfo: CompanyInfoDTO

    init(from invoice: Invoice) {
        self.creditNoteNumber = invoice.invoiceNumber
        self.customerInfo = CustomerInfoDTO(from: invoice.customerInfo)
        self.items = invoice.items.map { InvoiceItemDTO(from: $0) }
        self.totalAmount = invoice.totalAmount
        self.reason = invoice.legalNote ?? ""
        self.originalInvoiceNumber = nil
        self.createdAt = ISO8601DateFormatter().string(from: invoice.createdAt)
        self.companyInfo = CompanyInfoDTO.fromLegalIdentity()
    }
}

/// Request body for account statement PDF generation
private struct AccountStatementPDFRequest: Encodable {
    let statementNumber: String
    let customerInfo: CustomerInfoDTO
    let statementPeriod: String
    let entries: [AccountStatementEntryDTO]
    let openingBalance: Double
    let closingBalance: Double
    let createdAt: String?
    let companyInfo: CompanyInfoDTO

    init(
        statementNumber: String,
        customerInfo: CustomerInfo,
        period: String,
        entries: [AccountStatementEntry],
        openingBalance: Double,
        closingBalance: Double
    ) {
        self.statementNumber = statementNumber
        self.customerInfo = CustomerInfoDTO(from: customerInfo)
        self.statementPeriod = period
        self.entries = entries.map { AccountStatementEntryDTO(from: $0) }
        self.openingBalance = openingBalance
        self.closingBalance = closingBalance
        self.createdAt = ISO8601DateFormatter().string(from: Date())
        self.companyInfo = CompanyInfoDTO.fromLegalIdentity()
    }
}

// MARK: - DTO Types

private struct CustomerInfoDTO: Encodable {
    let name: String
    let address: String
    let city: String
    let postalCode: String
    let taxNumber: String
    let customerNumber: String
    let depotNumber: String
    let bank: String

    init(from info: CustomerInfo) {
        self.name = info.name
        self.address = info.address
        self.city = info.city
        self.postalCode = info.postalCode
        self.taxNumber = info.taxNumber
        self.customerNumber = info.customerNumber
        self.depotNumber = info.depotNumber
        self.bank = info.bank
    }
}

private struct InvoiceItemDTO: Encodable {
    let description: String
    let quantity: Double
    let unitPrice: Double
    let totalAmount: Double
    let itemType: String

    init(from item: InvoiceItem) {
        self.description = item.description
        self.quantity = item.quantity
        self.unitPrice = item.unitPrice
        self.totalAmount = item.totalAmount
        self.itemType = item.itemType.rawValue
    }
}

private struct BuyTransactionDTO: Encodable {
    let transactionNumber: String
    let orderVolume: String
    let executedVolume: String
    let price: String
    let marketValue: String
    let commission: String
    let ownExpenses: String
    let externalExpenses: String
    let finalAmount: String

    init(from data: BuyTransactionData) {
        self.transactionNumber = data.transactionNumber
        self.orderVolume = data.orderVolume
        self.executedVolume = data.executedVolume
        self.price = data.price
        self.marketValue = data.marketValue
        self.commission = data.commission
        self.ownExpenses = data.ownExpenses
        self.externalExpenses = data.externalExpenses
        self.finalAmount = data.finalAmount
    }
}

private struct SellTransactionDTO: Encodable {
    let transactionNumber: String
    let orderVolume: String
    let price: String
    let marketValue: String
    let commission: String
    let finalAmount: String

    init(from data: SellTransactionData) {
        self.transactionNumber = data.transactionNumber
        self.orderVolume = data.orderVolume
        self.price = data.price
        self.marketValue = data.marketValue
        self.commission = data.commission
        self.finalAmount = data.finalAmount
    }
}

private struct CalculationBreakdownDTO: Encodable {
    let totalSellAmount: String
    let buyAmount: String
    let resultBeforeTaxes: String

    init(from data: CalculationBreakdownData) {
        self.totalSellAmount = data.totalSellAmount
        self.buyAmount = data.buyAmount
        self.resultBeforeTaxes = data.resultBeforeTaxes
    }
}

private struct TaxSummaryDTO: Encodable {
    let assessmentBasis: String
    let totalTax: String
    let netResult: String

    init(from data: TaxSummaryData) {
        self.assessmentBasis = data.assessmentBasis
        self.totalTax = data.totalTax
        self.netResult = data.netResult
    }
}

private struct AccountStatementEntryDTO: Encodable {
    let date: String
    let description: String
    let category: String
    let amount: Double
    let direction: String
    let balanceAfter: Double?

    init(from entry: AccountStatementEntry) {
        self.date = ISO8601DateFormatter().string(from: entry.occurredAt)
        self.description = entry.title
        self.category = entry.category.rawValue
        self.amount = entry.amount
        self.direction = entry.direction.rawValue
        self.balanceAfter = entry.balanceAfter
    }
}
