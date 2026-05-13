import Foundation

@MainActor
final class MonthlyAccountStatementViewModel: ObservableObject {
    @Published private(set) var entries: [AccountStatementEntry] = []
    @Published private(set) var openingBalance: Double = 0
    @Published private(set) var closingBalance: Double = 0

    private let userService: any UserServiceProtocol
    private let investorCashBalanceService: any InvestorCashBalanceServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let traderDataService: (any TraderDataServiceProtocol)?

    private let year: Int
    private let month: Int

    init(services: AppServices, year: Int, month: Int) {
        self.userService = services.userService
        self.investorCashBalanceService = services.investorCashBalanceService
        self.invoiceService = services.invoiceService
        self.configurationService = services.configurationService
        self.traderDataService = services.traderDataService
        self.year = year
        self.month = month
    }

    // MARK: - Public API

    var title: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        let date = Calendar.current.date(from: DateComponents(year: self.year, month: self.month, day: 1)) ?? Date()
        return formatter.string(from: date)
    }

    var periodLabel: String {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: self.year, month: self.month, day: 1)) ?? Date()
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: start) ?? start
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }

    /// Date label for the opening balance line (last day before the month starts),
    /// e.g. "Opening balance as of 29 Aug 2025".
    var openingBalanceDateLabel: String {
        let calendar = Calendar.current
        let start = calendar.date(from: DateComponents(year: self.year, month: self.month, day: 1)) ?? Date()
        let previousDay = calendar.date(byAdding: .day, value: -1, to: start) ?? start
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: previousDay)
    }

    /// Display name for the account holder (current user).
    var accountHolderName: String {
        guard let user = userService.currentUser else { return "—" }
        let fullName = "\(user.firstName) \(user.lastName)".trimmingCharacters(in: .whitespaces)
        return fullName.isEmpty ? user.username : fullName
    }

    /// Mock IBAN for display purposes on the statement header.
    /// In a real implementation this would come from a stored account profile.
    var accountIbanDisplay: String {
        "DE20 7007 0012 3456 78"
    }

    /// Statement index shown in the header (mocked as calendar month number).
    var statementNumber: Int {
        self.month
    }

    var hasTransactions: Bool {
        !self.entries.isEmpty
    }

    var totalCredits: Double {
        self.entries
            .filter { $0.direction == .credit }
            .reduce(0) { $0 + $1.amount }
    }

    var totalDebits: Double {
        self.entries
            .filter { $0.direction == .debit }
            .reduce(0) { $0 + $1.amount }
    }

    var netChange: Double {
        self.entries.reduce(0) { $0 + $1.signedAmount }
    }

    var netChangeFormatted: String {
        let prefix = self.netChange >= 0 ? "+" : "−"
        return "\(prefix)\(abs(self.netChange).formattedAsLocalizedCurrency())"
    }

    func load() {
        guard let currentUser = userService.currentUser else {
            self.entries = []
            self.openingBalance = 0
            self.closingBalance = 0
            return
        }

        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: DateComponents(year: self.year, month: self.month, day: 1)) ?? Date()
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth) ?? startOfMonth

        let allEntries: [AccountStatementEntry]
        var baseOpeningBalance: Double = 0
        switch currentUser.role {
        case .investor:
            let ledger = self.investorCashBalanceService.getTransactions(for: currentUser.id)
            let closingNow = self.investorCashBalanceService.getBalance(for: currentUser.id)
            let totalDeltaAll = ledger.reduce(0) { $0 + $1.signedAmount }
            baseOpeningBalance = closingNow - totalDeltaAll
            allEntries = ledger
        case .trader:
            let snapshot = TraderAccountStatementBuilder.buildSnapshot(
                for: currentUser,
                invoiceService: self.invoiceService,
                configurationService: self.configurationService
            )
            baseOpeningBalance = snapshot.openingBalance
            allEntries = snapshot.entries
        default:
            self.openingBalance = 0
            self.closingBalance = 0
            self.entries = []
            return
        }

        let preMonthDelta = allEntries
            .filter { $0.occurredAt < startOfMonth }
            .reduce(0) { $0 + $1.signedAmount }
        let monthDelta = allEntries
            .filter { $0.occurredAt >= startOfMonth && $0.occurredAt < startOfNextMonth }
            .reduce(0) { $0 + $1.signedAmount }

        self.openingBalance = baseOpeningBalance + preMonthDelta
        self.closingBalance = self.openingBalance + monthDelta

        let monthlyEntries = allEntries.filter { entry in
            entry.occurredAt >= startOfMonth && entry.occurredAt < startOfNextMonth
        }

        self.entries = monthlyEntries.sorted { $0.occurredAt > $1.occurredAt }
    }
}
