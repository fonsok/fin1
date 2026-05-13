import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Display Model

struct BankContraPostingDisplay: Identifiable, Hashable {
    let id: UUID
    let accountName: String
    let sideText: String
    let amountText: String
    let investorId: String
    let batchId: String
    let investmentList: String
    let reference: String
    let createdAtText: String
    let metadataDescription: String
    let rawPosting: BankContraAccountPosting

    init(posting: BankContraAccountPosting, formatter: DateFormatter) {
        self.id = posting.id
        self.accountName = posting.account.displayName
        self.sideText = posting.side == .credit ? "Credit" : "Debit"
        self.amountText = posting.amount.formatted(.currency(code: "EUR"))
        self.investorId = posting.investorId
        self.batchId = posting.batchId
        self.investmentList = posting.investmentIds.joined(separator: "\n")
        self.reference = posting.reference
        self.createdAtText = formatter.string(from: posting.createdAt)
        if posting.metadata.isEmpty {
            self.metadataDescription = "—"
        } else {
            self.metadataDescription = posting.metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
        }
        self.rawPosting = posting
    }
}

// MARK: - ViewModel

@MainActor
final class BankContraLedgerViewModel: ObservableObject {

    @Published private(set) var entries: [BankContraPostingDisplay] = []
    @Published private(set) var totalsByAccount: [BankContraAccount: Double] = [:]

    @Published var selectedAccount: BankContraAccount? {
        didSet { self.applyFilters() }
    }
    @Published var investorFilter: String = "" {
        didSet { self.applyFilters() }
    }
    @Published var startDate: Date? {
        didSet { self.applyFilters() }
    }
    @Published var endDate: Date? {
        didSet { self.applyFilters() }
    }

    private let postingService: any BankContraAccountPostingServiceProtocol
    private let dateFormatter: DateFormatter
    private var allPostings: [BankContraAccountPosting] = []

    init(postingService: any BankContraAccountPostingServiceProtocol) {
        self.postingService = postingService
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateStyle = .medium
        self.dateFormatter.timeStyle = .short
        self.load()
    }

    func load() {
        let fetched = self.postingService.getAllPostings().sorted { $0.createdAt > $1.createdAt }
        self.allPostings = fetched
        self.applyFilters()
    }

    func refresh() {
        self.load()
    }

    func clearFilters() {
        self.selectedAccount = nil
        self.investorFilter = ""
        self.startDate = nil
        self.endDate = nil
        self.applyFilters()
    }

    func copyCSVToPasteboard() {
        #if os(iOS)
        UIPasteboard.general.string = self.generateCSV()
        #endif
    }

    // MARK: - Private Helpers

    private func applyFilters() {
        let filtered = self.allPostings.filter { posting in
            let matchesAccount = self.selectedAccount.map { $0 == posting.account } ?? true
            let matchesInvestor: Bool = {
                guard !self.investorFilter.isEmpty else { return true }
                return posting.investorId.localizedCaseInsensitiveContains(self.investorFilter)
            }()
            let matchesStart: Bool = {
                guard let startDate else { return true }
                return posting.createdAt >= startDate
            }()
            let matchesEnd: Bool = {
                guard let endDate else { return true }
                return posting.createdAt <= endDate
            }()
            return matchesAccount && matchesInvestor && matchesStart && matchesEnd
        }

        self.entries = filtered.map { BankContraPostingDisplay(posting: $0, formatter: self.dateFormatter) }
        self.totalsByAccount = Dictionary(grouping: filtered, by: { $0.account })
            .mapValues { postings in
                postings.reduce(0) { partial, posting in
                    let signed = posting.side == .credit ? posting.amount : -posting.amount
                    return partial + signed
                }
            }
    }

    private func generateCSV() -> String {
        var rows: [String] = []
        let header = [
            "Date",
            "Account",
            "Side",
            "Amount",
            "Investor",
            "Batch",
            "Investments",
            "Reference",
            "Metadata"
        ].joined(separator: ",")
        rows.append(header)

        for entry in self.entries {
            let fields: [String] = [
                entry.createdAtText,
                entry.accountName,
                entry.sideText,
                entry.amountText,
                entry.investorId,
                entry.batchId,
                entry.investmentList.replacingOccurrences(of: "\n", with: " | "),
                entry.reference,
                entry.metadataDescription.replacingOccurrences(of: "\n", with: " | ")
            ]
            let escaped = fields.map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"" }
            rows.append(escaped.joined(separator: ","))
        }
        return rows.joined(separator: "\n")
    }
}
