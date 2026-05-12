import Foundation

// MARK: - App Ledger Account (Eigenkonten der App)

/// System-level ledger accounts representing the app's financial position.
/// These are NOT user accounts - they are internal bookkeeping accounts (Eigenkonten)
/// that receive counter-entries (Gegenbuchungen) when fees are charged to users.
///
/// Service charge journal (Parse `afterSave Invoice`): debit `PLT-CLR-GEN` (gross),
/// credit `PLT-REV-PSC` (net) and `PLT-TAX-VAT` (VAT) so the App ledger balances.
///
/// Client-funds sub-ledger (target, see `Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md`):
/// `CLT-LIAB-AVA` → `CLT-LIAB-RSV` (reserve) → `CLT-LIAB-TRD` (deploy to pool); postings server-side TBD.
///
/// Full accounting lifecycle:
///   1. Eingang: User wallet debit → App ledger debit clearing + credits (revenue + VAT)
///   2. Erstattung: App ledger debit (revenue reversal) → User wallet credit
///   3. USt-Abführung: App ledger debit (VAT liability) → Finanzamt payment
///   4. Vorsteuer: App pays vendor → App ledger debit (input VAT claim)
enum AppLedgerAccount: String, Codable, CaseIterable, Sendable {

    // MARK: - Client Liability Sub-Ledger (Kundenguthaben, Teil-Verbindlichkeiten)

    /// Customer funds – immediately available in the app (sub-liability)
    case clientFundsAvailable = "CLT-LIAB-AVA"

    /// Customer funds – reserved for pending investments
    case clientFundsReserved = "CLT-LIAB-RSV"

    /// Customer funds – deployed in trading / pool mirror
    case clientFundsInTrading = "CLT-LIAB-TRD"

    // MARK: - Revenue Accounts (Erlöskonten)

    /// Net app service charge revenue (Erlös Appgebühr netto)
    case serviceChargeRevenue = "PLT-REV-PSC"

    /// Order fee revenue from trading (Erlös Ordergebühren)
    case orderFeeRevenue = "PLT-REV-ORD"

    /// Exchange/venue fee revenue (Erlös Börsenplatzgebühren)
    case exchangeFeeRevenue = "PLT-REV-EXC"

    /// Foreign costs passthrough (Fremdkostenpauschale)
    case foreignCostsRevenue = "PLT-REV-FRG"

    /// Commission revenue - platform share of trader commissions (Provisionserlös)
    case commissionRevenue = "PLT-REV-COM"

    // MARK: - Tax Accounts (Steuerkonten)

    /// Output VAT collected from users, owed to Finanzamt (USt-Verbindlichkeit)
    /// CREDIT when VAT is collected, DEBIT when remitted to Finanzamt
    case vatLiability = "PLT-TAX-VAT"

    /// Input VAT paid on platform expenses, reclaimable (Vorsteuer)
    /// DEBIT when platform pays vendors with VAT, CREDIT when offset in USt-Voranmeldung
    case vatInputClaim = "PLT-TAX-VST"

    /// Withholding tax (Abgeltungsteuer / Quellensteuer), owed to Finanzamt
    /// CREDIT on settlement deduction, DEBIT on remittance.
    /// ADR-010 / PR4
    case withholdingTaxLiability = "PLT-TAX-WHT"

    /// Solidarity surcharge (Solidaritätszuschlag), owed to Finanzamt
    /// ADR-010 / PR4
    case solidarityTaxLiability = "PLT-TAX-SOL"

    /// Church tax (Kirchensteuer), owed to Finanzamt
    /// ADR-010 / PR4
    case churchTaxLiability = "PLT-TAX-CHU"

    // MARK: - Trader-Verbindlichkeit aus Provision (ADR-010 / PR4)

    /// Provisionsverbindlichkeit gegenüber Trader: Investor → debit, Trader → credit.
    /// Saldiert pro Trade in Phase 1 auf 0 (100 % Trader-Cut, kein App-Anteil).
    case commissionLiability = "PLT-LIAB-COM"

    // MARK: - Bankkonten (Aktiva)

    /// Treuhand-Bankkonto Kundengelder (ADR-011 / PR5).
    /// Aktivkonto: debit bei Einzahlung / Verkaufserlös, credit bei Kauf / Auszahlung.
    case clientTrustBank = "BANK-TRT-CLT"

