import Foundation

// MARK: - Invoice Calculation Extensions

/// Extensions for common invoice calculation patterns to eliminate DRY violations
extension Invoice {

    /// Gets all non-tax items from the invoice (securities, fees, etc.)
    /// Used for profit calculations where taxes should be excluded
    var nonTaxItems: [InvoiceItem] {
        return items.filter { $0.itemType != .tax }
    }

    /// Gets all tax items from the invoice
    /// Used for tax calculations and reporting
    var taxItems: [InvoiceItem] {
        return items.filter { $0.itemType == .tax }
    }

    /// Gets all securities items from the invoice
    /// Used for securities-specific calculations
    var securitiesItems: [InvoiceItem] {
        return items.filter { $0.itemType == .securities }
    }

    /// Gets all fee items from the invoice (order fees, exchange fees, etc.)
    /// Used for fee calculations and reporting
    var feeItems: [InvoiceItem] {
        return items.filter { item in
            item.itemType == .orderFee ||
            item.itemType == .exchangeFee ||
            item.itemType == .foreignCosts
        }
    }

    /// Calculates the total amount of non-tax items
    /// This is the amount used for profit calculations
    var nonTaxTotal: Double {
        return nonTaxItems.reduce(0) { $0 + $1.totalAmount }
    }

    /// Calculates the total amount of tax items
    /// This is the total tax amount for the invoice
    var taxTotal: Double {
        return taxItems.reduce(0) { $0 + abs($1.totalAmount) }
    }

    /// Calculates the total amount of securities items
    /// This is the securities value for the invoice
    var securitiesTotal: Double {
        return securitiesItems.reduce(0) { $0 + $1.totalAmount }
    }

    /// Calculates the total amount of fee items
    /// This is the total fees for the invoice
    var feesTotal: Double {
        return feeItems.reduce(0) { $0 + abs($1.totalAmount) }
    }
}

// MARK: - Array Extensions for Invoice Collections

extension Array where Element == Invoice {

    /// Gets all non-tax items from all invoices
    var allNonTaxItems: [InvoiceItem] {
        return flatMap { $0.nonTaxItems }
    }

    /// Gets all tax items from all invoices
    var allTaxItems: [InvoiceItem] {
        return flatMap { $0.taxItems }
    }

    /// Gets all securities items from all invoices
    var allSecuritiesItems: [InvoiceItem] {
        return flatMap { $0.securitiesItems }
    }

    /// Gets all fee items from all invoices
    var allFeeItems: [InvoiceItem] {
        return flatMap { $0.feeItems }
    }

    /// Calculates the total amount of all non-tax items
    var totalNonTaxAmount: Double {
        return allNonTaxItems.reduce(0) { $0 + $1.totalAmount }
    }

    /// Calculates the total amount of all tax items
    var totalTaxAmount: Double {
        return allTaxItems.reduce(0) { $0 + abs($1.totalAmount) }
    }

    /// Calculates the total amount of all securities items
    var totalSecuritiesAmount: Double {
        return allSecuritiesItems.reduce(0) { $0 + $1.totalAmount }
    }

    /// Calculates the total amount of all fee items
    var totalFeesAmount: Double {
        return allFeeItems.reduce(0) { $0 + abs($1.totalAmount) }
    }
}

// MARK: - Invoice Item Extensions

extension InvoiceItem {

    /// Gets the absolute amount for calculations
    /// Used when we need the absolute value regardless of sign
    var absoluteAmount: Double {
        return abs(totalAmount)
    }
}
