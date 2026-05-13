import Foundation
import SwiftUI

// MARK: - Display Model

struct AppLedgerEntryDisplay: Identifiable, Hashable {
    let id: UUID
    let accountName: String
    let accountCode: String
    let sideText: String
    let amountText: String
    let userId: String
    let userRole: String
    let transactionType: String
    let referenceId: String
    let description: String
    let createdAtText: String
    let rawEntry: AppLedgerEntry

    init(entry: AppLedgerEntry, formatter: DateFormatter) {
        self.id = entry.id
        self.accountName = entry.account.displayName
        self.accountCode = entry.account.rawValue
        self.sideText = entry.side == .credit ? "Haben" : "Soll"
        self.amountText = entry.amount.formatted(.currency(code: "EUR"))
        self.userId = entry.userId
        self.userRole = entry.userRole
        self.transactionType = Self.transactionTypeLabel(entry.transactionType)
        self.referenceId = entry.referenceId
        self.description = entry.description
        self.createdAtText = formatter.string(from: entry.createdAt)
        self.rawEntry = entry
    }

    private static func transactionTypeLabel(_ type: AppLedgerTransactionType) -> String {
        switch type {
        case .appServiceCharge:    return "Appgebühr"
        case .orderFee:            return "Ordergebühr"
        case .exchangeFee:         return "Börsenplatzgebühr"
        case .foreignCosts:        return "Fremdkosten"
        case .commission:          return "Provision"
        case .refund:              return "Erstattung"
        case .creditNote:          return "Gutschrift"
        case .vatRemittance:       return "USt-Abführung"
        case .vatInputClaim:       return "Vorsteuer"
        case .operatingExpense:    return "Betriebsausgabe"
        case .withholdingTax:      return "Quellensteuer"
        case .solidaritySurcharge: return "Solidaritätszuschlag"
        case .churchTax:           return "Kirchensteuer"
        case .tradeCash:           return "Trade-Cash"
        case .walletDeposit:       return "Einzahlung"
        case .walletWithdrawal:    return "Auszahlung"
        case .adjustment:          return "Korrektur"
        case .reversal:            return "Storno"
        case .investmentEscrow:    return "Investment-Escrow"
        }
    }
}

// MARK: - ViewModel

@MainActor
final class AppLedgerViewModel: ObservableObject {

    @Published private(set) var entries: [AppLedgerEntryDisplay] = []
    @Published private(set) var accountSummaries: [AppLedgerAccountSummary] = []
    @Published private(set) var totalRevenue: Double = 0
    @Published private(set) var vatSummary: AppVATSummary?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    @Published var selectedAccount: AppLedgerAccount? {
        didSet { self.applyFilters() }
    }
    @Published var userFilter: String = "" {
        didSet { self.applyFilters() }
    }

    private let ledgerService: any AppLedgerServiceProtocol
    private let dateFormatter: DateFormatter
    private var allEntries: [AppLedgerEntry] = []

    init(ledgerService: any AppLedgerServiceProtocol) {
        self.ledgerService = ledgerService
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateStyle = .medium
        self.dateFormatter.timeStyle = .short
        Task { await self.load() }
    }

    func load() async {
        self.isLoading = true
        self.errorMessage = nil
        do {
            try await self.ledgerService.refreshFromBackend()
        } catch {
            self.errorMessage = "Ledger konnte nicht geladen werden: \(error.localizedDescription)"
        }
        self.allEntries = self.ledgerService.getAllEntries().sorted { $0.createdAt > $1.createdAt }
        self.accountSummaries = self.ledgerService.getAccountSummaries()
        self.totalRevenue = self.ledgerService.getTotalAppRevenue()
        self.vatSummary = self.ledgerService.getVATSummary()
        self.applyFilters()
        self.isLoading = false
    }

    func refresh() { Task { await self.load() } }

    func clearFilters() {
        self.selectedAccount = nil
        self.userFilter = ""
    }

    func copyCSVToPasteboard() {
        #if os(iOS)
        UIPasteboard.general.string = self.generateCSV()
        #endif
    }

    private func applyFilters() {
        let filtered = self.allEntries.filter { entry in
            let matchesAccount = self.selectedAccount.map { $0 == entry.account } ?? true
            let matchesUser: Bool = {
                guard !self.userFilter.isEmpty else { return true }
                return entry.userId.localizedCaseInsensitiveContains(self.userFilter)
            }()
            return matchesAccount && matchesUser
        }

        self.entries = filtered.map { AppLedgerEntryDisplay(entry: $0, formatter: self.dateFormatter) }
    }

    private func generateCSV() -> String {
        var rows = ["Datum,Konto,Code,Seite,Betrag,User,Rolle,Typ,Referenz,Beschreibung"]
        for entry in self.entries {
            let fields = [
                entry.createdAtText, entry.accountName, entry.accountCode,
                entry.sideText, entry.amountText, entry.userId,
                entry.userRole, entry.transactionType, entry.referenceId,
                entry.description
            ].map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            rows.append(fields.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }
}