    // MARK: - Expense Accounts (Aufwandskonten)

    /// General platform operating expenses (Betriebsaufwand)
    case operatingExpenses = "PLT-EXP-OPS"

    /// Refunds/credit notes issued to users (Erstattungsaufwand)
    case refundExpenses = "PLT-EXP-REF"

    // MARK: - Clearing / Settlement Accounts (Verrechnungskonten)

    /// General clearing account for unsettled items
    case clearingSuspense = "PLT-CLR-GEN"

    /// User refund clearing – temporary hold before wallet credit
    case clearingRefund = "PLT-CLR-REF"

    /// Finanzamt settlement – tracks pending VAT remittance
    case clearingVATSettlement = "PLT-CLR-VAT"

    var displayName: String {
        switch self {
        case .clientFundsAvailable:    return "Kundenguthaben – verfügbar"
        case .clientFundsReserved:     return "Kundenguthaben – reserviert"
        case .clientFundsInTrading:    return "Kundenguthaben – im Handel"
        case .serviceChargeRevenue:    return "Erlös Appgebühr (netto)"
        case .orderFeeRevenue:         return "Erlös Ordergebühren"
        case .exchangeFeeRevenue:      return "Erlös Börsenplatzgebühren"
        case .foreignCostsRevenue:     return "Fremdkostenpauschale"
        case .commissionRevenue:       return "Provisionserlös"
        case .vatLiability:            return "USt-Verbindlichkeit (Output)"
        case .vatInputClaim:           return "Vorsteuer (Input)"
        case .withholdingTaxLiability: return "Quellensteuer-Verbindlichkeit"
        case .solidarityTaxLiability:  return "Solidaritätszuschlag-Verbindlichkeit"
        case .churchTaxLiability:      return "Kirchensteuer-Verbindlichkeit"
        case .commissionLiability:     return "Provisionsverbindlichkeit Trader"
        case .clientTrustBank:         return "Treuhand-Bank Kundengelder"
        case .operatingExpenses:       return "Betriebsaufwand"
        case .refundExpenses:          return "Erstattungsaufwand"
        case .clearingSuspense:        return "Verrechnungskonto"
        case .clearingRefund:          return "Erstattungs-Verrechnungskonto"
        case .clearingVATSettlement:   return "USt-Abführung Verrechnungskonto"
        }
    }

    var accountGroup: AccountGroup {
        switch self {
        case .clientFundsAvailable, .clientFundsReserved, .clientFundsInTrading,
             .commissionLiability:
            return .liability
        case .clientTrustBank:
            return .asset
        case .serviceChargeRevenue, .orderFeeRevenue, .exchangeFeeRevenue,
             .foreignCostsRevenue, .commissionRevenue:
            return .revenue
        case .vatLiability, .vatInputClaim,
             .withholdingTaxLiability, .solidarityTaxLiability, .churchTaxLiability:
            return .tax
        case .operatingExpenses, .refundExpenses:
            return .expense
        case .clearingSuspense, .clearingRefund, .clearingVATSettlement:
            return .clearing
        }
    }

    enum AccountGroup: String, Codable, CaseIterable, Sendable {
        case asset
        case liability
        case revenue
        case tax
        case expense
        case clearing

        var displayName: String {
            switch self {
            case .asset:     return "Aktiva (Bank/Wertpapiere)"
            case .liability: return "Verbindlichkeiten"
            case .revenue:   return "Erlöskonten"
            case .tax:       return "Steuerkonten"
            case .expense:   return "Aufwandskonten"
            case .clearing:  return "Verrechnungskonten"
            }
        }
    }
}

// MARK: - App Ledger Entry

/// A single posting on an app ledger account (Gegenbuchung).
/// For every fee deducted from a user, a corresponding credit entry is recorded here.
struct AppLedgerEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let account: AppLedgerAccount
    let side: AppLedgerSide
    let amount: Double
    let userId: String
    let userRole: String
    let transactionType: AppLedgerTransactionType
    let referenceId: String
    let referenceType: String
    let description: String
    let createdAt: Date
    let metadata: [String: String]

    init(
        id: UUID = UUID(),
        account: AppLedgerAccount,
        side: AppLedgerSide,
        amount: Double,
        userId: String,
        userRole: String,
        transactionType: AppLedgerTransactionType,
        referenceId: String,
        referenceType: String,
        description: String,
        createdAt: Date = Date(),
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.account = account
        self.side = side
        self.amount = amount
        self.userId = userId
        self.userRole = userRole
        self.transactionType = transactionType
        self.referenceId = referenceId
        self.referenceType = referenceType
        self.description = description
        self.createdAt = createdAt
        self.metadata = metadata
    }
}

