import Foundation
import Combine

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

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var isInvestor: Bool {
        userService.currentUser?.role == .investor
    }

    var isTrader: Bool {
        userService.currentUser?.role == .trader
    }

    var currentUserId: String? {
        userService.currentUser?.id
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
        paymentService: (any PaymentServiceProtocol)? = nil
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

        setupNotificationObservers()
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
            paymentService: appServices.paymentService
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
            .store(in: &cancellables)

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
            .store(in: &cancellables)

        // Investment completed
        NotificationCenter.default.publisher(for: .investmentCompleted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActiveInvestmentsCount()
            }
            .store(in: &cancellables)

        // Investment status updated
        NotificationCenter.default.publisher(for: .investmentStatusUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateActiveInvestmentsCount()
            }
            .store(in: &cancellables)

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
            .store(in: &cancellables)

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
                      userId == self.currentUserId else {
                    return
                }

                // Refresh all data when wallet transaction is updated via Live Query
                self.refreshAllData()
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Called when view appears or needs refresh
    func refreshAllData() {
        if isInvestor {
            updateInvestorBalance()
            updateActiveInvestmentsCount()
        } else if isTrader {
            updateTraderAccountBalance()
            updateDepotValue()
            updateTraderPoolsStatus()
        }
    }

    /// Called on view appear via .task modifier
    func onViewAppear() async {
        await ensureInvoicesGenerated()
        refreshAllData()
    }

    /// Called when investments count changes
    func onInvestmentsCountChange() {
        updateInvestorBalance()
        updateActiveInvestmentsCount()
    }

    // MARK: - Investor Data Updates

    private func updateInvestorBalance() {
        guard let currentUserId = currentUserId,
              let currentUser = userService.currentUser else {
            investorBalance = "€ 0,00"
            return
        }

        // Use single source of truth for investor balance (consistent with trader)
        Task {
            let snapshot = await InvestorAccountStatementBuilder.buildSnapshotWithWallet(
                for: currentUser,
                investorCashBalanceService: investorCashBalanceService,
                paymentService: paymentService
            )

            await MainActor.run {
                investorBalance = snapshot.closingBalance.formatted(.currency(code: "EUR"))
            }
        }
    }

    private func updateActiveInvestmentsCount() {
        guard let currentUserId = currentUserId else {
            activeInvestmentsCount = 0
            return
        }
        let investorInvestments = investmentService.getInvestments(for: currentUserId)
        activeInvestmentsCount = investorInvestments.filter { $0.status == .active }.count
    }

    // MARK: - Trader Data Updates

    private func updateTraderAccountBalance() {
        Task {
            let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(
                for: userService.currentUser,
                invoiceService: invoiceService,
                configurationService: configurationService,
                paymentService: paymentService
            )

            await MainActor.run {
                accountBalance = snapshot.closingBalance
            }
        }
    }

    private func updateDepotValue() {
        guard let currentTraderId = currentUserId else {
            depotValue = 0.0
            return
        }

        let completedTrades = traderService.completedTrades
            .filter { $0.traderId == currentTraderId }

        guard !completedTrades.isEmpty else {
            depotValue = 0.0
            return
        }

        // Calculate total depot value from remaining holdings
        let totalValue = completedTrades.compactMap { trade -> Double? in
            let holding = holdingsConversionService.createHolding(
                from: trade,
                position: 1,
                ongoingOrders: []
            )
            return Double(holding.remainingQuantity) * holding.currentPrice
        }.reduce(0, +)

        depotValue = totalValue
    }

    private func updateTraderPoolsStatus() {
        guard let currentUser = userService.currentUser else {
            traderPoolsStatus = "not active"
            return
        }

        let traderId = findTraderIdForMatching() ?? currentUser.id

        let traderInvestments = investmentService.getInvestments(forTrader: traderId)
            .filter { $0.status == .active }

        let hasRelevantInvestments = traderInvestments.contains { investment in
            investment.reservationStatus == .reserved || investment.reservationStatus == .active
        }

        traderPoolsStatus = hasRelevantInvestments ? "active" : "not active"
    }

    // MARK: - Helper Methods

    /// Finds the trader ID to use for investment matching
    /// First tries to find MockTrader by username from user's email, then falls back to user ID
    private func findTraderIdForMatching() -> String? {
        guard let currentUser = userService.currentUser else {
            return nil
        }

        // Extract username from email (e.g., "trader3@test.com" -> "trader3")
        let username = currentUser.email.components(separatedBy: "@").first ?? ""

        // 1) Exact username match
        if let mockTrader = traderDataService.traders.first(where: { $0.username == username }) {
            return mockTrader.id.uuidString
        }

        // 2) Try display name match (FirstName LastName) against MockTrader.name
        let displayName = "\(currentUser.firstName) \(currentUser.lastName)".trimmingCharacters(in: .whitespaces)
        if let byName = traderDataService.traders.first(where: { $0.name.caseInsensitiveCompare(displayName) == .orderedSame }) {
            return byName.id.uuidString
        }

        // 3) Fuzzy contains on name as last resort
        if let fuzzy = traderDataService.traders.first(where: { $0.name.localizedCaseInsensitiveContains(username) }) {
            return fuzzy.id.uuidString
        }

        // Fallback to user ID
        return currentUser.id
    }

    /// Generate invoices for any completed trades that don't have invoices yet
    private func ensureInvoicesGenerated() async {
        guard let currentTraderId = currentUserId else { return }

        let completedTrades = traderService.completedTrades
            .filter { $0.traderId == currentTraderId }

        if !completedTrades.isEmpty {
            await invoiceService.generateInvoicesForCompletedTrades(completedTrades)
        }
    }
}











