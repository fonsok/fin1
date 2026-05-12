import Foundation
import UIKit
import Combine
@testable import FIN1

// MARK: - Mock Invoice Service (Simplified)
/// Simplified mock using closure-based behavior instead of multiple configuration properties
final class MockInvoiceService: InvoiceServiceProtocol, @unchecked Sendable {
    @Published var invoices: [Invoice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false

    // MARK: - Behavior Closures (Simplified Approach)
    /// Closure to handle loadInvoices - defaults to setting invoices from pre-populated array
    var loadInvoicesHandler: ((String) async throws -> Void)?

    /// Closure to handle createInvoice from OrderBuy - defaults to creating simple invoice
    var createInvoiceFromOrderHandler: ((OrderBuy, CustomerInfo) async throws -> Invoice)?

    /// Closure to handle createInvoice from OrderSell - defaults to creating simple invoice
    var createInvoiceFromSellOrderHandler: ((OrderSell, CustomerInfo) async throws -> Invoice)?

    /// Closure to handle updateInvoiceStatus - defaults to updating in-place
    var updateInvoiceStatusHandler: ((Invoice, InvoiceStatus) async throws -> Void)?

    /// Closure to handle deleteInvoice - defaults to removing from array
    var deleteInvoiceHandler: ((Invoice) async throws -> Void)?

    /// Closure to handle generatePDF - defaults to simple mock data
    var generatePDFHandler: ((Invoice) async throws -> Data)?

    /// Closure to handle generatePDFPreview - defaults to system image
    var generatePDFPreviewHandler: ((Invoice) async throws -> UIImage)?

    /// Closure to handle savePDFToDocuments - defaults to temp directory
    var savePDFToDocumentsHandler: ((Data, String) async throws -> URL)?

    // MARK: - Invoice Management

    func loadInvoices(for userId: String) async throws {
        if let handler = loadInvoicesHandler {
            try await handler(userId)
        } else {
            // Default: no-op (invoices already set by test if needed)
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    func createInvoice(from order: OrderBuy, customerInfo: CustomerInfo) async throws -> Invoice {
        if let handler = createInvoiceFromOrderHandler {
            let invoice = try await handler(order, customerInfo)
            await MainActor.run {
                self.invoices.append(invoice)
            }
            return invoice
        } else {
            // Default: create simple invoice
            let invoice = Invoice(
                invoiceNumber: "INV-\(Date().timeIntervalSince1970)",
                type: .securitiesSettlement,
                status: .draft,
                customerInfo: customerInfo,
                items: [],
                tradeId: order.id,
                orderId: order.id,
                dueDate: Date().addingTimeInterval(86400 * 30)
            )
            await MainActor.run {
                self.invoices.append(invoice)
            }
            return invoice
        }
    }

    func createInvoice(from sellOrder: OrderSell, customerInfo: CustomerInfo) async throws -> Invoice {
        if let handler = createInvoiceFromSellOrderHandler {
            let invoice = try await handler(sellOrder, customerInfo)
            await MainActor.run {
                self.invoices.append(invoice)
            }
            return invoice
        } else {
            // Default: create simple invoice
            let invoice = Invoice(
                invoiceNumber: "INV-\(Date().timeIntervalSince1970)",
                type: .securitiesSettlement,
                status: .draft,
                customerInfo: customerInfo,
                items: [],
                tradeId: sellOrder.id,
                orderId: sellOrder.id,
                dueDate: Date().addingTimeInterval(86400 * 30)
            )
            await MainActor.run {
                self.invoices.append(invoice)
            }
            return invoice
        }
    }

    func addInvoice(_ invoice: Invoice) async {
        await MainActor.run {
            self.invoices.append(invoice)
        }
    }

    func updateInvoiceStatus(_ invoice: Invoice, status: InvoiceStatus) async throws {
        if let handler = updateInvoiceStatusHandler {
            try await handler(invoice, status)
        } else {
            // Default: update in-place
            await MainActor.run {
                if let index = self.invoices.firstIndex(where: { $0.id == invoice.id }) {
                    let existing = self.invoices[index]
                    // Create new invoice with updated status
                    let updated = Invoice(
                        id: existing.id,
                        invoiceNumber: existing.invoiceNumber,
                        type: existing.type,
                        status: status,
                        customerInfo: existing.customerInfo,
                        items: existing.items,
                        tradeId: existing.tradeId,
                        tradeNumber: existing.tradeNumber,
                        orderId: existing.orderId,
                        transactionType: existing.transactionType,
                        taxNote: existing.taxNote,
                        legalNote: existing.legalNote,
                        dueDate: existing.dueDate
                    )
                    self.invoices[index] = updated
                }
            }
        }
    }

    func deleteInvoice(_ invoice: Invoice) async throws {
        if let handler = deleteInvoiceHandler {
            try await handler(invoice)
        } else {
            // Default: remove from array
            await MainActor.run {
                self.invoices.removeAll { $0.id == invoice.id }
            }
        }
    }

    func generateInvoicesForCompletedTrades(_ trades: [Trade]) async {
        // Default: no-op
    }

    // MARK: - PDF Generation

    func generatePDF(for invoice: Invoice) async throws -> Data {
        if let handler = generatePDFHandler {
            return try await handler(invoice)
        } else {
            // Default: simple mock data
            return Data("Mock PDF data".utf8)
        }
    }

    func generatePDFPreview(for invoice: Invoice) async throws -> UIImage {
        if let handler = generatePDFPreviewHandler {
            return try await handler(invoice)
        } else {
            // Default: system image
            return UIImage(systemName: "doc.text") ?? UIImage()
        }
    }

    func savePDFToDocuments(_ pdfData: Data, fileName: String) async throws -> URL {
        if let handler = savePDFToDocumentsHandler {
            return try await handler(pdfData, fileName)
        } else {
            // Default: temp directory
            return FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        }
    }

    // MARK: - Invoice Queries

    func getInvoices(for userId: String) -> [Invoice] {
        return invoices.filter { $0.customerInfo.customerNumber == userId }
    }

    func getInvoicesByType(_ type: InvoiceType, for userId: String) -> [Invoice] {
        return invoices.filter { $0.type == type && $0.customerInfo.customerNumber == userId }
    }

    func getInvoice(by id: String) -> Invoice? {
        return invoices.first { $0.id == id }
    }

    func getInvoicesForTrade(_ tradeId: String) -> [Invoice] {
        return invoices.filter { $0.tradeId == tradeId }
    }

    func invoice(matching document: Document) -> Invoice? {
        if let embedded = document.invoiceData { return embedded }
        if let hit = invoices.first(where: { $0.id == document.id }) { return hit }
        if let num = document.accountingDocumentNumber,
           let hit = invoices.first(where: { $0.invoiceNumber == num }) {
            return hit
        }
        if let tradeId = document.tradeId {
            return invoices.first(where: { $0.tradeId == tradeId })
        }
        return nil
    }

    func getServiceChargeInvoiceForBatch(_ batchId: String, userId: String) -> Invoice? {
        // Find invoice where tradeId == batchId and type is platform service charge
        for invoice in invoices {
            if invoice.tradeId == batchId,
               invoice.type == .appServiceCharge,
               invoice.customerInfo.customerNumber == userId {
                return invoice
            }
        }
        return nil
    }

    // MARK: - Invoice Validation

    func validateInvoice(_ invoice: Invoice) -> Bool {
        return !invoice.invoiceNumber.isEmpty && !invoice.items.isEmpty
    }

    func validateCustomerInfo(_ customerInfo: CustomerInfo) -> Bool {
        return !customerInfo.name.isEmpty && !customerInfo.address.isEmpty
    }

    // MARK: - ServiceLifecycle

    func start() {}
    func stop() {}

    func syncToBackend() async {}

    func reset() {
        invoices.removeAll()
        isLoading = false
        errorMessage = nil
        showError = false
        // Reset all handlers
        loadInvoicesHandler = nil
        createInvoiceFromOrderHandler = nil
        createInvoiceFromSellOrderHandler = nil
        updateInvoiceStatusHandler = nil
        deleteInvoiceHandler = nil
        generatePDFHandler = nil
        generatePDFPreviewHandler = nil
        savePDFToDocumentsHandler = nil
    }
}
