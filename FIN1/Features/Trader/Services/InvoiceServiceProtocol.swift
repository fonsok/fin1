import Combine
import Foundation
import SwiftUI

// MARK: - Invoice Service Protocol
/// Defines the contract for invoice operations and PDF generation
protocol InvoiceServiceProtocol: ObservableObject, ServiceLifecycle, Sendable {
    var invoices: [Invoice] { get }
    var isLoading: Bool { get }
    var errorMessage: String? { get }
    var showError: Bool { get }

    // MARK: - Invoice Management
    func loadInvoices(for userId: String) async throws
    func createInvoice(from order: OrderBuy, customerInfo: CustomerInfo) async throws -> Invoice
    func createInvoice(from sellOrder: OrderSell, customerInfo: CustomerInfo) async throws -> Invoice
    func addInvoice(_ invoice: Invoice) async
    func updateInvoiceStatus(_ invoice: Invoice, status: InvoiceStatus) async throws
    func deleteInvoice(_ invoice: Invoice) async throws
    func generateInvoicesForCompletedTrades(_ trades: [Trade]) async

    // MARK: - PDF Generation
    func generatePDF(for invoice: Invoice) async throws -> Data
    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage
    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL

    // MARK: - Invoice Queries
    func getInvoices(for userId: String) -> [Invoice]
    func getInvoicesByType(_ type: InvoiceType, for userId: String) -> [Invoice]
    func getInvoice(by id: String) -> Invoice?
    func getInvoicesForTrade(_ tradeId: String) -> [Invoice]
    /// Resolves structured invoice data for a Parse `Document` when `invoiceData` is nil (hydrate from synced invoices).
    func invoice(matching document: Document) -> Invoice?
    /// Returns the app service charge invoice for an investment batch (invoice.tradeId == batchId).
    func getServiceChargeInvoiceForBatch(_ batchId: String, userId: String) -> Invoice?

    // MARK: - Invoice Validation
    func validateInvoice(_ invoice: Invoice) -> Bool
    func validateCustomerInfo(_ customerInfo: CustomerInfo) -> Bool

    // MARK: - Backend Synchronization
    func syncToBackend() async
}
