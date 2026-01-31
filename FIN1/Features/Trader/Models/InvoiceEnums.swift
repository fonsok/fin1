import Foundation
import SwiftUI

// MARK: - Invoice Type Enum
enum InvoiceType: String, CaseIterable, Codable, Hashable {
    case securitiesSettlement = "securities_settlement"
    case tradingFee = "trading_fee"
    case accountStatement = "account_statement"
    case platformServiceCharge = "platform_service_charge"
    case creditNote = "credit_note"
    case commissionInvoice = "commission_invoice"

    var displayName: String {
        switch self {
        case .securitiesSettlement: return "Rechnung"
        case .tradingFee: return "Handelsgebühren"
        case .accountStatement: return "Kontoauszug"
        case .platformServiceCharge: return "Plattform-Servicegebühr"
        case .creditNote: return "Gutschrift"
        case .commissionInvoice: return "Provisionsrechnung"
        }
    }

    var icon: String {
        switch self {
        case .securitiesSettlement: return "doc.text"
        case .tradingFee: return "banknote"
        case .accountStatement: return "list.bullet.rectangle"
        case .platformServiceCharge: return "creditcard"
        case .creditNote: return "doc.text"
        case .commissionInvoice: return "doc.text"
        }
    }
}

// MARK: - Invoice Status Enum
enum InvoiceStatus: String, CaseIterable, Codable, Hashable {
    case draft
    case generated
    case sent
    case paid
    case cancelled

    var displayName: String {
        switch self {
        case .draft: return "Entwurf"
        case .generated: return "Generiert"
        case .sent: return "Versendet"
        case .paid: return "Bezahlt"
        case .cancelled: return "Storniert"
        }
    }

    var color: Color {
        switch self {
        case .draft: return AppTheme.accentOrange
        case .generated: return AppTheme.accentLightBlue
        case .sent: return AppTheme.accentGreen
        case .paid: return AppTheme.accentGreen
        case .cancelled: return AppTheme.accentRed
        }
    }
}

// MARK: - Transaction Type Enum
enum TransactionType: String, CaseIterable, Codable, Hashable {
    case buy
    case sell

    var displayName: String {
        switch self {
        case .buy: return "KAUF"
        case .sell: return "VERKAUF"
        }
    }
}

// MARK: - Invoice Item Type Enum
enum InvoiceItemType: String, CaseIterable, Codable, Hashable {
    case securities = "securities"
    case orderFee = "order_fee"
    case exchangeFee = "exchange_fee"
    case foreignCosts = "foreign_costs"
    case serviceCharge = "service_charge"
    case vat = "vat"
    case tax = "tax"
    case other = "other"
    case commission = "commission"

    var displayName: String {
        switch self {
        case .securities: return "Wertpapiere"
        case .orderFee: return "Ordergebühr"
        case .exchangeFee: return "Börsenplatzgebühr"
        case .foreignCosts: return "Fremdkostenpauschale"
        case .serviceCharge: return "Servicegebühr"
        case .vat: return "Umsatzsteuer (19%)"
        case .tax: return "Steuer"
        case .other: return "Sonstiges"
        case .commission: return "Provision"
        }
    }
}
