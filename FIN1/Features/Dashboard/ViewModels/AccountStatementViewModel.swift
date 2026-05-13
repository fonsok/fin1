import Combine
import Foundation

// MARK: - Account Statement ViewModel
/// ViewModel for displaying account statements for investors and traders
@MainActor
final class AccountStatementViewModel: ObservableObject {

    // MARK: - Published State
    @Published private(set) var entries: [AccountStatementEntry] = []
    @Published private(set) var filteredEntries: [AccountStatementEntry] = []
    @Published private(set) var currentBalance: Double = 0
    @Published private(set) var openingBalance: Double = 0
    @Published private(set) var userRole: UserRole?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var selectedRange: AccountStatementRange = .lastMonth {
        didSet {
            self.applyFilters()
        }
    }

    // MARK: - Dependencies
    private let userService: any UserServiceProtocol
    private let investorCashBalanceService: any InvestorCashBalanceServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let traderDataService: (any TraderDataServiceProtocol)?
    private let paymentService: (any PaymentServiceProtocol)?
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(services: AppServices) {
        self.userService = services.userService
        self.investorCashBalanceService = services.investorCashBalanceService
        self.invoiceService = services.invoiceService
        self.configurationService = services.configurationService
        self.traderDataService = services.traderDataService
        self.paymentService = services.paymentService
        self.settlementAPIService = services.settlementAPIService

        self.setupNotificationObservers()
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        // Investor balance changed
        NotificationCenter.default.publisher(for: .investorBalanceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let investorId = userInfo["investorId"] as? String,
                      investorId == self.userService.currentUser?.id,
                      self.userService.currentUser?.role == .investor else {
                    return
                }
                // Refresh account statement when investor balance changes
                self.refresh()
            }
            .store(in: &self.cancellables)

        // Trader balance changed
        NotificationCenter.default.publisher(for: .traderBalanceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let traderId = userInfo["traderId"] as? String,
                      traderId == self.userService.currentUser?.id,
                      self.userService.currentUser?.role == .trader else {
                    return
                }
                // Refresh account statement when trader balance changes
                self.refresh()
            }
            .store(in: &self.cancellables)

        // Wallet transaction completed
        NotificationCenter.default.publisher(for: .walletTransactionCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let userId = userInfo["userId"] as? String,
                      userId == self.userService.currentUser?.id else {
                    return
                }
                // Refresh account statement when wallet transaction is completed
                self.refresh()
            }
            .store(in: &self.cancellables)

        // Parse Live Query updates for Wallet Transactions
        NotificationCenter.default.publisher(for: .parseLiveQueryObjectUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let className = userInfo["className"] as? String,
                      className == "WalletTransaction",
                      let object = userInfo["object"] as? [String: Any],
                      let userId = object["userId"] as? String,
                      userId == self.userService.currentUser?.id else {
                    return
                }

                // Refresh account statement when wallet transaction is updated via Live Query
                self.refresh()
            }
            .store(in: &self.cancellables)

        // Invoice added/changed (credit notes, trade invoices)
        NotificationCenter.default.publisher(for: .invoiceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self,
                      self.userService.currentUser != nil else {
                    return
                }
                self.refresh()
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Intent

    func refresh() {
        guard !self.isLoading else { return }

        Task {
            await MainActor.run {
                self.isLoading = true
            }

            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }

            guard let currentUser = userService.currentUser else {
                await MainActor.run {
                    self.entries = []
                    self.filteredEntries = []
                    self.currentBalance = 0
                    self.openingBalance = 0
                    self.errorMessage = "No active user session"
                }
                return
            }

            await MainActor.run {
                self.userRole = currentUser.role
                self.errorMessage = nil
            }

            switch currentUser.role {
            case .investor:
                await self.buildInvestorStatement(for: currentUser)
            case .trader:
                await self.buildTraderStatement(for: currentUser)
            default:
                await MainActor.run {
                    self.entries = []
                    self.currentBalance = 0
                    self.openingBalance = 0
                }
            }

            await MainActor.run {
                self.applyFilters()
            }
        }
    }

    // MARK: - Computed Summaries

    var totalCredits: Double {
        self.filteredEntries
            .filter { $0.direction == .credit }
            .reduce(0) { $0 + $1.amount }
    }

    var totalDebits: Double {
        self.filteredEntries
            .filter { $0.direction == .debit }
            .reduce(0) { $0 + $1.amount }
    }

    var netChange: Double {
        self.filteredEntries.reduce(0) { $0 + $1.signedAmount }
    }

    var hasTransactions: Bool {
        !self.filteredEntries.isEmpty
    }

    // MARK: - Private Builders

    private func buildInvestorStatement(for user: User) async {
        let snapshot = await InvestorAccountStatementBuilder.buildSnapshotWithWallet(
            for: user,
            investorCashBalanceService: self.investorCashBalanceService,
            paymentService: self.paymentService,
            settlementAPIService: self.settlementAPIService,
            configurationService: self.configurationService
        )

        await MainActor.run {
            self.openingBalance = snapshot.openingBalance
            self.currentBalance = snapshot.closingBalance
            self.entries = snapshot.entries
            self.errorMessage = nil
        }
    }

    private func buildTraderStatement(for user: User) async {
        let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(
            for: user,
            invoiceService: self.invoiceService,
            configurationService: self.configurationService,
            paymentService: self.paymentService,
            settlementAPIService: self.settlementAPIService
        )

        let totalDelta = snapshot.entries.reduce(0) { $0 + $1.signedAmount }
        let calculatedOpening = snapshot.closingBalance - totalDelta

        await MainActor.run {
            self.openingBalance = max(0, calculatedOpening)
            self.currentBalance = snapshot.closingBalance
            self.entries = snapshot.entries
            self.errorMessage = nil
        }
    }

    private func applyFilters() {
        guard !self.entries.isEmpty else {
            self.filteredEntries = []
            return
        }

        let thresholdDate = self.selectedRange.startDate()
        self.filteredEntries = self.entries.filter { $0.occurredAt >= thresholdDate }
    }
}
