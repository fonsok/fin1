import Foundation
import OSLog

// MARK: - PDF Backend Service Protocol

/// Protocol for backend PDF generation service
protocol PDFBackendServiceProtocol: Sendable {
    /// Generates an invoice PDF from the backend
    func generateInvoicePDF(from invoice: Invoice) async throws -> Data

    /// Generates a trade statement PDF from the backend (`tradeNumber` only; avoids non-Sendable `TradeOverviewItem` crossing actor boundaries).
    func generateTradeStatementPDF(
        for displayData: TradeStatementDisplayData,
        tradeNumber: Int
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
actor PDFBackendService: PDFBackendServiceProtocol {

    // MARK: - Properties

    let logger = Logger(subsystem: "com.fin1.app", category: "PDFBackendService")
    let baseURL: URL
    let session: URLSession

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
        tradeNumber: Int
    ) async throws -> Data {
        logger.info("Generating trade statement PDF via backend: Trade #\(tradeNumber)")

        let requestBody = TradeStatementPDFRequest(from: displayData, tradeNumber: tradeNumber)
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

    // MARK: - Request Sending

    func sendPDFRequest<T: Encodable>(to url: URL, body: T) async throws -> Data {
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

