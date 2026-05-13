import Combine
import Foundation

// MARK: - Investor Cash Balance Service

/// Service for managing investor cash balances with per-investor tracking
@MainActor
final class InvestorCashBalanceService: InvestorCashBalanceServiceProtocol, ObservableObject {

    // MARK: - Properties

    /// Dictionary to store balances per investor (investorId -> balance)
    @Published var balances: [String: Double] = [:]
    /// Ledger service for transaction recording
    let ledgerService: InvestorCashBalanceLedgerService
    let configurationService: any ConfigurationServiceProtocol
    let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?
    let userService: (any UserServiceProtocol)?
    var initialInvestorBalance: Double
    let queue = DispatchQueue(label: "com.fin.app.investorcashbalance", attributes: .concurrent)
    var liveQuerySubscriptions: [String: LiveQuerySubscription] = [:]
    var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        configurationService: any ConfigurationServiceProtocol,
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil,
        userService: (any UserServiceProtocol)? = nil
    ) {
        self.configurationService = configurationService
        self.parseLiveQueryClient = parseLiveQueryClient
        self.userService = userService
        self.ledgerService = InvestorCashBalanceLedgerService()
        self.initialInvestorBalance = configurationService.initialAccountBalance
        setupLiveQuerySubscription()
        observeConfigChanges()
        Task { await self.subscribeToLiveUpdates() }
    }

    // MARK: - Public Methods

    func getBalance(for investorId: String) -> Double {
        return self.queue.sync {
            return self.balances[investorId] ?? self.initialInvestorBalance
        }
    }

    func getFormattedBalance(for investorId: String) -> String {
        let balance = self.getBalance(for: investorId)
        return balance.formatted(.currency(code: "EUR"))
    }

    func getTransactions(for investorId: String) -> [AccountStatementEntry] {
        self.ledgerService.getLedgerEntries(for: investorId)
    }
}
