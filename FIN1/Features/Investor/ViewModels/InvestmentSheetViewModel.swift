import Foundation
import SwiftUI

// MARK: - Investment Sheet View Model
/// ViewModel for InvestmentSheet following MVVM architecture
/// Handles all business logic, calculations, validation, and state management
@MainActor
final class InvestmentSheetViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var investmentAmount: String = String(
        Int(CalculationConstants.Investment.defaultAmount)
    )
    @Published var selectedInvestmentSelection: InvestmentSelectionStrategy = .multipleInvestments
    @Published var numberOfInvestments: Int = 3
    @Published var showInvestmentError = false
    @Published var investmentErrorMessage = ""
    @Published var showSuccess = false
    @Published var isLoading = false
    @Published var isCommissionConfirmed = false
    @Published private(set) var poolMirrorCapacity: PoolMirrorCapacityStatus?
    @Published var poolMirrorAlertSubscribed = false
    @Published var isUpdatingPoolMirrorAlert = false
    @Published private(set) var isHydratingTraderIdentity = false

    private var poolMirrorRefreshTask: Task<Void, Never>?
    @Published private(set) var trader: InvestorTrader
    private let userService: any UserServiceProtocol
    private let investmentService: any InvestmentServiceProtocol
    private let telemetryService: any TelemetryServiceProtocol
    private let investorCashBalanceService: any InvestorCashBalanceServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let parseAPIClient: (any ParseAPIClientProtocol)?
    private let onInvestmentSuccess: (() -> Void)?

    // MARK: - Initialization
    init(
        trader: InvestorTrader,
        userService: any UserServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        telemetryService: any TelemetryServiceProtocol,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil,
        onInvestmentSuccess: (() -> Void)? = nil
    ) {
        self.trader = trader
        self.userService = userService
        self.investmentService = investmentService
        self.telemetryService = telemetryService
        self.investorCashBalanceService = investorCashBalanceService
        self.configurationService = configurationService
        self.parseAPIClient = parseAPIClient
        self.onInvestmentSuccess = onInvestmentSuccess
    }

    // MARK: - Computed Properties (Business Logic)

    var currentUser: User? {
        self.userService.currentUser
    }

    var amountPerInvestment: Double {
        let totalAmount = Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        return totalAmount > 0 ? totalAmount / Double(self.numberOfInvestments) : 0
    }

    var totalInvestmentAmount: Double {
        Double(self.investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
    }

    /// Calculates the app service charge for the current investment amount
    /// - Note: Service charge applies ONLY to investors (not traders)
    var appServiceCharge: Double {
        self.totalInvestmentAmount * self.configurationService.effectiveAppServiceChargeRate
    }

    /// Total amount required (investment + app service charge)
    var totalRequiredAmount: Double {
        self.totalInvestmentAmount + self.appServiceCharge
    }

    /// Validates that cash balance after investment + fee will be >= minimum cash reserve
    var hasSufficientCashBalance: Bool {
        guard let currentUser = currentUser else { return false }
        let currentBalance = self.investorCashBalanceService.getBalance(for: currentUser.id)
        let remainingBalance = currentBalance - self.totalRequiredAmount
        let minimumReserve = self.configurationService.getMinimumCashReserve(for: currentUser.id)
        return remainingBalance >= minimumReserve
    }

    /// Shows warning when cash balance is insufficient
    var showInsufficientCashBalanceWarning: Bool {
        guard !self.investmentAmount.isEmpty,
              Double(self.investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0 > 0 else {
            return false
        }
        return !self.hasSufficientCashBalance
    }

    /// Message explaining insufficient cash balance
    var insufficientCashBalanceMessage: String {
        guard let currentUser = currentUser else {
            return "Please log in to check your balance."
        }
        let currentBalance = self.investorCashBalanceService.getBalance(for: currentUser.id)
        let remainingBalance = currentBalance - self.totalRequiredAmount
        let minimumRequired = self.configurationService.getMinimumCashReserve(for: currentUser.id)
        let shortfall = max(0, minimumRequired - remainingBalance)

        return "Insufficient funds. Current balance: \(currentBalance.formattedAsLocalizedCurrency()), Estimated after investment: \(remainingBalance.formattedAsLocalizedCurrency()). Need \(shortfall.formattedAsLocalizedCurrency()) more to maintain minimum reserve of \(minimumRequired.formattedAsLocalizedCurrency())."
    }

    /// Current cash balance for the investor
    var currentCashBalance: Double {
        guard let currentUser = currentUser else { return 0 }
        return self.investorCashBalanceService.getBalance(for: currentUser.id)
    }

    /// Remaining balance after investment and fee
    var remainingBalanceAfterInvestment: Double {
        guard let currentUser = currentUser else { return 0 }
        let currentBalance = self.investorCashBalanceService.getBalance(for: currentUser.id)
        return currentBalance - self.totalRequiredAmount
    }

    var canProceed: Bool {
        let total = Double(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        let perSlot = self.amountPerInvestment
        let minSlot = self.configurationService.minimumInvestmentAmount
        let maxSlot = self.configurationService.maximumInvestmentAmount
        let withinSlotLimits = total > 0 && perSlot >= minSlot && perSlot <= maxSlot
        let poolAllows = !(self.poolMirrorCapacity?.blocksInvestment ?? false)

        return !self.investmentAmount.isEmpty &&
            total > 0 &&
            withinSlotLimits &&
            self.numberOfInvestments >= 1 &&
            self.numberOfInvestments <= 10 &&
            self.hasSufficientCashBalance &&
            poolAllows &&
            self.isCommissionConfirmed &&
            self.hasTraderIdentityForInvesting &&
            !self.isHydratingTraderIdentity
    }

    /// Parse `objectId` bekannt oder mindestens `username` für Server-Auflösung (`resolveTraderParseUser`).
    var hasTraderIdentityForInvesting: Bool {
        if self.trader.hasParseUserId { return true }
        return !self.trader.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Blockiert Anlage nur ohne jede Trader-Server-Identität (nicht während Hydration).
    var traderIdentityBlockedMessage: String? {
        if self.isHydratingTraderIdentity || self.hasTraderIdentityForInvesting {
            return nil
        }
        return "Trader-Verbindung zum Server fehlt. Bitte kurz warten und erneut versuchen."
    }

    var isHydratingTraderIdentityMessage: Bool {
        self.isHydratingTraderIdentity && !self.trader.hasParseUserId
    }

    /// Pool ≥95 % belegt — Hinweis ohne Betragseingabe.
    var showPoolMirrorCapacityBlockedProactive: Bool {
        guard let cap = self.poolMirrorCapacity, cap.capEnabled else { return false }
        return cap.isPoolNearlyFull
    }

    /// Nur nach Eingabe, wenn Betrag die Restkapazität sprengt (Pool noch unter 95 %).
    var showPoolMirrorMaxInvestableOnInput: Bool {
        guard let cap = self.poolMirrorCapacity, cap.capEnabled else { return false }
        guard !cap.isPoolNearlyFull else { return false }
        guard self.totalInvestmentAmount > 0 else { return false }
        return cap.wouldExceed
    }

    var poolMirrorCapacityBlockedProactiveMessage: String {
        "Aktuell ist ein Investment in den nächsten Trade nicht möglich."
    }

    var poolMirrorMaxInvestableOnInputMessage: String {
        guard let cap = self.poolMirrorCapacity else { return "" }
        let maxInvestable = (cap.maxInvestableAmountForNextTrade ?? cap.remainingCapacity ?? 0)
            .formattedAsLocalizedCurrency()
        let traderLabel = self.trader.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return
            "Für den nächsten Trade von \(traderLabel) ist derzeit nur ein Investment von maximal \(maxInvestable) möglich."
    }

    var showPoolMirrorCapacityNotifyButton: Bool {
        guard let cap = self.poolMirrorCapacity, cap.capEnabled else { return false }
        return cap.isPoolNearlyFull
    }

    /// Positive total entered, slot count valid, but amount per slot violates admin min/max (so „Invest“ stays disabled).
    var showInvestmentSlotLimitHint: Bool {
        let total = self.totalInvestmentAmount
        guard total > 0,
              self.numberOfInvestments >= 1,
              self.numberOfInvestments <= 10 else { return false }
        let per = self.amountPerInvestment
        let minSlot = self.configurationService.minimumInvestmentAmount
        let maxSlot = self.configurationService.maximumInvestmentAmount
        return per < minSlot || per > maxSlot
    }

    var investmentSlotLimitHintMessage: String {
        let per = self.amountPerInvestment
        let minSlot = self.configurationService.minimumInvestmentAmount
        let maxSlot = self.configurationService.maximumInvestmentAmount
        let perFormatted = per.formattedAsLocalizedCurrency()
        if per < minSlot {
            return
                "Der Betrag je Anlageposition beträgt \(perFormatted), erlaubt sind mindestens \(minSlot.formattedAsLocalizedCurrency()). " +
                "Erhöhen Sie den Gesamtbetrag oder reduzieren Sie die Anzahl der Anlagen."
        }
        if per > maxSlot {
            return
                "Der Betrag je Anlageposition beträgt \(perFormatted), erlaubt sind höchstens \(maxSlot.formattedAsLocalizedCurrency()). " +
                "Erhöhen Sie die Anzahl der Anlagen oder senken Sie den Gesamtbetrag."
        }
        return ""
    }

    // MARK: - Server-aligned limits (best practices: refresh getConfig before investing)

    /// Pulls latest `getConfig` limits/fees, then caps the total amount field to the configured maximum.
    func prepareForInvestingFlow(traderDataService: (any TraderDataServiceProtocol)? = nil) async {
        if let traderDataService {
            await self.hydrateTraderFromDataService(traderDataService)
        }
        await self.configurationService.refreshConfigurationFromServerIfAvailable()
        self.applyConfiguredMaximumToAmountField()
        await self.refreshPoolMirrorCapacity()
    }

    /// Ensures `trader` carries Parse `objectId` before investments / pool-mirror API calls.
    func hydrateTraderFromDataService(_ traderDataService: (any TraderDataServiceProtocol)?) async {
        self.isHydratingTraderIdentity = true
        defer { self.isHydratingTraderIdentity = false }

        if let traderDataService {
            await traderDataService.refreshTraderCatalog()
            let usernameKey = self.trader.username.lowercased()
            if let match = traderDataService.traders.first(where: {
                $0.username.lowercased() == usernameKey
            }), match.hasParseUserId {
                self.trader = match
                return
            }
        }

        guard let client = self.parseAPIClient else { return }
        let usernameKey = self.trader.username.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !usernameKey.isEmpty else { return }

        do {
            let map = try await TraderDiscoveryAPIService(apiClient: client).fetchUsernameToParseIdMap()
            if let parseId = map[usernameKey] {
                self.trader = self.trader.withParseUserId(parseId)
                print("✅ InvestmentSheetViewModel: Hydrated trader \(usernameKey) → \(parseId)")
            } else {
                print("⚠️ InvestmentSheetViewModel: discoverTraders had no entry for username \(usernameKey)")
            }
        } catch {
            print("⚠️ InvestmentSheetViewModel: direct trader hydration failed: \(error.localizedDescription)")
        }
    }

    func refreshPoolMirrorCapacity() async {
        guard let client = self.parseAPIClient else { return }
        let api = InvestmentAPIService(apiClient: client)
        do {
            let status = try await api.fetchPoolMirrorCapacity(
                traderId: self.trader.backendTraderId,
                traderUsername: self.trader.username,
                traderName: self.trader.name,
                additionalAmount: self.totalInvestmentAmount
            )
            self.poolMirrorCapacity = status
            self.poolMirrorAlertSubscribed = status.alertSubscribed
        } catch {
            print("⚠️ InvestmentSheetViewModel: pool mirror capacity fetch failed: \(error.localizedDescription)")
        }
    }

    /// Debounced pool-mirror refresh — avoids one network call per keystroke in the amount field.
    func schedulePoolMirrorCapacityRefresh(debounceNanoseconds: UInt64 = 450_000_000) {
        self.poolMirrorRefreshTask?.cancel()
        self.poolMirrorRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: debounceNanoseconds)
            guard !Task.isCancelled, let self else { return }
            await self.refreshPoolMirrorCapacity()
        }
    }

    func togglePoolMirrorCapacityAlert() async {
        guard let client = self.parseAPIClient else { return }
        self.isUpdatingPoolMirrorAlert = true
        let api = InvestmentAPIService(apiClient: client)
        let next = !self.poolMirrorAlertSubscribed
        defer { self.isUpdatingPoolMirrorAlert = false }
        do {
            try await api.setPoolMirrorCapacityAlert(
                traderId: self.trader.backendTraderId,
                traderUsername: self.trader.username,
                traderName: self.trader.name,
                enabled: next
            )
            self.poolMirrorAlertSubscribed = next
            await self.refreshPoolMirrorCapacity()
        } catch {
            self.showInvestmentError(
                "Benachrichtigung konnte nicht gespeichert werden. Bitte erneut versuchen."
            )
        }
    }

    /// Caps `investmentAmount` (whole euros) to `maximumInvestmentAmount` after a config refresh.
    func applyConfiguredMaximumToAmountField() {
        let maxEuros = max(0, Int(floor(configurationService.maximumInvestmentAmount)))
        guard maxEuros > 0 else { return }
        let raw = Int(investmentAmount.replacingOccurrences(of: ".", with: "")) ?? 0
        if raw > maxEuros {
            self.investmentAmount = String(maxEuros)
        }
    }

    // MARK: - Validation

    func validateUserCanInvest() -> Bool {
        guard let currentUser = currentUser else {
            self.showInvestmentError("Please log in to make investments")
            return false
        }

        if currentUser.role == .trader {
            self.showInvestmentError("Traders cannot invest in other traders")
            return false
        }

        return true
    }

    // MARK: - Investment Creation

    func createInvestment() async {
        guard self.validateUserCanInvest() else { return }
        guard let currentUser = currentUser else { return }

        self.isLoading = true
        await self.prepareForInvestingFlow()

        guard self.canProceed else {
            self.isLoading = false
            return
        }

        let amountPerInvestment = self.amountPerInvestment

        Task {
            do {
                // Create the investment using the current user and trader data
                try await self.investmentService.createInvestment(
                    investor: currentUser,
                    trader: self.trader,
                    amountPerInvestment: amountPerInvestment,
                    numberOfInvestments: self.numberOfInvestments,
                    specialization: self.trader.specialization,
                    poolSelection: self.selectedInvestmentSelection
                )

                await MainActor.run {
                    self.isLoading = false
                    // Show success message briefly, then dismiss and return to investor dashboard
                    self.showSuccess = true
                    // Dismiss the sheet after a short delay to show the success message
                    Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                        await MainActor.run {
                            self.onInvestmentSuccess?()
                        }
                    }
                }
            } catch let error as AppError {
                await MainActor.run {
                    self.isLoading = false
                    self.showInvestmentError(error.userFacingInvestmentMessage)

                    // Track error with investment context
                    let context = ErrorContext(
                        screen: "InvestmentSheet",
                        action: "createInvestment",
                        userId: currentUser.id,
                        userRole: currentUser.role.displayName,
                        additionalData: [
                            "trader_id": trader.backendTraderId,
                            "trader_name": trader.name,
                            "investment_amount": amountPerInvestment,
                            "number_of_investments": numberOfInvestments,
                            "specialization": trader.specialization,
                            "investment_selection": selectedInvestmentSelection.rawValue
                        ]
                    )
                    telemetryService.trackAppError(error, context: context)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    let appError = error.toAppError()
                    self.showInvestmentError(appError.userFacingInvestmentMessage)

                    // Track unknown error
                    let context = ErrorContext(
                        screen: "InvestmentSheet",
                        action: "createInvestment",
                        userId: currentUser.id,
                        userRole: currentUser.role.displayName,
                        additionalData: [
                            "original_error": appError.errorDescription ?? "unknown",
                            "trader_id": self.trader.backendTraderId,
                            "investment_amount": amountPerInvestment
                        ]
                    )
                    self.telemetryService.trackAppError(appError, context: context)
                }
            }
        }
    }

    // MARK: - Error Handling

    private func showInvestmentError(_ message: String) {
        self.investmentErrorMessage = message
        self.showInvestmentError = true
    }
}
