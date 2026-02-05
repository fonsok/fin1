import Foundation
import SwiftUI
import Combine

// MARK: - Invoice Service Implementation
/// Handles invoice operations, PDF generation, and management
final class InvoiceService: InvoiceServiceProtocol, ServiceLifecycle {
    @Published var invoices: [Invoice] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var cancellables = Set<AnyCancellable>()
    private let pdfGenerator = PDFGenerator()
    private let transactionIdService: any TransactionIdServiceProtocol
    private let parseAPIClient: (any ParseAPIClientProtocol)?

    init(
        transactionIdService: any TransactionIdServiceProtocol = TransactionIdService(),
        parseAPIClient: (any ParseAPIClientProtocol)? = nil
    ) {
        self.transactionIdService = transactionIdService
        self.parseAPIClient = parseAPIClient
        // Don't load mock invoices - they will be generated from actual trades
    }

    // MARK: - ServiceLifecycle

    func start() {
        // Invoices will be generated automatically when trades complete
        // No need to preload mock data
    }

    func stop() {
        // Clean up any ongoing operations
    }

    func reset() {
        invoices.removeAll()
        errorMessage = nil
    }

    // MARK: - Invoice Management

    func loadInvoices(for userId: String) async throws {
        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 800_000_000) // 0.8 seconds

