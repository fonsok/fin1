import Foundation
import SwiftUI
import Combine

// MARK: - Invoice ViewModel
/// Manages invoice state and business logic following MVVM pattern
@MainActor
final class InvoiceViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var invoices: [Invoice] = []
    @Published var selectedInvoice: Invoice?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false
    @Published var showPDFPreview = false
    @Published var pdfPreviewImage: UIImage?
    @Published var isGeneratingPDF = false
    @Published var pdfGenerationProgress: Double = 0.0

    // MARK: - Private Properties

    let invoiceService: any InvoiceServiceProtocol
    let notificationService: any NotificationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private let pdfHandler: InvoicePDFHandler
    private let filteringHelper: InvoiceFilteringHelper

    // MARK: - Initialization

    init(invoiceService: any InvoiceServiceProtocol, notificationService: any NotificationServiceProtocol) {
        self.invoiceService = invoiceService
        self.notificationService = notificationService
        self.pdfHandler = InvoicePDFHandler(
            invoiceService: invoiceService,
            notificationService: notificationService
        )
        self.filteringHelper = InvoiceFilteringHelper()

        setupBindings()
    }

    // MARK: - Public Methods

    /// Loads all invoices for the current user
    func loadInvoices(for userId: String) {
        Task {
            await MainActor.run {
                self.isLoading = true
            }
            do {
                try await invoiceService.loadInvoices(for: userId)
                // Sync invoices from service after loading
                await MainActor.run {
                    // Get invoices from service and filter by user ID
                    let serviceInvoices = invoiceService.getInvoices(for: userId)
                    self.invoices = serviceInvoices
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                handleError(error)
            }
        }
    }

    /// Refreshes invoices from the service (useful when invoices are added externally)
    func refreshInvoices(for userId: String) {
        Task {
            await MainActor.run {
                // Get all invoices from service and filter by user ID
                let serviceInvoices = invoiceService.getInvoices(for: userId)
                self.invoices = serviceInvoices
            }
        }
    }

    /// Creates a new invoice from an order
    func createInvoice(from order: OrderBuy, customerInfo: CustomerInfo) {
        Task {
            do {
                let invoice = try await invoiceService.createInvoice(from: order, customerInfo: customerInfo)
                await MainActor.run {
                    self.invoices.append(invoice)
                    self.selectedInvoice = invoice
                }
            } catch {
                handleError(error)
            }
        }
    }

    /// Updates the status of an invoice
    func updateInvoiceStatus(_ invoice: Invoice, status: InvoiceStatus) {
        Task {
            do {
                try await invoiceService.updateInvoiceStatus(invoice, status: status)
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
                            dueDate: invoice.dueDate,
                            traderCommissionRateSnapshot: invoice.traderCommissionRateSnapshot
                        )
                        self.invoices[index] = updatedInvoice
                        self.selectedInvoice = updatedInvoice
                    }
                }
            } catch {
                handleError(error)
            }
        }
    }

    /// Deletes an invoice
    func deleteInvoice(_ invoice: Invoice) {
        Task {
            do {
                try await invoiceService.deleteInvoice(invoice)
                await MainActor.run {
                    self.invoices.removeAll { $0.id == invoice.id }
                    if self.selectedInvoice?.id == invoice.id {
                        self.selectedInvoice = nil
                    }
                }
            } catch {
                handleError(error)
            }
        }
    }

    /// Generates a PDF for the selected invoice
    func generatePDF(for invoice: Invoice) {
        Task {
            await MainActor.run {
                self.isGeneratingPDF = true
                self.pdfGenerationProgress = 0.0
            }

            await pdfHandler.generatePDF(
                for: invoice,
                progressCallback: { progress in
                    Task { @MainActor in
                        self.pdfGenerationProgress = progress
                    }
                },
                completionCallback: {
                    Task { @MainActor in
                        self.isGeneratingPDF = false
                        self.pdfGenerationProgress = 1.0
                    }
                },
                errorCallback: { error in
                    Task { @MainActor in
                        self.isGeneratingPDF = false
                        self.pdfGenerationProgress = 0.0
                        self.handleError(error)
                    }
                }
            )
        }
    }

    /// Creates a shareable PDF URL for use with ShareLink
    /// - Parameter invoice: The invoice to generate PDF for
    /// - Returns: The URL of the PDF file ready for sharing, or nil if generation fails
    func createShareablePDFURL(for invoice: Invoice) async -> URL? {
        let url = await pdfHandler.createShareablePDFURL(for: invoice)
        if url == nil {
            await MainActor.run {
                handleError(AppError.unknown("Failed to generate PDF"))
            }
        }
        return url
    }

    /// Downloads PDF via browser
    func downloadPDFViaBrowser(for invoice: Invoice) {
        Task {
            do {
                try await pdfHandler.downloadPDFViaBrowser(for: invoice)
            } catch {
                await MainActor.run {
                    handleError(error)
                }
            }
        }
    }

    /// Generates a PDF preview for the selected invoice
    func generatePDFPreview(for invoice: Invoice) {
        Task {
            do {
                let preview = try await pdfHandler.generatePDFPreview(for: invoice)
                await MainActor.run {
                    self.pdfPreviewImage = preview
                    self.showPDFPreview = true
                }
            } catch {
                handleError(error)
            }
        }
    }

    /// Filters invoices by type
    func filterInvoices(by type: InvoiceType?) -> [Invoice] {
        filteringHelper.filterInvoices(invoices, by: type)
    }

    /// Searches invoices by invoice number or customer name
    func searchInvoices(query: String) -> [Invoice] {
        filteringHelper.searchInvoices(invoices, query: query)
    }

    /// Filters and searches invoices (combines both operations)
    func filteredInvoices(searchQuery: String, filterType: InvoiceType?) -> [Invoice] {
        filteringHelper.filteredInvoices(invoices, searchQuery: searchQuery, filterType: filterType)
    }

    // MARK: - Formatting Methods

    /// Formats invoice number for display
    func formattedInvoiceNumber(for invoice: Invoice) -> String {
        invoice.formattedInvoiceNumber
    }

    /// Formats total amount for display
    func formattedTotalAmount(for invoice: Invoice) -> String {
        invoice.formattedTotalAmount
    }

    /// Gets invoices for a specific trade
    func getInvoicesForTrade(_ tradeId: String) -> [Invoice] {
        return invoiceService.getInvoicesForTrade(tradeId)
    }

    /// Validates customer information
    func validateCustomerInfo(_ customerInfo: CustomerInfo) -> Bool {
        return invoiceService.validateCustomerInfo(customerInfo)
    }

    /// Validates an invoice
    func validateInvoice(_ invoice: Invoice) -> Bool {
        return invoiceService.validateInvoice(invoice)
    }

    /// Clears error message
    func clearError() {
        errorMessage = nil
        showError = false
    }

    /// Dismisses PDF preview
    func dismissPDFPreview() {
        showPDFPreview = false
        pdfPreviewImage = nil
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Observe invoice changes via notifications
        NotificationCenter.default.publisher(for: .invoiceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Refresh invoices when a new one is added
                // We'll need the user ID to filter - this will be handled by the view
                print("📄 InvoiceViewModel: Received invoice change notification")
                _ = self // Acknowledge self capture for weak reference
            }
            .store(in: &cancellables)
    }

    private func handleError(_ error: Error) {
        let appError = error.toAppError()
        errorMessage = appError.errorDescription ?? "An error occurred"
        showError = true
        isLoading = false
        isGeneratingPDF = false
        pdfGenerationProgress = 0.0
    }

}

