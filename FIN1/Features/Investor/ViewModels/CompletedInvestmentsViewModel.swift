import Combine
import Foundation
import SwiftUI

@MainActor
final class CompletedInvestmentsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var investments: [Investment] = []
    @Published var selectedYear: Int? // Deprecated: kept for backward compatibility
    @Published var selectedTimePeriod: InvestmentTimePeriod = .last30Days
    @Published var showCompletedInvestmentDetails = false
    @Published var selectedCompletedInvestment: Investment?
    @Published var errorMessage: String?
    @Published var showError = false

    private var userService: any UserServiceProtocol
    private var investmentService: any InvestmentServiceProtocol
    private var documentService: any DocumentServiceProtocol
    private var invoiceService: any InvoiceServiceProtocol
    private var traderDataService: any TraderDataServiceProtocol
    private var poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    private var tradeLifecycleService: any TradeLifecycleServiceProtocol
    private var configurationService: any ConfigurationServiceProtocol
    private var commissionCalculationService: any CommissionCalculationServiceProtocol
    private var settlementAPIService: (any SettlementAPIServiceProtocol)?
    private var tradeAPIService: (any TradeAPIServiceProtocol)?
    private var cancellables = Set<AnyCancellable>()
    private var roleChangeCancellables = Set<AnyCancellable>() // Separate set for role change observers
    private var boundInvestorId: String?
    private var currentRole: UserRole? // Track current role to detect role changes

    /// Beleg-/Rechnungsnummern pro Investment (MVVM: View bindet nur daran).
    @Published var investmentDocRefs: [String: (docNumber: String?, invoiceNumber: String?)] = [:]
    /// Local statement summaries for completed-list fallback (preview / tests only).
    /// Empty when `investorMonetaryServerOnly` — lists use `canonicalSummaries` only.
    @Published var investmentSummaries: [String: InvestorInvestmentStatementSummary] = [:]

    /// Server-canonical totals + ROI2 (`investorCollectionBill.metadata`). SSOT when server-only.
    @Published var canonicalSummaries: [String: ServerInvestmentCanonicalSummary] = [:]

    private var monetaryServerOnly: Bool {
        self.configurationService.investorMonetaryServerOnly
    }

    var monetaryServerOnlyForDisplay: Bool { self.monetaryServerOnly }

    init(
        userService: any UserServiceProtocol,
        investmentService: any InvestmentServiceProtocol,
        documentService: any DocumentServiceProtocol,
        invoiceService: any InvoiceServiceProtocol,
        traderDataService: any TraderDataServiceProtocol,
        poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        configurationService: any ConfigurationServiceProtocol,
        commissionCalculationService: any CommissionCalculationServiceProtocol,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
    ) {
        self.userService = userService
        self.investmentService = investmentService
        self.documentService = documentService
        self.invoiceService = invoiceService
        self.traderDataService = traderDataService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.tradeLifecycleService = tradeLifecycleService
        self.configurationService = configurationService
        self.commissionCalculationService = commissionCalculationService
        self.settlementAPIService = settlementAPIService
        self.tradeAPIService = nil
        self.boundInvestorId = userService.currentUser?.id
        self.currentRole = userService.currentUser?.role
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
                        "🔄 CompletedInvestmentsViewModel: User data changed (ID: \(newInvestorId ?? "nil") -> \(self.boundInvestorId ?? "nil"), Role: \(newRole?.displayName ?? "nil") -> \(self.currentRole?.displayName ?? "nil")) - reloading"
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
                print("🔄 CompletedInvestmentsViewModel: Role changed to \(newRole?.displayName ?? "nil") - reloading")
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
        let publisher: AnyPublisher<[Investment], Never>
        if let user = self.userService.currentUser {
            publisher = self.investmentService.investmentsPublisher(matchingAnyOf: user.ledgerUserIdCandidates)
        } else {
            publisher = self.investmentService.investmentsPublisher
        }
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedInvestments in
                guard let self = self else { return }
                self.investments = updatedInvestments
                self.refreshInvestmentDocRefs()
                self.refreshDisplayData()
                self.checkAndUpdateInvestmentCompletion()
                print("✅ CompletedInvestmentsViewModel: Investments updated from service - count: \(updatedInvestments.count)")
            }
            .store(in: &self.cancellables)

        // Initial load
        self.loadCompletedInvestments()
    }

    /// Reconfigures ViewModel with services from environment (preferred)
    func reconfigure(with services: AppServices) {
        // Cancel existing subscriptions
        self.cancellables.removeAll()
        self.roleChangeCancellables.removeAll()

        self.userService = services.userService
        self.investmentService = services.investmentService
        self.documentService = services.documentService
        self.invoiceService = services.invoiceService
        self.traderDataService = services.traderDataService
        self.poolTradeParticipationService = services.poolTradeParticipationService
        self.tradeLifecycleService = services.tradeLifecycleService
        self.configurationService = services.configurationService
        self.commissionCalculationService = services.commissionCalculationService
        self.settlementAPIService = services.settlementAPIService
        self.tradeAPIService = services.parseAPIClient.map { TradeAPIService(apiClient: $0) }
        self.boundInvestorId = services.userService.currentUser?.id
        self.refreshInvestmentDocRefs()
        self.refreshDisplayData()
        self.setupBindings()
    }

    var currentUser: User? {
        self.userService.currentUser
    }

    // MARK: - Data Loading

    func loadCompletedInvestments() {
        self.isLoading = true

        if let user = userService.currentUser {
            self.investments = self.investmentService.getInvestments(matchingAnyOf: user.ledgerUserIdCandidates)
        } else {
            self.investments = []
        }
        self.refreshInvestmentDocRefs()
        self.refreshDisplayData()
        self.checkAndUpdateInvestmentCompletion()

        // Auto-select current year for completed investments
        if self.selectedYear == nil && !self.availableYears.isEmpty {
            self.selectedYear = self.availableYears.first
        }

        self.isLoading = false
    }

    /// Beleg-/Rechnungsnummern aus Services (MVVM: keine Logik in der View).
    private func refreshInvestmentDocRefs() {
        let userId = self.userService.currentUser?.id ?? ""
        var refs: [String: (docNumber: String?, invoiceNumber: String?)] = [:]
        for inv in self.investments {
            let docs = self.documentService.getDocumentsForInvestment(inv.id)
            let docNumber = docs.first { $0.type == .investorCollectionBill }?.accountingDocumentNumber
            let batchId = inv.batchId ?? ""
            let invoiceNumber = batchId.isEmpty
                ? nil
                : self.invoiceService.getServiceChargeInvoiceForBatch(batchId, userId: userId)?.invoiceNumber
            refs[inv.id] = (docNumber, invoiceNumber)
        }
        self.investmentDocRefs = refs
    }

    /// Statement-Summaries und kanonische Server-Totals für Completed-Tabelle (MVVM).
    private func refreshDisplayData() {
        self.investmentSummaries = [:]
        self.refreshCanonicalSummaries(for: self.investments)
    }

    /// Lädt server-kanonische Summaries (ROI2 + Totals) in `canonicalSummaries`.
    private func refreshCanonicalSummaries(for investments: [Investment]) {
        guard let service = self.settlementAPIService else { return }
        let relevantIds = investments
            .filter { $0.status == .completed || $0.reservationStatus == .completed }
            .map(\.id)
        guard !relevantIds.isEmpty else { return }
        let allowUnweightedFallback = !self.monetaryServerOnly

        Task { [weak self] in
            let result = await ServerCalculatedReturnResolver.resolveCanonicalSummaries(
                investmentIds: relevantIds,
                settlementAPIService: service,
                allowUnweightedReturnFallback: allowUnweightedFallback
            )
            await MainActor.run { [weak self] in
                self?.canonicalSummaries = result
            }
        }
    }

    // MARK: - Filtered Investment Lists

    /// Returns investments filtered by completed/cancelled, plus partially-completed (active with completed pool status)
    var completedInvestments: [Investment] {
        let fullyDone = self.investments.filter { $0.status == .completed || $0.status == .cancelled }
        // Since each pool is an investment, check if active investment has completed pool status
        let partials = self.investments.filter { inv in
            inv.status == .active && inv.reservationStatus == .completed
        }
        let completed = fullyDone + partials
        print("🔍 CompletedInvestmentsViewModel.completedInvestments:")
        print("   📊 Total investments: \(self.investments.count)")
        print("   ✅ Completed investments: \(completed.count)")
        for (index, inv) in completed.enumerated() {
            print(
                "      [\(index)] Investment \(inv.id): trader='\(inv.traderName)', amount=€\(inv.amount), currentValue=€\(inv.currentValue), performance=\(inv.performance)%, completedAt=\(inv.completedAt?.description ?? "nil")"
            )
        }
        return completed
    }

    /// Checks if investments should be marked as completed
    /// Note: Since each pool is now an investment, completion checking is handled by InvestmentCompletionService
    private func checkAndUpdateInvestmentCompletion() {
        // The service's checkAndUpdateInvestmentCompletion() should handle the actual updates
        // This method is just for logging/debugging - the service will publish updates via the publisher
        let activeInvestments = self.investments.filter { $0.status == .active && $0.reservationStatus == .completed }
        if !activeInvestments.isEmpty {
            print("🔍 CompletedInvestmentsViewModel.checkAndUpdateInvestmentCompletion:")
            print("   📊 Found \(activeInvestments.count) active investments with completed pool status")
            print("   ℹ️ Service should handle the actual status update - waiting for publisher update")
        }
    }

    /// Returns completed/partial investments filtered by time period
    var completedInvestmentsByTimePeriod: [Investment] {
        let allCompleted = self.completedInvestments
        let cutoffDate = self.selectedTimePeriod.cutoffDate()

        return allCompleted.filter { investment in
            if let completedAt = investment.completedAt {
                return completedAt >= cutoffDate
            } else {
                // Partial/cancelled without date -> included in all time periods
                return true
            }
        }
    }

    /// Returns completed/partial investments filtered by year (partials have no completedAt -> included)
    /// Deprecated: Use completedInvestmentsByTimePeriod instead
    var completedInvestmentsByYear: [Investment] {
        self.completedInvestmentsByTimePeriod
    }

    /// Available years for filtering completed investments
    var availableYears: [Int] {
        let years = self.completedInvestments.compactMap { investment -> Int? in
            guard let completedAt = investment.completedAt else { return nil }
            return Calendar.current.component(.year, from: completedAt)
        }
        return Array(Set(years)).sorted(by: >)
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

    /// Filters completed investments by the selected time period
    func filterCompletedInvestments(by period: InvestmentTimePeriod) {
        self.selectedTimePeriod = period
    }
}
