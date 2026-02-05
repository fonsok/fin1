import Foundation
import SwiftUI

// MARK: - Invoice Model

struct Invoice: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let invoiceNumber: String
    let type: InvoiceType
    let status: InvoiceStatus
    let customerInfo: CustomerInfo
    let items: [InvoiceItem]
    let subtotal: Double
    let totalTax: Double
    let totalAmount: Double
    let createdAt: Date
    let dueDate: Date?
    let paidAt: Date?
    let tradeId: String?
    let tradeNumber: Int? // User-friendly trade number (001, 002, 003...)
    let orderId: String?
    let transactionType: TransactionType?

    // Tax information
    let taxNote: String?
    let legalNote: String?

    init(
        id: String = UUID().uuidString,
        invoiceNumber: String,
        type: InvoiceType,
        status: InvoiceStatus = .draft,
        customerInfo: CustomerInfo,
        items: [InvoiceItem],
        tradeId: String? = nil,
        tradeNumber: Int? = nil,
        orderId: String? = nil,
        transactionType: TransactionType? = nil,
        taxNote: String? = nil,
        legalNote: String? = nil,
        dueDate: Date? = nil
    ) {
        self.id = id
        self.invoiceNumber = invoiceNumber
        self.type = type
        self.status = status
        self.customerInfo = customerInfo
        self.items = items
        self.tradeId = tradeId
        self.tradeNumber = tradeNumber
        self.orderId = orderId
        self.transactionType = transactionType
        self.taxNote = taxNote
        self.legalNote = legalNote
        self.dueDate = dueDate

        // Calculate totals
        self.subtotal = items.reduce(0) { $0 + $1.totalAmount }
        self.totalTax = items
            .filter { $0.itemType == .tax }
            .reduce(0) { $0 + $1.totalAmount }
        self.totalAmount = subtotal

        self.createdAt = Date()
        self.paidAt = nil
    }

    // MARK: - Computed Properties

    var formattedInvoiceNumber: String {
        // Display as "Rechnung" instead of the technical invoice number
        return "Rechnung"
    }

    var formattedTradeNumber: String? {
        guard let tradeNumber = tradeNumber else { return nil }
        return String(format: "%03d", tradeNumber)
    }

    var formattedTotalAmount: String {
        totalAmount.formattedAsLocalizedCurrency()
    }

    var formattedSubtotal: String {
        subtotal.formattedAsLocalizedCurrency()
    }

    var formattedTaxAmount: String {
        totalTax.formattedAsLocalizedCurrency()
    }

    var isPaid: Bool {
        status == .paid
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate else { return false }
        return Date() > dueDate && !isPaid
    }

    var daysUntilDue: Int? {
        guard let dueDate = dueDate else { return nil }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: Date(), to: dueDate).day
        return days
    }
}