// MARK: - Computed Properties

extension InvoiceViewModel {

    /// Returns the total number of invoices
    var totalInvoices: Int {
        invoices.count
    }

    /// Returns the number of paid invoices
    var paidInvoicesCount: Int {
        invoices.filter { $0.isPaid }.count
    }

    /// Returns the number of overdue invoices
    var overdueInvoicesCount: Int {
        invoices.filter { $0.isOverdue }.count
    }

    /// Returns the total amount of all invoices
    var totalAmount: Double {
        invoices.reduce(0) { $0 + $1.totalAmount }
    }

    /// Returns the total amount of paid invoices
    var paidAmount: Double {
        invoices.filter { $0.isPaid }.reduce(0) { $0 + $1.totalAmount }
    }

    /// Returns the total amount of outstanding invoices
    var outstandingAmount: Double {
        invoices.filter { !$0.isPaid }.reduce(0) { $0 + $1.totalAmount }
    }

    /// Returns invoices grouped by status
    var invoicesByStatus: [InvoiceStatus: [Invoice]] {
        Dictionary(grouping: invoices) { $0.status }
    }

    /// Returns invoices grouped by type
    var invoicesByType: [InvoiceType: [Invoice]] {
        Dictionary(grouping: invoices) { $0.type }
    }

    /// Returns the most recent invoice
    var mostRecentInvoice: Invoice? {
        invoices.max { $0.createdAt < $1.createdAt }
    }

    /// Returns invoices created in the last 30 days
    var recentInvoices: [Invoice] {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        return invoices.filter { $0.createdAt >= thirtyDaysAgo }
    }
}
