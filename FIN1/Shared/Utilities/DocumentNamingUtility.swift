import Foundation

// MARK: - Document Naming Utility
/// Provides industry-standard document naming conventions for financial documents
struct DocumentNamingUtility {

    // MARK: - Date Formatter
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    // MARK: - Hash Generator
    /// Generates an 8-digit alphanumeric hash for document uniqueness
    private static func generateHash8() -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<8).compactMap { _ in characters.randomElement() })
    }

    // MARK: - Document Naming Methods

    /// Generates a collection bill document name for traders
    /// Format: TraderCollectionBill_Trade{Number}_{YYYYMMDD}_{Hash8}.pdf
    static func traderCollectionBillName(for trade: Trade) -> String {
        let dateString = dateFormatter.string(from: Date())
        let hash = generateHash8()
        return "TraderCollectionBill_Trade\(trade.tradeNumber)_\(dateString)_\(hash).pdf"
    }

    /// Generates a collection bill document name for investors
    /// Format: InvestorCollectionBill_Investment{InvestmentId}_{YYYYMMDD}_{Hash8}.pdf
    static func investorCollectionBillName(for investment: Investment) -> String {
        let dateString = dateFormatter.string(from: Date())
        let hash = generateHash8()
        return "InvestorCollectionBill_Investment\(investment.id)_\(dateString)_\(hash).pdf"
    }

    /// Generates a batch investor collection bill document name
    /// Format: InvestorCollectionBill_Batch{BatchIdPrefix}_{YYYYMMDD}_{Hash8}.pdf
    static func investorCollectionBillBatchName(for batch: InvestmentBatch) -> String {
        let dateString = dateFormatter.string(from: Date())
        let hash = generateHash8()
        let batchPrefix = batch.id.prefix(8)
        return "InvestorCollectionBill_Batch\(batchPrefix)_\(dateString)_\(hash).pdf"
    }

    /// Generates an invoice document name for traders
    /// Format: Invoice_{Type}_{Number}_{YYYYMMDD}_{Hash8}.pdf
    static func invoiceName(for invoice: Invoice, userRole: UserRole) -> String {
        let dateString = dateFormatter.string(from: Date())
        let hash = generateHash8()

        let typeString = invoice.type.rawValue.capitalized
        let numberString = invoice.invoiceNumber

        return "Invoice_\(typeString)_\(numberString)_\(dateString)_\(hash).pdf"
    }

    /// Generates a generic document name with role-specific prefix
    /// Format: {Prefix}_{Type}_{Number}_{YYYYMMDD}_{Hash8}.pdf
    static func documentName(prefix: String, type: String, number: String) -> String {
        let dateString = dateFormatter.string(from: Date())
        let hash = generateHash8()
        return "\(prefix)_\(type)_\(number)_\(dateString)_\(hash).pdf"
    }

    /// Generates a monthly account statement document name
    /// Format: MonthlyStatement_{Role}_{YYYYMM}_{Hash8}.pdf
    static func monthlyAccountStatementName(for user: User, year: Int, month: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMM"
        let calendar = Calendar.current
        let components = DateComponents(year: year, month: month, day: 1)
        let date = calendar.date(from: components) ?? Date()
        let yearMonthString = formatter.string(from: date)
        let hash = generateHash8()
        let roleString = user.role.displayName.replacingOccurrences(of: " ", with: "")
        return "MonthlyStatement_\(roleString)_\(yearMonthString)_\(hash).pdf"
    }
}

// MARK: - Import Investment Model
// Note: Investment model is imported from Features/Investor/Models/Investment.swift
