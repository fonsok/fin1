import Foundation
import Combine

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
            applyFilters()
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

        setupNotificationObservers()
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
            .store(in: &cancellables)

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
            .store(in: &cancellables)

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
            .store(in: &cancellables)

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
            .store(in: &cancellables)

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
            .store(in: &cancellables)
    }

    // MARK: - Intent

    func refresh() {
        guard !isLoading else { return }

        Task {
            await MainActor.run {
                isLoading = true
            }

            defer {
                Task { @MainActor in
                    isLoading = false
                }
            }

            guard let currentUser = userService.currentUser else {
                await MainActor.run {
                    entries = []
                    filteredEntries = []
                    currentBalance = 0
                    openingBalance = 0
                    errorMessage = "No active user session"
                }
                return
            }

            await MainActor.run {
                userRole = currentUser.role
                errorMessage = nil
            }

            switch currentUser.role {
            case .investor:
                await buildInvestorStatement(for: currentUser)
            case .trader:
                await buildTraderStatement(for: currentUser)
            default:
                await MainActor.run {
                    entries = []
                    currentBalance = 0
                    openingBalance = 0
                }
            }

            await MainActor.run {
                applyFilters()
            }
        }
    }

    // MARK: - Computed Summaries

    var totalCredits: Double {
        filteredEntries
            .filter { $0.direction == .credit }
            .reduce(0) { $0 + $1.amount }
    }

    var totalDebits: Double {
        filteredEntries
            .filter { $0.direction == .debit }
            .reduce(0) { $0 + $1.amount }
    }

    var netChange: Double {
        filteredEntries.reduce(0) { $0 + $1.signedAmount }
    }

    var hasTransactions: Bool {
        !filteredEntries.isEmpty
    }

    // MARK: - Private Builders

    private func buildInvestorStatement(for user: User) async {
        let snapshot = await InvestorAccountStatementBuilder.buildSnapshotWithWallet(
            for: user,
            investorCashBalanceService: investorCashBalanceService,
            paymentService: paymentService,
            settlementAPIService: settlementAPIService,
            configurationService: configurationService
        )

        await MainActor.run {
            openingBalance = snapshot.openingBalance
            currentBalance = snapshot.closingBalance
            entries = snapshot.entries
            errorMessage = nil
        }
    }

    private func buildTraderStatement(for user: User) async {
        let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(
            for: user,
            invoiceService: invoiceService,
            configurationService: configurationService,
            paymentService: paymentService,
            settlementAPIService: settlementAPIService
        )

        let totalDelta = snapshot.entries.reduce(0) { $0 + $1.signedAmount }
        let calculatedOpening = snapshot.closingBalance - totalDelta

        await MainActor.run {
            openingBalance = max(0, calculatedOpening)
            currentBalance = snapshot.closingBalance
            entries = snapshot.entries
            errorMessage = nil
        }
    }

    private func applyFilters() {
        guard !entries.isEmpty else {
            filteredEntries = []
            return
        }

        let thresholdDate = selectedRange.startDate()
        filteredEntries = entries.filter { $0.occurredAt >= thresholdDate }
    }
}
