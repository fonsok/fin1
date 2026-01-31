import Foundation

// MARK: - Invoice Display Models
/// Clean display models that separate data from presentation logic

struct InvoiceDisplayData {
    let header: String
    let items: [InvoiceItemDisplayData]
    let totals: InvoiceTotalsDisplayData
}

struct InvoiceItemDisplayData: Identifiable {
    let id: String
    let description: String
    let quantity: String
    let unitPrice: String
    let total: String
    let itemType: InvoiceItemType
}

struct InvoiceTotalsDisplayData {
    let subtotal: String
    let tax: String
    let total: String
}

// MARK: - Invoice Header Display Data
struct InvoiceHeaderDisplayData {
    let transactionType: String
    let invoiceNumber: String
    let status: String
    let createdDate: String
    let dueDate: String?
}

// MARK: - Customer Info Display Data
struct CustomerInfoDisplayData {
    let name: String
    let address: String
    let city: String
    let taxNumber: String
    let customerNumber: String
}
