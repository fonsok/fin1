import Foundation
import Combine
import OSLog

// MARK: - Wallet ViewModel
/// ViewModel for wallet management (balance, deposits, withdrawals, transaction history)
@MainActor
final class WalletViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published private(set) var currentBalance: Double = 0.0
    @Published private(set) var formattedBalance: String = "€ 0,00"
    @Published private(set) var transactions: [Transaction] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published var showDepositSheet = false
    @Published var showWithdrawalSheet = false
    @Published var depositAmount: String = ""
    @Published var withdrawalAmount: String = ""
    @Published var showSuccessMessage = false
    @Published var successMessage: String = ""

    // MARK: - Dependencies

    private let cashBalanceService: any CashBalanceServiceProtocol
    private let investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    private let invoiceService: (any InvoiceServiceProtocol)?
    private let configurationService: any ConfigurationServiceProtocol
    private let paymentService: any PaymentServiceProtocol
    private let userService: any UserServiceProtocol
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?
    private let parseLiveQueryClient: (any ParseLiveQueryClientProtocol)?

    private var cancellables = Set<AnyCancellable>()
    private var liveQuerySubscription: LiveQuerySubscription?

    // MARK: - Initialization

    init(
        cashBalanceService: any CashBalanceServiceProtocol,
        paymentService: any PaymentServiceProtocol,
        userService: any UserServiceProtocol,
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        invoiceService: (any InvoiceServiceProtocol)? = nil,
        configurationService: any ConfigurationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil,
        parseLiveQueryClient: (any ParseLiveQueryClientProtocol)? = nil
    ) {
        self.cashBalanceService = cashBalanceService
        self.paymentService = paymentService
        self.userService = userService
        self.investorCashBalanceService = investorCashBalanceService
        self.invoiceService = invoiceService
        self.configurationService = configurationService
        self.settlementAPIService = settlementAPIService
        self.parseLiveQueryClient = parseLiveQueryClient

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe cash balance changes
        if let observableService = cashBalanceService as? CashBalanceService {
            observableService.$currentBalance
                .receive(on: DispatchQueue.main)
                .sink { [weak self] balance in
                    self?.updateBalance(balance)
                }
                .store(in: &cancellables)
        }

        // Observe Parse Live Query updates for Wallet Transactions
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

                // Reload wallet data when transaction is updated
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.loadWalletData()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Intent Methods

    func loadWalletData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        defer {
            Task { @MainActor in
                isLoading = false
            }
        }

        // Note: cash balance service is started by ServiceLifecycleCoordinator
        // No need to call start() here

        // Get user-specific balance based on role
        // This function is async and performs async operations (try await) in some code paths
        let balance = await getUserSpecificBalance()

        // Update balance
        await MainActor.run {
            updateBalance(balance)
        }

        // Load transaction history (handles errors internally)
        await loadTransactionHistory()

        // Subscribe to Live Query updates for Wallet Transactions
        await subscribeToLiveUpdates()
    }

    // MARK: - Live Query Integration

    private func subscribeToLiveUpdates() async {
        guard let liveQueryClient = parseLiveQueryClient,
              let userId = userService.currentUser?.id else {
            return
        }

        // Unsubscribe from previous subscription if exists
        if let existingSubscription = liveQuerySubscription {
            liveQueryClient.unsubscribe(existingSubscription)
        }

        // Subscribe to WalletTransaction updates for current user
        liveQuerySubscription = liveQueryClient.subscribe(
            className: "WalletTransaction",
            query: ["userId": userId],
            onUpdate: { [weak self] (parseTransaction: ParseWalletTransaction) in
                Task { @MainActor in
                    // Reload wallet data when transaction is updated
                    await self?.loadWalletData()
                }
            },
            onDelete: { [weak self] objectId in
                Task { @MainActor in
                    // Reload wallet data when transaction is deleted
                    await self?.loadWalletData()
                }
            },
            onError: { error in
                print("⚠️ Live Query error for WalletTransaction: \(error.localizedDescription)")
            }
        )
    }

    // MARK: - User-Specific Balance

    private func getUserSpecificBalance() async -> Double {
        guard let currentUser = userService.currentUser else {
            return cashBalanceService.currentBalance
        }

        switch currentUser.role {
        case .investor:
            // For investors, calculate balance from account statement snapshot (including wallet)
            if let investorService = investorCashBalanceService {
                let snapshot = await InvestorAccountStatementBuilder.buildSnapshotWithWallet(
                    for: currentUser,
                    investorCashBalanceService: investorService,
                    paymentService: paymentService,
                    settlementAPIService: settlementAPIService,
                    configurationService: configurationService
                )
                return snapshot.closingBalance
            }
            // Fallback to global cash balance service
            return cashBalanceService.currentBalance

        case .trader:
            // For traders, calculate balance from account statement snapshot (including wallet)
            if let invoiceService = invoiceService {
                let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(
                    for: currentUser,
                    invoiceService: invoiceService,
                    configurationService: configurationService,
                    paymentService: paymentService,
                    settlementAPIService: settlementAPIService
                )
                return snapshot.closingBalance
            }
            return cashBalanceService.currentBalance

        default:
            return cashBalanceService.currentBalance
        }
    }

    func refresh() async {
        await loadWalletData()
    }

    func deposit() async {
        guard let amount = parseAmount(depositAmount) else {
            errorMessage = "Bitte geben Sie einen gültigen Betrag ein."
            return
        }

        // Validate amount against limits
        if amount < CalculationConstants.PaymentLimits.minimumDeposit {
            errorMessage = "Der Mindestbetrag für Einzahlungen beträgt \(CalculationConstants.PaymentLimits.minimumDeposit.formatted(.currency(code: "EUR")))."
            return
        }

        if amount > CalculationConstants.PaymentLimits.maximumDeposit {
            errorMessage = "Der Maximalbetrag für Einzahlungen beträgt \(CalculationConstants.PaymentLimits.maximumDeposit.formatted(.currency(code: "EUR")))."
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let transaction = try await paymentService.deposit(amount: amount)

            // Clear input and close sheet
            depositAmount = ""
            showDepositSheet = false

            // Show success message
            successMessage = "Einzahlung von \(amount.formatted(.currency(code: "EUR"))) erfolgreich!"
            showSuccessMessage = true

            // Hide success message after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    showSuccessMessage = false
                }
            }

            // Reload data
            await loadWalletData()

            logger.info("✅ Deposit successful: \(transaction.id)")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Deposit failed: \(error.localizedDescription)")
        }
    }

    func withdraw() async {
        guard let amount = parseAmount(withdrawalAmount) else {
            errorMessage = "Bitte geben Sie einen gültigen Betrag ein."
            return
        }

        // Validate amount against limits
        if amount < CalculationConstants.PaymentLimits.minimumWithdrawal {
            errorMessage = "Der Mindestbetrag für Auszahlungen beträgt \(CalculationConstants.PaymentLimits.minimumWithdrawal.formatted(.currency(code: "EUR")))."
            return
        }

        if amount > CalculationConstants.PaymentLimits.maximumWithdrawal {
            errorMessage = "Der Maximalbetrag für Auszahlungen beträgt \(CalculationConstants.PaymentLimits.maximumWithdrawal.formatted(.currency(code: "EUR")))."
            return
        }

        // Check if withdrawal is allowed
        do {
            guard try await paymentService.canWithdraw(amount: amount) else {
                errorMessage = "Unzureichendes Guthaben für diese Auszahlung."
                return
            }
        } catch {
            errorMessage = "Fehler bei der Überprüfung: \(error.localizedDescription)"
            return
        }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let transaction = try await paymentService.withdraw(amount: amount)

            // Clear input and close sheet
            withdrawalAmount = ""
            showWithdrawalSheet = false

            // Show success message
            successMessage = "Auszahlung von \(amount.formatted(.currency(code: "EUR"))) erfolgreich!"
            showSuccessMessage = true

            // Hide success message after 3 seconds
            Task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    showSuccessMessage = false
                }
            }

            // Reload data
            await loadWalletData()

            logger.info("✅ Withdrawal successful: \(transaction.id)")
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Withdrawal failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Private Methods

    private func updateBalance(_ balance: Double) {
        currentBalance = balance
        formattedBalance = balance.formatted(.currency(code: "EUR"))
    }

    private func loadTransactionHistory() async {
        do {
            let history = try await paymentService.getTransactionHistory(limit: 50, offset: 0)
            await MainActor.run {
                transactions = history
            }
        } catch {
            logger.error("Failed to load transaction history: \(error.localizedDescription)")
            // Don't show error to user, just log it
            await MainActor.run {
                transactions = []
            }
        }
    }

    private func parseAmount(_ amountString: String) -> Double? {
        // Remove currency symbols and whitespace
        let cleaned = amountString
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)

        return Double(cleaned)
    }

    // MARK: - Logger

    private let logger = Logger(subsystem: "com.fin1.app", category: "WalletViewModel")
}