        await MainActor.run {
            self.isLoading = false
            // In a real app, this would load from API
            self.loadMockInvoices()
        }
    }

    func createInvoice(from order: OrderBuy, customerInfo: CustomerInfo) async throws -> Invoice {
        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

        let invoice = Invoice.from(order: order, customerInfo: customerInfo, transactionIdService: transactionIdService)

        await MainActor.run {
            self.invoices.append(invoice)
            self.isLoading = false
        }

        return invoice
    }

    func createInvoice(from sellOrder: OrderSell, customerInfo: CustomerInfo) async throws -> Invoice {
        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 600_000_000) // 0.6 seconds

        let invoice = Invoice.from(sellOrder: sellOrder, customerInfo: customerInfo, transactionIdService: transactionIdService)

        await MainActor.run {
            self.invoices.append(invoice)
            self.isLoading = false
        }

        return invoice
    }

    func addInvoice(_ invoice: Invoice) async {
        // Save to backend if it's a service charge invoice and ParseAPIClient is available
        if invoice.type == .platformServiceCharge, let apiClient = parseAPIClient {
            await saveServiceChargeInvoiceToBackend(invoice, apiClient: apiClient)
        }

        await MainActor.run {
            self.invoices.append(invoice)
            // Post notification so ViewModels can refresh
            NotificationCenter.default.post(
                name: .invoiceDidChange,
                object: nil,
                userInfo: ["invoiceId": invoice.id, "invoiceType": invoice.type.rawValue]
            )
        }
    }

    // MARK: - Backend Integration
    // Note: Backend integration methods are in InvoiceService+Backend.swift extension

    func updateInvoiceStatus(_ invoice: Invoice, status: InvoiceStatus) async throws {
        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds

        await MainActor.run {
            if let index = self.invoices.firstIndex(where: { $0.id == invoice.id }) {
                let updatedInvoice = Invoice(
                    id: invoice.id,
                    invoiceNumber: invoice.invoiceNumber,
                    type: invoice.type,
                    status: status,
                    customerInfo: invoice.customerInfo,
                    items: invoice.items,
                    tradeId: invoice.tradeId,
                    orderId: invoice.orderId,
                    taxNote: invoice.taxNote,
                    legalNote: invoice.legalNote,
                    dueDate: invoice.dueDate
                )
                self.invoices[index] = updatedInvoice
            }
            self.isLoading = false
        }
    }

    func deleteInvoice(_ invoice: Invoice) async throws {
        await MainActor.run {
            isLoading = true
        }

        // Simulate API call
        try await Task.sleep(nanoseconds: 400_000_000) // 0.4 seconds

        await MainActor.run {
            self.invoices.removeAll { $0.id == invoice.id }
            self.isLoading = false
        }
    }

    // MARK: - PDF Generation

    func generatePDF(for invoice: Invoice) async throws -> Data {
        await MainActor.run {
            isLoading = true
        }

        do {
            // Simulate PDF generation time
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

            print("🔧 DEBUG: Starting PDF generation for invoice: \(invoice.formattedInvoiceNumber)")

            let pdfData = PDFGenerator.generatePDF(from: invoice)

            print("🔧 DEBUG: PDF generation completed. Data size: \(pdfData.count) bytes")

            // Check if PDF data is empty (generation failed)
            if pdfData.isEmpty {
                print("❌ DEBUG: PDF generation returned empty data")
                throw AppError.serviceError(.operationFailed)
            }

            await MainActor.run {
                self.isLoading = false
            }

            return pdfData
        } catch {
            print("❌ DEBUG: PDF generation failed with error: \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
            throw AppError.serviceError(.operationFailed)
        }
    }

    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage {
        await MainActor.run {
            isLoading = true
        }

        // Simulate preview generation time
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

        guard let preview = PDFGenerator.generatePreview(from: invoice) else {
            throw AppError.invoiceGenerationFailed
        }

        await MainActor.run {
            self.isLoading = false
        }

        return preview
    }

    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL {
        // Save to Documents folder for sharing
        return try await PDFDownloadService.savePDFToDocuments(pdfData, fileName: fileName, fileExtension: "pdf")
    }

    // MARK: - Invoice Queries

    func getInvoices(for userId: String) -> [Invoice] {
        return invoices.filter { $0.customerInfo.customerNumber == userId }
    }

    func getInvoicesByType(_ type: InvoiceType, for userId: String) -> [Invoice] {
        return invoices.filter {
            $0.type == type && $0.customerInfo.customerNumber == userId
        }
    }

    func getInvoice(by id: String) -> Invoice? {
        return invoices.first { $0.id == id }
    }

    func getInvoicesForTrade(_ tradeId: String) -> [Invoice] {
        return invoices.filter { $0.tradeId == tradeId }
    }

    func getServiceChargeInvoiceForBatch(_ batchId: String, userId: String) -> Invoice? {
        return getInvoicesByType(.platformServiceCharge, for: userId)
            .first { $0.tradeId == batchId }
    }

    // MARK: - Invoice Validation

    func validateInvoice(_ invoice: Invoice) -> Bool {
        // Check if invoice has required fields
        guard !invoice.invoiceNumber.isEmpty,
              !invoice.customerInfo.name.isEmpty,
              !invoice.items.isEmpty else {
            return false
        }

        // Check if total amount is positive
        guard invoice.totalAmount > 0 else {
            return false
        }

        // Check if all items are valid
        for item in invoice.items {
            guard item.quantity > 0,
                  item.unitPrice >= 0,
                  item.totalAmount >= 0 else {
                return false
            }
        }

        return true
    }

    func validateCustomerInfo(_ customerInfo: CustomerInfo) -> Bool {
        // Check if all required customer fields are present
        guard !customerInfo.name.isEmpty,
              !customerInfo.address.isEmpty,
              !customerInfo.city.isEmpty,
              !customerInfo.postalCode.isEmpty,
              !customerInfo.taxNumber.isEmpty,
              !customerInfo.depotNumber.isEmpty,
              !customerInfo.bank.isEmpty,
              !customerInfo.customerNumber.isEmpty else {
            return false
        }

        // Validate postal code format (German format)
        let postalCodeRegex = "^[0-9]{5}$"
        let postalCodePredicate = NSPredicate(format: "SELF MATCHES %@", postalCodeRegex)
        guard postalCodePredicate.evaluate(with: customerInfo.postalCode) else {
            return false
        }

        return true
    }

    // MARK: - Private Methods

    private func loadMockInvoices() {
        // Invoices are now generated automatically when trades complete
        // No need for mock invoices - they will be created dynamically
        invoices = []
    }

    /// Generate invoices for all existing completed trades (backfill)
    func generateInvoicesForCompletedTrades(_ trades: [Trade]) async {
        print("📄 Generating invoices for \(trades.count) completed trades...")

        for trade in trades where trade.status == .completed {
            // CRITICAL: Use trade.traderId as customer number for proper trader isolation
            // This ensures invoices are tied to the specific trader who owns the trade
            let customerInfo = CustomerInfo(
                name: "Dr. Hans-Peter Müller",
                address: "Hauptstraße 42",
                city: "Frankfurt am Main",
                postalCode: "60311",
                taxNumber: "43/123/45678",
                depotNumber: "DE12345678901234567890",
                bank: "Deutsche Bank AG",
                customerNumber: trade.traderId  // Use trader ID for proper isolation
            )

            // Check if invoices already exist for this trade
            let existingInvoices = invoices.filter { $0.tradeId == trade.id }
            let hasBuyInvoice = existingInvoices.contains { $0.transactionType == .buy }
            // Create buy invoice if missing
            if !hasBuyInvoice {
                let buyInvoice = Invoice.from(
                    order: trade.buyOrder,
                    customerInfo: customerInfo,
                    transactionIdService: transactionIdService,
                    tradeId: trade.id,
                    tradeNumber: trade.tradeNumber
                )
                await addInvoice(buyInvoice)
            }

            // Create sell invoices for each sell order
            // Handle multiple sell orders (partial sales)
            for sellOrder in trade.sellOrders {
                // Check if invoice already exists for this specific order
                let invoiceExists = existingInvoices.contains { $0.orderId == sellOrder.id }

                if !invoiceExists {
                    let sellInvoice = Invoice.from(
                        sellOrder: sellOrder,
                        customerInfo: customerInfo,
                        transactionIdService: transactionIdService,
                        tradeId: trade.id,
                        tradeNumber: trade.tradeNumber
                    )
                    await addInvoice(sellInvoice)
                }
            }

            // Handle legacy single sell order (backward compatibility)
            if let sellOrder = trade.sellOrder, trade.sellOrders.isEmpty {
                let invoiceExists = existingInvoices.contains { $0.orderId == sellOrder.id }

                if !invoiceExists {
                    let sellInvoice = Invoice.from(
                        sellOrder: sellOrder,
                        customerInfo: customerInfo,
                        transactionIdService: transactionIdService,
                        tradeId: trade.id,
                        tradeNumber: trade.tradeNumber
                    )
                    await addInvoice(sellInvoice)
                }
            }
        }

        print("📄 Invoice generation complete. Total invoices: \(invoices.count)")
    }

    private func handleError(_ error: Error) async {
        await MainActor.run {
            let appError = error.toAppError()
            self.errorMessage = appError.errorDescription ?? "An error occurred"
            self.showError = true
            self.isLoading = false
        }
    }
}

// MARK: - AppError Extension

extension AppError {
    static let invoiceGenerationFailed = AppError.serviceError(.operationFailed)
    static let pdfGenerationFailed = AppError.serviceError(.operationFailed)
    static let invalidInvoiceData = AppError.validationError("Invalid invoice data")
    static let invalidCustomerInfo = AppError.validationError("Invalid customer information")
}
