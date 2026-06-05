import Combine
import Foundation

// MARK: - Dashboard Stats ViewModel
/// ViewModel for DashboardStatsSection following MVVM architecture
/// Handles all business logic, calculations, and data transformations
@MainActor
final class DashboardStatsViewModel: ObservableObject {

    // MARK: - Published Properties (UI State)

    @Published var investorBalance: String = "€ 0,00"
    @Published var activeInvestmentsCount: Int = 0
    @Published var activeTradesCount: String = "-"
    @Published var accountBalance: Double = 0.0
    @Published var depotValue: Double = 0.0
    @Published var traderPoolsStatus: String = "not active"

    // MARK: - Dependencies

    private let userService: any UserServiceProtocol
    private let investmentService: any InvestmentServiceProtocol
    private let investorCashBalanceService: any InvestorCashBalanceServiceProtocol
    private let traderService: any TraderServiceProtocol
    private let traderDataService: any TraderDataServiceProtocol
    private let invoiceService: any InvoiceServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let holdingsConversionService: any HoldingsConversionServiceProtocol
    private let paymentService: (any PaymentServiceProtocol)?
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var isInvestor: Bool {
        self.userService.currentUser?.role == .investor
    }

    var isTrader: Bool {
        self.userService.currentUser?.role == .trader
    }

    var currentUserId: String? {
        self.userService.currentUser?.id
    }

    // MARK: - Initialization

    init(
        userService: any UserServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        traderService: any TraderServiceProtocol,
        traderDataService: any TraderDataServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        holdingsConversionService: any HoldingsConversionServiceProtocol,
        paymentService: (any PaymentServiceProtocol)? = nil,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.userService = userService
        self.investmentService = investmentService
        self.investorCashBalanceService = investorCashBalanceService
        self.traderService = traderService
        self.traderDataService = traderDataService
        self.invoiceService = invoiceService
        self.configurationService = configurationService
        self.holdingsConversionService = holdingsConversionService
        self.paymentService = paymentService
        self.settlementAPIService = settlementAPIService

        self.setupNotificationObservers()
    }

    /// Convenience initializer using AppServices
    convenience init(appServices: AppServices) {
        self.init(
            userService: appServices.userService,
            investmentService: appServices.investmentService,
            investorCashBalanceService: appServices.investorCashBalanceService,
            traderService: appServices.traderService,
            traderDataService: appServices.traderDataService,
            invoiceService: appServices.invoiceService,
            configurationService: appServices.configurationService,
            holdingsConversionService: appServices.holdingsConversionService,
            paymentService: appServices.paymentService,
            settlementAPIService: appServices.settlementAPIService
        )
    }

    // MARK: - Setup

    private func setupNotificationObservers() {
        // User sign in
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshAllData()
            }
            .store(in: &self.cancellables)

        // Investor balance changed
        NotificationCenter.default.publisher(for: .investorBalanceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let investorId = userInfo["investorId"] as? String,
                      investorId == self.currentUserId else { return }
                self.updateInvestorBalance()
            }
            .store(in: &self.cancellables)

        // Investment completed
        NotificationCenter.default.publisher(for: .investmentCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActiveInvestmentsCount()
            }
            .store(in: &self.cancellables)

        // Investment status updated
        NotificationCenter.default.publisher(for: .investmentStatusUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActiveInvestmentsCount()
            }
            .store(in: &self.cancellables)

        // Wallet transaction completed (deposit/withdrawal)
        NotificationCenter.default.publisher(for: .walletTransactionCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let userId = userInfo["userId"] as? String,
                      userId == self.currentUserId else { return }
                // Refresh balance for both investors and traders
                self.refreshAllData()
            }
            .store(in: &self.cancellables)

        // Trader balance changed (for trader role)
        NotificationCenter.default.publisher(for: .traderBalanceDidChange)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let userInfo = notification.userInfo,
                      let traderId = userInfo["traderId"] as? String,
                      traderId == self.currentUserId else { return }
                // Refresh trader account balance
                if self.isTrader {
                    self.updateTraderAccountBalance()
                }
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
                      userId == self.currentUserId else {
                    return
                }

