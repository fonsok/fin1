import Foundation

// MARK: - Invoice Filtering Helper

/// Handles invoice filtering and search operations for InvoiceViewModel
/// Separated to reduce main ViewModel file size and improve maintainability
final class InvoiceFilteringHelper {
    /// Filters invoices by type
    func filterInvoices(_ invoices: [Invoice], by type: InvoiceType?) -> [Invoice] {
        guard let type = type else { return invoices }
        return invoices.filter { $0.type == type }
    }

    /// Searches invoices by invoice number or customer name
    func searchInvoices(_ invoices: [Invoice], query: String) -> [Invoice] {
        guard !query.isEmpty else { return invoices }

        return invoices.filter { invoice in
            invoice.invoiceNumber.localizedCaseInsensitiveContains(query) ||
            invoice.customerInfo.name.localizedCaseInsensitiveContains(query) ||
            invoice.customerInfo.customerNumber.localizedCaseInsensitiveContains(query)
        }
    }

    /// Filters and searches invoices (combines both operations)
    func filteredInvoices(
        _ invoices: [Invoice],
        searchQuery: String,
        filterType: InvoiceType?
    ) -> [Invoice] {
        let searchResults = searchInvoices(invoices, query: searchQuery)
        let filtered = filterInvoices(invoices, by: filterType)
        return filtered.filter { invoice in
            searchResults.contains { $0.id == invoice.id }
        }
    }
}







