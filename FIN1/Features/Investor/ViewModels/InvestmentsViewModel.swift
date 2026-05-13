import Combine
import Foundation
import SwiftUI

@MainActor
final class InvestmentsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var investments: [Investment] = []
    @Published var selectedYear: Int? // Deprecated: kept for backward compatibility
    @Published var selectedTimePeriod: InvestmentTimePeriod = .last30Days
    @Published var showNewInvestment = false
    @Published var errorMessage: String?
    @Published var showError = false

    var userService: any UserServiceProtocol
    var investmentService: any InvestmentServiceProtocol
    var investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    var poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    var documentService: any DocumentServiceProtocol
    var invoiceService: any InvoiceServiceProtocol
    var traderDataService: any TraderDataServiceProtocol
    var tradeLifecycleService: any TradeLifecycleServiceProtocol
    var configurationService: any ConfigurationServiceProtocol
    var commissionCalculationService: any CommissionCalculationServiceProtocol
    var settlementAPIService: (any SettlementAPIServiceProtocol)?
    var tradeAPIService: (any TradeAPIServiceProtocol)?
    var cancellables = Set<AnyCancellable>()
    var roleChangeCancellables = Set<AnyCancellable>() // Separate set for role change observers
    // Capture a stable investorId when this VM is created to avoid cross-user drift
    var boundInvestorId: String?
    var currentRole: UserRole? // Track current role to detect role changes
    var dataProcessor: InvestmentsDataProcessor

    /// Display-Daten für Completed-Tabelle (MVVM: View bindet nur daran).
    @Published var completedTraderUsernames: [String: String] = [:]
    @Published var completedTradeNumbers: [String: String] = [:]
    @Published var completedInvestmentSummaries: [String: InvestorInvestmentStatementSummary] = [:]
    /// Server-canonical summaries (ROI2) pro Investment-ID. Task 5a: View prefers
    /// this value; `completedInvestmentSummaries` is the fallback when the
    /// backend data is not available yet.
    @Published var completedCanonicalSummaries: [String: ServerInvestmentCanonicalSummary] = [:]

    init(
        userService: any UserServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        documentService: any DocumentServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        traderDataService: any TraderDataServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.userService = userService
        self.investmentService = investmentService
        self.investorCashBalanceService = investorCashBalanceService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.documentService = documentService
        self.invoiceService = invoiceService
        self.traderDataService = traderDataService
        self.tradeLifecycleService = tradeLifecycleService
        self.configurationService = configurationService
        self.commissionCalculationService = commissionCalculationService
        self.settlementAPIService = settlementAPIService
        self.tradeAPIService = nil
        self.boundInvestorId = userService.currentUser?.id
        self.currentRole = userService.currentUser?.role
        self.dataProcessor = InvestmentsDataProcessor(
            poolTradeParticipationService: poolTradeParticipationService,
            configurationService: configurationService
        )
        self.setupRoleChangeObservers()
        self.setupBindings()
    }

    // MARK: - Setup Observers

    private func setupRoleChangeObservers() {
        // Clear existing role change observers (if any)
        self.roleChangeCancellables.removeAll()

        // Observe role changes to reload data for new user
        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newInvestorId = self.userService.currentUser?.id
                let newRole = self.userService.currentUser?.role

                // Reload if user ID changed OR role changed (for role testing)
                if newInvestorId != self.boundInvestorId || newRole != self.currentRole {
                    print(
                        "🔄 InvestmentsViewModel: User data changed (ID: \(newInvestorId ?? "nil") -> \(self.boundInvestorId ?? "nil"), Role: \(newRole?.displayName ?? "nil") -> \(self.currentRole?.displayName ?? "nil")) - reloading"
                    )
                    self.boundInvestorId = newInvestorId
                    self.currentRole = newRole
                    // Re-setup investment publisher subscription with new investor ID
                    self.setupInvestmentPublisher()
                }
            }
            .store(in: &self.roleChangeCancellables)

        NotificationCenter.default.publisher(for: NSNotification.Name("UserRoleChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newInvestorId = self.userService.currentUser?.id
                let newRole = self.userService.currentUser?.role

                // Always reload on explicit role change (for role testing)
                print("🔄 InvestmentsViewModel: Role changed to \(newRole?.displayName ?? "nil") - reloading")
                self.boundInvestorId = newInvestorId
                self.currentRole = newRole
                // Re-setup investment publisher subscription with new investor ID
                self.setupInvestmentPublisher()
            }
            .store(in: &self.roleChangeCancellables)
    }

    // MARK: - Setup Bindings

    private func setupBindings() {
        self.setupRoleChangeObservers()
        self.setupInvestmentPublisher()
    }

    private func setupInvestmentPublisher() {
        // Cancel existing investment publisher subscription
        self.cancellables.removeAll()

        // Observe investment changes from service
        let investorId = self.boundInvestorId
        let publisher: AnyPublisher<[Investment], Never>
        if let investorId = investorId {
            publisher = self.investmentService.investmentsPublisher(for: investorId)
        } else {
            publisher = self.investmentService.investmentsPublisher
        }
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedInvestments in
                guard let self = self else { return }
                print("🔍 InvestmentsViewModel: Received investment update - count: \(updatedInvestments.count)")
                // Publisher already filtered; assign directly
                self.investments = updatedInvestments
                self.refreshCompletedDisplayData()
                // Check and update investment completion status after changes
                self.checkAndUpdateInvestmentCompletion()
                print("✅ InvestmentsViewModel: Investments updated for current user - count: \(self.investments.count)")
            }
            .store(in: &self.cancellables)

        // Initial load
        loadInvestments()
    }

    /// Reconfigures ViewModel with services from environment (single container to avoid omissions)
    func reconfigure(with services: AppServices) {
        // Cancel existing subscriptions
        self.cancellables.removeAll()
        self.roleChangeCancellables.removeAll()

        self.userService = services.userService
        self.investmentService = services.investmentService
        self.investorCashBalanceService = services.investorCashBalanceService
        self.poolTradeParticipationService = services.poolTradeParticipationService
        self.documentService = services.documentService
        self.invoiceService = services.invoiceService
        self.traderDataService = services.traderDataService
        self.tradeLifecycleService = services.tradeLifecycleService
        self.configurationService = services.configurationService
        self.commissionCalculationService = services.commissionCalculationService
        self.settlementAPIService = services.settlementAPIService
        self.tradeAPIService = services.parseAPIClient.map { TradeAPIService(apiClient: $0) }
        // Refresh bound investor id when VM is explicitly reconfigured
        self.boundInvestorId = services.userService.currentUser?.id

        self.dataProcessor = InvestmentsDataProcessor(
            poolTradeParticipationService: services.poolTradeParticipationService,
            configurationService: services.configurationService
        )
        refreshCompletedDisplayData()

        // Re-setup bindings with new service
        self.setupBindings()
    }

    deinit {
        print("🧹 InvestmentsViewModel deallocated")
    }

    var currentUser: User? {
        self.userService.currentUser
    }

    // MARK: - Investment Management

    func showNewInvestmentSheet() {
        self.showNewInvestment = true
    }

    func hideNewInvestmentSheet() {
        self.showNewInvestment = false
    }

    // MARK: - Investment Deletion

    /// Deletes a reserved split (storno). Refund + escrow: `InvestmentService` (server via API when synced, else local wallet).
    /// App service charge is never refunded.
    func deleteInvestment(_ investmentRow: InvestmentRow) async throws {
        await self.investmentService.deleteInvestment(
            investmentId: investmentRow.investmentId,
            reservationId: investmentRow.reservation.id
        )
    }

    // MARK: - Error Handling

    func clearError() {
        self.errorMessage = nil
        self.showError = false
    }

    func showError(_ error: AppError) {
        self.errorMessage = error.errorDescription ?? "An error occurred"
        self.showError = true
    }

    func handleError(_ error: Error) {
        let appError = error.toAppError()
        self.errorMessage = appError.errorDescription ?? "An error occurred"
        self.showError = true
    }
}