                // Refresh all data when wallet transaction is updated via Live Query
                self.refreshAllData()
            }
            .store(in: &self.cancellables)
    }

    // MARK: - Public Methods

    /// Called when view appears or needs refresh
    func refreshAllData() {
        if self.isInvestor {
            self.updateInvestorBalance()
            self.updateActiveInvestmentsCount()
        } else if self.isTrader {
            self.updateTraderAccountBalance()
            self.updateDepotValue()
            self.updateTraderPoolsStatus()
        }
    }

    /// Called on view appear via .task modifier
    func onViewAppear() async {
        await self.ensureInvoicesGenerated()
        self.refreshAllData()
    }

    /// Called when investments count changes
    func onInvestmentsCountChange() {
        self.updateInvestorBalance()
        self.updateActiveInvestmentsCount()
    }

    // MARK: - Investor Data Updates

    private func updateInvestorBalance() {
        guard let currentUser = userService.currentUser else {
            self.investorBalance = "€ 0,00"
            return
        }

        Task { @MainActor in
            let snapshot = await InvestorAccountStatementBuilder.buildSnapshotWithWallet(
                for: currentUser,
                investorCashBalanceService: self.investorCashBalanceService,
                paymentService: self.paymentService,
                settlementAPIService: self.settlementAPIService,
                configurationService: self.configurationService
            )
            self.investorBalance = snapshot.closingBalance.formatted(.currency(code: "EUR"))
        }
    }

    private func updateActiveInvestmentsCount() {
        guard let currentUser = userService.currentUser else {
            self.activeInvestmentsCount = 0
            return
        }
        let investorInvestments = self.investmentService.getInvestments(
            matchingAnyOf: currentUser.ledgerUserIdCandidates
        )
        self.activeInvestmentsCount = investorInvestments.filter(\.isOpenPosition).count
    }

    // MARK: - Trader Data Updates

    private func updateTraderAccountBalance() {
        Task {
            let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(
                for: self.userService.currentUser,
                invoiceService: self.invoiceService,
                configurationService: self.configurationService,
                paymentService: self.paymentService,
                settlementAPIService: self.settlementAPIService
            )

            await MainActor.run {
                self.accountBalance = snapshot.closingBalance
            }
        }
    }

    private func updateDepotValue() {
        guard let currentTraderId = currentUserId else {
            self.depotValue = 0.0
            return
        }

        let completedTrades = self.traderService.completedTrades
            .filter { $0.traderId == currentTraderId }

        guard !completedTrades.isEmpty else {
            self.depotValue = 0.0
            return
        }

        // Calculate total depot value from remaining holdings
        let totalValue = completedTrades.compactMap { trade -> Double? in
            let holding = self.holdingsConversionService.createHolding(
                from: trade,
                position: 1,
                ongoingOrders: []
            )
            return Double(holding.remainingQuantity) * holding.currentPrice
        }.reduce(0, +)

        self.depotValue = totalValue
    }

    private func updateTraderPoolsStatus() {
        guard let currentUser = userService.currentUser else {
            self.traderPoolsStatus = "not active"
            return
        }

        let traderId = self.findTraderIdForMatching() ?? currentUser.id
        let traderIdCandidates = self.traderIdCandidatesForPoolMatching(primaryTraderId: traderId)

        let traderInvestments = self.investmentService.investments.filter { investment in
            self.investmentMatchesTraderCandidates(investment, candidates: traderIdCandidates) && investment.isOpenPosition
        }

        let hasRelevantInvestments = traderInvestments.contains { $0.hasPoolCapitalCommitted }

        self.traderPoolsStatus = hasRelevantInvestments ? "active" : "not active"
    }

    // MARK: - Helper Methods

    private func findTraderIdForMatching() -> String? {
        TraderMatchingHelper.findTraderIdForMatching(
            currentUser: self.userService.currentUser,
            traderDataService: self.traderDataService
        )
    }

    private func traderIdCandidatesForPoolMatching(primaryTraderId: String) -> Set<String> {
        var candidates = [primaryTraderId]
        if let user = userService.currentUser {
            candidates.append(user.id)
            let email = user.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !email.isEmpty {
                candidates.append(email)
                candidates.append("user:\(email)")
                if let username = email.split(separator: "@").first.map(String.init), !username.isEmpty {
                    candidates.append(username)
                }
            }
        }
        return Set(
            candidates
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty },
        )
    }

    private func investmentMatchesTraderCandidates(_ investment: Investment, candidates: Set<String>) -> Bool {
        let traderKey = investment.traderId.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if candidates.contains(traderKey) { return true }
        let username = investment.traderUsername?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if !username.isEmpty, candidates.contains(username) { return true }
        return false
    }

    /// Generate invoices for any completed trades that don't have invoices yet
    private func ensureInvoicesGenerated() async {
        guard let currentTraderId = currentUserId else { return }

        let completedTrades = self.traderService.completedTrades
            .filter { $0.traderId == currentTraderId }

        if !completedTrades.isEmpty {
            await self.invoiceService.generateInvoicesForCompletedTrades(completedTrades)
        }
    }
}











