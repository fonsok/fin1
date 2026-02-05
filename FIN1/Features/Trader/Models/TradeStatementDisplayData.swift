import Foundation

// MARK: - Placeholders (Handelsplatz etc. werden in Live-Produktion belegt)

/// Handelsplätze sind nicht festgelegt und werden erst in Live-Produktion bestimmt.
enum TradeStatementPlaceholders {
    static let tradingVenue = "—"
}

// MARK: - Main Display Data Model

/// Complete display data for a trade statement
struct TradeStatementDisplayData {
    let depotNumber: String
    let depotHolder: String
    let securityIdentifier: String

    let buyTransaction: BuyTransactionData?
    let sellTransactions: [SellTransactionData]

    // Original invoices for legacy SellOrderData support
    let sellInvoices: [Invoice]

    let calculationBreakdown: CalculationBreakdownData
    let taxSummary: TaxSummaryData
    let fees: [FeeItem]
    let taxes: [TaxItem]

    let legalDisclaimer: String
    let accountNumber: String
    let taxReportTransactionNumber: String
}

// MARK: - Buy Transaction Data

/// Display data for buy transactions
struct BuyTransactionData {
    let transactionNumber: String
    let orderVolume: String
    let executedVolume: String
    let price: String
    let exchangeRate: String
    let conversionFactor: String
    let custodyType: String
    let depository: String
    let depositoryCountry: String
    let profitLoss: String
    let profitLossColor: String // Color name for PDF generation
    let valueDate: String
    let tradingVenue: String
    let closingDate: String
    let marketValue: String
    let commission: String
    let ownExpenses: String
    let externalExpenses: String
    let assessmentBasis: String
    let withheldTax: String
    let finalAmount: String
    let finalAmountColor: String // Color name for PDF generation
}

// MARK: - Sell Transaction Data

/// Display data for sell transactions
struct SellTransactionData {
    let transactionNumber: String
    let orderVolume: String
    let executedVolume: String
    let price: String
    let exchangeRate: String
    let conversionFactor: String
    let custodyType: String
    let depository: String
    let depositoryCountry: String
    let profitLoss: String
    let profitLossColor: String // Color name for PDF generation
    let valueDate: String
    let tradingVenue: String
    let closingDate: String
    let marketValue: String
    let commission: String
    let ownExpenses: String
    let externalExpenses: String
    let assessmentBasis: String
    let withheldTax: String
    let finalAmount: String
    let finalAmountColor: String // Color name for PDF generation
}

// MARK: - Calculation Breakdown Data

/// Data for the calculation breakdown section
struct CalculationBreakdownData {
    let sellAmounts: [String] // Individual sell amounts
    let totalSellAmount: String
    let buyAmount: String
    let resultBeforeTaxes: String
    let resultBeforeTaxesColor: String // Color name for PDF generation
}

// MARK: - Tax Summary Data

/// Summary data for tax calculations
struct TaxSummaryData {
    let assessmentBasis: String
    let totalTax: String
    let netResult: String
    let netResultColor: String // Color name for PDF generation
}

// Note: FeeItem and TaxItem are defined in TradeStatementModels.swift

// MARK: - Sell Order Data (Legacy Support)

/// Legacy sell order data structure for backward compatibility
struct SellOrderData {
    let transactionNumber: String
    let invoice: Invoice

    var orderVolume: String {
        let securityItems = invoice.items.filter { $0.itemType == .securities }
        if let securityItem = securityItems.first {
            return "\(String(format: "%.0f", securityItem.quantity)) St."
        }
        return "100,00 St."
    }

    var price: String {
        let securityItems = invoice.items.filter { $0.itemType == .securities }
        if let securityItem = securityItems.first, securityItem.quantity > 0 {
            let price = securityItem.unitPrice
            // Use German decimal formatting (comma as decimal separator)
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.locale = Locale(identifier: "de_DE")
            formatter.decimalSeparator = ","
            formatter.minimumFractionDigits = 2
            formatter.maximumFractionDigits = 4
            return "\(formatter.string(from: NSNumber(value: price)) ?? "0,00") EUR"
        }
        return "0,62 EUR"
    }

    var valueDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yy"
        return formatter.string(from: invoice.createdAt)
    }

    var closingDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy, HH:mm 'Uhr'"
        return formatter.string(from: invoice.createdAt)
    }

    var marketValue: String {
        let securityItems = invoice.items.filter { $0.itemType == .securities }
        let totalValue = securityItems.reduce(0) { $0 + $1.totalAmount }
        return totalValue.formatted(.currency(code: "EUR"))
    }

    var commission: String {
        // Calculate individual fees using the same logic as Trade Details
        // For sell transactions, fees should be negative (like in TradeCalculationService.calculateSellFees)
        let securitiesItems = invoice.items.filter { $0.itemType == .securities }
        let securitiesAmount = securitiesItems.reduce(0) { $0 + $1.totalAmount }
        let feeBreakdown = FeeCalculationService.createFeeBreakdown(for: securitiesAmount)

        // Extract order fee and make it negative for sell transactions
        let orderFee = -(feeBreakdown.first { $0.name == "Ordergebühr" }?.amount ?? 0.0)
        return orderFee.formatted(.currency(code: "EUR"))
    }

    var ownExpenses: String {
        // Calculate individual fees using the same logic as Trade Details
        // For sell transactions, fees should be negative (like in TradeCalculationService.calculateSellFees)
        let securitiesItems = invoice.items.filter { $0.itemType == .securities }
        let securitiesAmount = securitiesItems.reduce(0) { $0 + $1.totalAmount }
        let feeBreakdown = FeeCalculationService.createFeeBreakdown(for: securitiesAmount)

        let exchangeFee = -(feeBreakdown.first { $0.name == "Handelsplatzgebühr" }?.amount ?? 0.0)
        return exchangeFee.formatted(.currency(code: "EUR"))
    }

    var externalExpenses: String {
        // Calculate individual fees using the same logic as Trade Details
        // For sell transactions, fees should be negative (like in TradeCalculationService.calculateSellFees)
        let securitiesItems = invoice.items.filter { $0.itemType == .securities }
        let securitiesAmount = securitiesItems.reduce(0) { $0 + $1.totalAmount }
        let feeBreakdown = FeeCalculationService.createFeeBreakdown(for: securitiesAmount)

        let foreignCosts = -(feeBreakdown.first { $0.name == "Fremdkostenpauschale" }?.amount ?? 0.0)
        return foreignCosts.formatted(.currency(code: "EUR"))
    }

    var finalAmount: String {
        return invoice.totalAmount.formatted(.currency(code: "EUR"))
    }
}
