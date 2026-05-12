import Foundation
import SwiftUI

// MARK: - Invoice Display ViewModel
/// Handles all business logic and data transformation for invoice display
@MainActor
final class InvoiceDisplayViewModel: ObservableObject {

    // MARK: - Published Properties
    @Published var displayData: InvoiceDisplayData?
    @Published var headerData: InvoiceHeaderDisplayData?
    @Published var customerData: CustomerInfoDisplayData?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties
    let invoice: Invoice

    // MARK: - Initialization
    init(invoice: Invoice) {
        self.invoice = invoice
        setupDisplayData()
    }

    // MARK: - Public Methods

    /// Refreshes the display data (useful for dynamic updates)
    func refreshDisplayData() {
        setupDisplayData()
    }

    // MARK: - Private Methods

    private func setupDisplayData() {
        headerData = createHeaderDisplayData()
        customerData = createCustomerDisplayData()
        displayData = createInvoiceDisplayData()
    }

    private func createHeaderDisplayData() -> InvoiceHeaderDisplayData {
        return InvoiceHeaderDisplayData(
            transactionType: invoice.transactionType?.displayName ?? "Unknown",
            invoiceNumber: invoice.formattedInvoiceNumber,
            status: invoice.status.displayName,
            createdDate: invoice.createdAt.formatted(date: .abbreviated, time: .omitted),
            dueDate: invoice.dueDate?.formatted(date: .abbreviated, time: .omitted)
        )
    }

    private func createCustomerDisplayData() -> CustomerInfoDisplayData {
        return CustomerInfoDisplayData(
            name: invoice.customerInfo.name,
            address: invoice.customerInfo.address,
            city: "\(invoice.customerInfo.postalCode) \(invoice.customerInfo.city)",
            taxNumber: invoice.customerInfo.taxNumber,
            customerNumber: invoice.customerInfo.customerNumber
        )
    }

    private func createInvoiceDisplayData() -> InvoiceDisplayData {
        let items = invoice.items.map { createItemDisplayData($0) }
        let totals = createTotalsDisplayData()

        return InvoiceDisplayData(
            header: createTransactionHeader(),
            items: items,
            totals: totals
        )
    }

    private func createTransactionHeader() -> String {
        guard let transactionType = invoice.transactionType else {
            return "Wertpapier"
        }
        return "\(transactionType.displayName) Wertpapier"
    }

    private func createItemDisplayData(_ item: InvoiceItem) -> InvoiceItemDisplayData {
        return InvoiceItemDisplayData(
            id: item.id,
            description: formatItemDescription(item),
            quantity: item.quantity.formattedAsLocalizedNumber(),
            unitPrice: item.unitPrice.formattedAsLocalizedCurrency(),
            total: item.totalAmount.formattedAsLocalizedCurrency(),
            itemType: item.itemType
        )
    }

    private func formatItemDescription(_ item: InvoiceItem) -> String {
        switch item.itemType {
        case .securities:
            // Service-charge invoices have no securities row; skip the WKN/strike
            // parser so we don't render "Unknown - Unknown - Unknown - Unknown" for
            // generic invoices that never had a securities item.
            if invoice.items.contains(where: { $0.itemType == .securities }) {
                return formatSecuritiesDescription(item)
            }
            return item.description
        case .orderFee, .exchangeFee, .foreignCosts, .serviceCharge, .commission, .vat, .tax, .other:
            return item.description
        }
    }

    private func formatSecuritiesDescription(_ item: InvoiceItem) -> String {
        // Extract securities info from the first securities item
        guard let securitiesItem = invoice.items.first(where: { $0.itemType == .securities }) else {
            return item.description
        }

        // Parse the existing description to extract components
        let components = parseSecuritiesDescription(securitiesItem.description)

        // Format according to the requested sequence: WKN/ISIN - direction - underlying - strike price - issuer
        return formatSecuritiesComponents(components)
    }

    private func parseSecuritiesDescription(_ description: String) -> SecuritiesComponents {
        let wkn = extractWKNFromInvoice()
        return SecuritiesComponents(
            wkn: wkn,
            direction: extractDirectionFromInvoice(),
            underlying: extractUnderlyingFromInvoice(),
            strikePrice: extractStrikePriceFromInvoice(),
            issuer: String.emittentName(forWKN: wkn)
        )
    }

    private func formatSecuritiesComponents(_ components: SecuritiesComponents) -> String {
        var parts: [String] = []

        if !components.wkn.isEmpty {
            parts.append(components.wkn)
        }

        if !components.direction.isEmpty {
            parts.append(components.direction)
        }

        if !components.underlying.isEmpty {
            parts.append(components.underlying)
        }

        if !components.strikePrice.isEmpty {
            parts.append(components.strikePrice)
        }

        if !components.issuer.isEmpty {
            parts.append(components.issuer)
        }

        return parts.joined(separator: " - ")
    }

    private func createTotalsDisplayData() -> InvoiceTotalsDisplayData {
        // Subtotal = sum of NET line items (services, fees, securities, ...) excluding
        // separate tax/VAT line items so "Zwischensumme + Steuer = Gesamt" stimmt
        // (sonst würde `.vat`/`.tax` doppelt zählen — siehe service_charge Belege).
        let netItems = invoice.items.filter { $0.itemType != .vat && $0.itemType != .tax }
        let taxItems = invoice.items.filter { $0.itemType == .vat || $0.itemType == .tax }

        let subtotal = netItems.reduce(0) { $0 + $1.totalAmount }
        let tax = taxItems.reduce(0) { $0 + $1.totalAmount }
        let total = subtotal + tax

        return InvoiceTotalsDisplayData(
            subtotal: subtotal.formattedAsLocalizedCurrency(),
            tax: tax.formattedAsLocalizedCurrency(),
            total: total.formattedAsLocalizedCurrency()
        )
    }

    // MARK: - Helper Methods for Data Extraction

    private func extractWKNFromInvoice() -> String {
        // Extract WKN from invoice items - look for securities item
        if let securitiesItem = invoice.items.first(where: { $0.itemType == .securities }) {
            // Parse the description to extract WKN
            let components = securitiesItem.description.components(separatedBy: " - ")
            return components.first ?? "Unknown"
        }
        return "Unknown"
    }

    private func extractDirectionFromInvoice() -> String {
        // Extract direction from invoice items
        if let securitiesItem = invoice.items.first(where: { $0.itemType == .securities }) {
            let components = securitiesItem.description.components(separatedBy: " - ")
            if components.count > 1 {
                return components[1]
            }
        }
        return "Unknown"
    }

    private func extractUnderlyingFromInvoice() -> String {
        // Extract underlying asset from invoice items
        if let securitiesItem = invoice.items.first(where: { $0.itemType == .securities }) {
            let components = securitiesItem.description.components(separatedBy: " - ")
            if components.count > 2 {
                return components[2]
            }
        }
        return "Unknown"
    }

    private func extractStrikePriceFromInvoice() -> String {
        // Extract strike price from invoice items
        if let securitiesItem = invoice.items.first(where: { $0.itemType == .securities }) {
            let components = securitiesItem.description.components(separatedBy: " - ")
            if components.count > 3 {
                return components[3]
            }
        }
        return "Unknown"
    }
}

// MARK: - Supporting Data Structures

private struct SecuritiesComponents {
    let wkn: String
    let direction: String
    let underlying: String
    let strikePrice: String
    let issuer: String
}
