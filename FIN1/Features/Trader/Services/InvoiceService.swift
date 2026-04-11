import Foundation
import SwiftUI
import Combine

// MARK: - Invoice Service Implementation
/// Handles invoice CRUD, queries, validation, and backend sync. PDF generation/export is delegated to InvoicePDFService.
final class InvoiceService: InvoiceServiceProtocol, ServiceLifecycle {
    @Published var invoices: [Invoice] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var cancellables = Set<AnyCancellable>()
    let transactionIdService: any TransactionIdServiceProtocol
    private let pdfService: any InvoicePDFServiceProtocol
    private let parseAPIClient: (any ParseAPIClientProtocol)?
    private var invoiceAPIService: InvoiceAPIServiceProtocol?

    init(
        transactionIdService: any TransactionIdServiceProtocol = TransactionIdService(),
        parseAPIClient: (any ParseAPIClientProtocol)? = nil,
        pdfService: (any InvoicePDFServiceProtocol)? = nil
    ) {
        self.transactionIdService = transactionIdService
        self.parseAPIClient = parseAPIClient
        self.pdfService = pdfService ?? InvoicePDFService()
    }

    /// Configures the invoice API service for backend synchronization
    func configure(invoiceAPIService: InvoiceAPIServiceProtocol) {
        self.invoiceAPIService = invoiceAPIService
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

        // Try loading from backend first
        if let apiService = invoiceAPIService {
            do {
                let backendInvoices = try await apiService.fetchInvoices(for: userId)
                await MainActor.run {
                    // Merge: backend invoices take precedence, keep local-only invoices that aren't on backend yet
                    let backendIds = Set(backendInvoices.map(\.invoiceNumber))
                    let localOnly = self.invoices.filter { !backendIds.contains($0.invoiceNumber) && $0.id.count == 36 }
                    self.invoices = backendInvoices + localOnly
                    self.isLoading = false
                }
                print("✅ InvoiceService: Loaded \(backendInvoices.count) invoices from backend")
                return
            } catch {
                print("⚠️ InvoiceService: Failed to load invoices from backend: \(error.localizedDescription)")
            }
        }

        await MainActor.run {
            self.isLoading = false
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
        // Write-through: Sync immediately if API service available
        if let apiService = invoiceAPIService {
            do {
                let syncedInvoice = try await apiService.saveInvoice(invoice)
                await MainActor.run {
                    self.invoices.append(syncedInvoice)
                    // Post notification so ViewModels can refresh
                    NotificationCenter.default.post(
                        name: .invoiceDidChange,
                        object: nil,
                        userInfo: ["invoiceId": syncedInvoice.id, "invoiceType": syncedInvoice.type.rawValue]
                    )
                }
                return
            } catch {
                print("⚠️ InvoiceService: Failed to sync invoice immediately: \(error.localizedDescription)")
                // Fall through to local storage + legacy service charge sync
            }
        }

        // Fallback: Legacy service charge invoice sync (for backward compatibility)
        if invoice.type == .appServiceCharge, let apiClient = parseAPIClient {
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

    // MARK: - Backend Synchronization

    /// Syncs pending invoices to the backend
    func syncToBackend() async {
        guard let apiService = invoiceAPIService else {
            print("⚠️ InvoiceService: No API service configured, skipping sync")
            return
        }

        print("📤 InvoiceService: Syncing pending invoices to backend...")

        // Sync pending invoices (without Parse objectId or with local- prefix)
        let pendingInvoices = invoices.filter { invoice in
            invoice.id.starts(with: "local-") ||
            !invoice.id.contains("-") || // UUID without Parse objectId format
            invoice.id.count == 36 // Standard UUID format (not Parse objectId)
        }

        print("📤 InvoiceService: Found \(pendingInvoices.count) pending invoices to sync")

        for invoice in pendingInvoices {
            do {
                let syncedInvoice = try await apiService.saveInvoice(invoice)

                // Update local invoice with Parse objectId
                await MainActor.run {
                    if let index = self.invoices.firstIndex(where: { $0.id == invoice.id }) {
                        self.invoices[index] = syncedInvoice
                    }
                }

                print("✅ InvoiceService: Synced invoice \(invoice.invoiceNumber)")
            } catch {
                print("⚠️ InvoiceService: Failed to sync invoice \(invoice.invoiceNumber): \(error.localizedDescription)")
            }
        }

        print("✅ InvoiceService: Background sync completed")
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

    // MARK: - PDF Generation (delegated to InvoicePDFService)

    func generatePDF(for invoice: Invoice) async throws -> Data {
        await MainActor.run { isLoading = true }
        do {
            let data = try await pdfService.generatePDF(for: invoice)
            await MainActor.run { isLoading = false }
            return data
        } catch {
            await MainActor.run { isLoading = false }
            throw AppError.serviceError(.operationFailed)
        }
    }

    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage {
        await MainActor.run { isLoading = true }
        do {
            let image = try await pdfService.generatePDFPreview(for: invoice)
            await MainActor.run { isLoading = false }
            return image
        } catch {
            await MainActor.run { isLoading = false }
            throw error
        }
    }

    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL {
        try await pdfService.savePDFToDocuments(pdfData, fileName: fileName)
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
        return getInvoicesByType(.appServiceCharge, for: userId)
            .first { $0.tradeId == batchId }
    }

    // MARK: - Private Methods

    private func loadMockInvoices() {
        // Invoices are now generated automatically when trades complete
        // No need for mock invoices - they will be created dynamically
        invoices = []
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