// MARK: - Supporting Types

enum AppLedgerSide: String, Codable, Sendable {
    case debit  // Soll
    case credit // Haben
}

enum AppLedgerTransactionType: String, Codable, Sendable {
    // Incoming (Eingang)
    case appServiceCharge
    case orderFee
    case exchangeFee
    case foreignCosts
    case commission

    // Outgoing (Ausgang)
    case refund              // Erstattung an User
    case creditNote          // Gutschrift an User
    case vatRemittance       // USt-Abführung ans Finanzamt
    case vatInputClaim       // Vorsteuer-Anspruch aus Eingangsrechnung
    case operatingExpense    // Betriebsausgabe

    // Steuern auf Trade-Settlement (ADR-010 / PR4)
    case withholdingTax      // Abgeltungsteuer / Quellensteuer
    case solidaritySurcharge // Solidaritätszuschlag
    case churchTax           // Kirchensteuer

    // Trade-Cash / Wallet-Bewegungen (ADR-011 / PR5)
    case tradeCash           // Wertpapierkauf/-verkauf via Treuhand-Bank
    case walletDeposit       // Einzahlung
    case walletWithdrawal    // Auszahlung

    // Corrections
    case adjustment          // Manuelle Korrektur
    case reversal            // Stornierung (Gegenbuchung zu Originalbuchung)

    /// Kundenguthaben Reservierung / Handel (CLT-LIAB-*)
    case investmentEscrow

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        let raw = try c.decode(String.self)
        if let v = AppLedgerTransactionType(rawValue: raw) {
            self = v
            return
        }
        if raw == "platformServiceCharge" {
            self = .appServiceCharge
            return
        }
        throw DecodingError.dataCorruptedError(in: c, debugDescription: "Unknown AppLedgerTransactionType: \(raw)")
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawValue)
    }
}

// MARK: - Grouped Posting Results

/// Returned when recording an app service charge (multiple accounts hit at once)
struct AppServiceChargePostings: Sendable {
    let revenueEntry: AppLedgerEntry
    let vatEntry: AppLedgerEntry
}

/// Returned when recording trading fees (order + exchange + foreign)
struct TradingFeePostings: Sendable {
    let orderFeeEntry: AppLedgerEntry?
    let exchangeFeeEntry: AppLedgerEntry?
    let foreignCostsEntry: AppLedgerEntry?
}

/// Returned when processing a user refund (reversal + credit note)
struct UserRefundPostings: Sendable {
    /// Debit on the original revenue account (reversal of the original booking)
    let revenueReversalEntry: AppLedgerEntry
    /// Debit on VAT liability (reversal of VAT portion), nil if no VAT involved
    let vatReversalEntry: AppLedgerEntry?
    /// Entry on refund expense account
    let refundExpenseEntry: AppLedgerEntry
}

/// Returned when recording VAT remittance to Finanzamt
struct VATRemittancePostings: Sendable {
    /// Debit on PLT-TAX-VAT reducing the liability
    let vatLiabilityDebitEntry: AppLedgerEntry
    /// Credit on clearing account to track the payment
    let settlementEntry: AppLedgerEntry
}

// MARK: - Account Summary

/// Aggregated balance for a single app ledger account
struct AppLedgerAccountSummary: Identifiable, Sendable {
    var id: String { account.rawValue }
    let account: AppLedgerAccount
    let totalCredits: Double
    let totalDebits: Double

    var netBalance: Double { totalCredits - totalDebits }
}

// MARK: - VAT Summary

/// Snapshot of the app's VAT position for a period
struct AppVATSummary: Sendable {
    /// Total output VAT collected from users (Umsatzsteuer)
    let outputVATCollected: Double
    /// Total output VAT already remitted to Finanzamt
    let outputVATRemitted: Double
    /// Total input VAT on platform expenses (Vorsteuer)
    let inputVATClaimed: Double

    /// Outstanding VAT liability = collected - remitted - inputClaimed
    var outstandingVATLiability: Double {
        outputVATCollected - outputVATRemitted - inputVATClaimed
    }
}
