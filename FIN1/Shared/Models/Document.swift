import Foundation
import SwiftUI

// MARK: - Document Types

enum DocumentType: String, CaseIterable, Codable, Hashable, Sendable {
    case identification
    case address
    case financial
    case income
    case tax
    case invoice
    case traderCollectionBill
    case investorCollectionBill
    case traderCreditNote
    /// GoB: interner Buchungsbeleg für die erste Escrow-Reservierung (CLT-LIAB-AVA → RSV), ohne externen Bankbeleg.
    case investmentReservationEigenbeleg
    case monthlyAccountStatement
    case other

    var displayName: String {
        switch self {
        case .identification: return "Identification"
        case .address: return "Address Proof"
        case .financial: return "Financial Document"
        case .income: return "Income Statement"
        case .tax: return "Tax Document"
        case .invoice: return "Invoice"
        case .traderCollectionBill: return "Trader Collection Bill"
        case .investorCollectionBill: return "Investor Collection Bill"
        case .traderCreditNote: return "Gutschrift"
        case .investmentReservationEigenbeleg: return "Eigenbeleg (Reservierung)"
        case .monthlyAccountStatement: return "Monthly Account Statement"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .identification: return "person.circle"
        case .address: return "house"
        case .financial: return "banknote"
        case .income: return "chart.line.uptrend.xyaxis"
        case .tax: return "doc.text"
        case .invoice: return "doc.text.fill"
        case .traderCollectionBill: return "doc.text.magnifyingglass"
        case .investorCollectionBill: return "doc.text.magnifyingglass"
        case .traderCreditNote: return "doc.text.fill"
        case .investmentReservationEigenbeleg: return "doc.badge.plus"
        case .monthlyAccountStatement: return "tablecells"
        case .other: return "doc"
        }
    }

    var color: Color {
        switch self {
        case .identification: return AppTheme.accentLightBlue
        case .address: return AppTheme.accentGreen
        case .financial: return AppTheme.accentOrange
        case .income: return AppTheme.accentGreen
        case .tax: return AppTheme.accentRed
        case .invoice: return AppTheme.accentLightBlue
        case .traderCollectionBill: return AppTheme.accentLightBlue
        case .investorCollectionBill: return AppTheme.accentGreen
        case .traderCreditNote: return AppTheme.accentGreen
        case .investmentReservationEigenbeleg: return AppTheme.accentOrange
        case .monthlyAccountStatement: return AppTheme.accentLightBlue
        case .other: return AppTheme.fontColor
        }
    }
}

enum DocumentStatus: String, CaseIterable, Codable, Hashable {
    case pending
    case verified
    case rejected
    case expired

    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .verified: return "Verified"
        case .rejected: return "Rejected"
        case .expired: return "Expired"
        }
    }

    var color: String {
        switch self {
        case .pending: return "orange"
        case .verified: return "green"
        case .rejected: return "red"
        case .expired: return "gray"
        }
    }

    /// SwiftUI foreground for status values (avoids `Color(_:)` asset-name ambiguity).
    var statusRowForeground: Color {
        switch self {
        case .pending: return .orange
        case .verified: return .green
        case .rejected: return .red
        case .expired: return .gray
        }
    }
}

// MARK: - Document Model

struct Document: Identifiable, Codable, Hashable {
    let id: String
    let userId: String
    let name: String
    let type: DocumentType
    let status: DocumentStatus
    let fileURL: String
    let size: Int64
    let uploadedAt: Date
    let verifiedAt: Date?
    let expiresAt: Date?
    var readAt: Date?
    var downloadedAt: Date?

    // Special property for invoice documents
    var invoiceData: Invoice?
    let tradeId: String?
    let investmentId: String?
    let statementYear: Int?
    let statementMonth: Int?
    let statementRole: UserRole?

    // MARK: - Accounting Document Number
    /// Eindeutige Belegnummer für Buchhaltungsbelege (Rechnungen, Rechnungen/Bills, Gutschriften)
    /// Gemäß Grundsätzen ordnungsgemäßer Buchführung (GoB) müssen alle Belege eindeutig identifizierbar sein
    let documentNumber: String?

    /// Trader commission rate at issuance (e.g. settlement); stored on Parse because `invoiceData` is not persisted.
    let traderCommissionRateSnapshot: Double?

    /// Mehrzeiliger Buchhaltungs-/Eigenbeleg-Text vom Backend (z. B. Reservierung GoB), für Anzeige ohne PDF.
    let accountingSummaryText: String?

    init(
        id: String = UUID().uuidString,
        userId: String,
        name: String,
        type: DocumentType,
        status: DocumentStatus,
        fileURL: String,
        size: Int64,
        uploadedAt: Date,
        verifiedAt: Date? = nil,
        expiresAt: Date? = nil,
        invoiceData: Invoice? = nil,
        tradeId: String? = nil,
        investmentId: String? = nil,
        statementYear: Int? = nil,
        statementMonth: Int? = nil,
        statementRole: UserRole? = nil,
        documentNumber: String? = nil,
        traderCommissionRateSnapshot: Double? = nil,
        accountingSummaryText: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.type = type
        self.status = status
        self.fileURL = fileURL
        self.size = size
        self.uploadedAt = uploadedAt
        self.verifiedAt = verifiedAt
        self.expiresAt = expiresAt
        self.invoiceData = invoiceData
        self.tradeId = tradeId
        self.investmentId = investmentId
        self.statementYear = statementYear
        self.statementMonth = statementMonth
        self.statementRole = statementRole
        // Automatisch documentNumber aus invoiceData setzen, falls vorhanden
        // Sonst verwende den übergebenen documentNumber
        self.documentNumber = invoiceData?.invoiceNumber ?? documentNumber
        self.traderCommissionRateSnapshot = traderCommissionRateSnapshot
        self.accountingSummaryText = accountingSummaryText
    }

    // MARK: - Computed Properties

    var title: String {
        return self.name
    }

    var description: String {
        return "\(self.type.displayName) document uploaded on \(self.uploadedAt.formatted(date: .abbreviated, time: .omitted))"
    }

    var timestamp: Date {
        return self.uploadedAt
    }

    var fileSize: String {
        return self.formattedSize
    }

    var fileFormat: String {
        let pathExtension = URL(string: fileURL)?.pathExtension ?? "unknown"
        return pathExtension.uppercased()
    }

    var icon: String {
        return self.type.icon
    }

    var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: self.size)
    }

    var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return Date() > expiresAt
    }

    var daysUntilExpiry: Int? {
        guard let expiresAt = expiresAt else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: expiresAt)
        return components.day
    }

    // MARK: - Accounting Document Number Helper

    /// Gibt die Belegnummer zurück, falls vorhanden
    /// Für Buchhaltungsbelege (Invoices, Bills, Credit Notes) sollte dies immer gesetzt sein
    var accountingDocumentNumber: String? {
        return self.documentNumber ?? self.invoiceData?.invoiceNumber
    }

    /// Prüft, ob das Dokument eine Belegnummer hat (erforderlich für Buchhaltungsbelege)
    var hasAccountingDocumentNumber: Bool {
        return self.accountingDocumentNumber != nil
    }

    /// Interner GoB-Eigenbeleg (Reservierung); nicht im Investor-Postfach „Dokumente“, sondern am App-Ledger zur Buchung.
    var isExcludedFromInvestorDocumentInbox: Bool {
        self.type == .investmentReservationEigenbeleg
    }
}
