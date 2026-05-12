import SwiftUI
import Foundation
import Combine

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
    /// Trader-Username pro Investment-ID (MVVM: keine Service-Aufrufe in der View).
    @Published var traderUsernames: [String: String] = [:]
    /// Trade-Nummer pro Investment-ID (MVVM: keine Service-Aufrufe in der View).
    @Published var tradeNumbers: [String: String] = [:]
    /// Statement-Summaries pro Investment-ID (MVVM: keine Berechnung in der View).
    /// Same aggregator populates the Investor Collection Bill – table, info sheet and
    /// PDF therefore stay internally consistent.
    @Published var investmentSummaries: [String: InvestorInvestmentStatementSummary] = [:]

    /// Server-canonical summary pro Investment-ID (ROI2 aus
    /// `investorCollectionBill.metadata.returnPercentage`). Task 5a: View prefers
    /// this value; `investmentSummaries` is the fallback when the backend data
    /// is not (yet) available. See Documentation/RETURN_CALCULATION_SCHEMAS.md.
    @Published var canonicalSummaries: [String: ServerInvestmentCanonicalSummary] = [:]

    init(userService: any UserServiceProtocol,
         investmentService: any InvestmentServiceProtocol,
         documentService: any DocumentServiceProtocol,
         invoiceService: any InvoiceServiceProtocol,
         traderDataService: any TraderDataServiceProtocol,
         poolTradeParticipationService: any PoolTradeParticipationServiceProtocol,
         tradeLifecycleService: any TradeLifecycleServiceProtocol,
         configurationService: any ConfigurationServiceProtocol,
         commissionCalculationService: any CommissionCalculationServiceProtocol,
         settlementAPIService: (any SettlementAPIServiceProtocol)? = nil) {
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
        setupBindings()
    }

    // MARK: - Setup Observers

    private func setupRoleChangeObservers() {
        // Clear existing role change observers (if any)
        roleChangeCancellables.removeAll()

        // Observe role changes to reload data for new user
        NotificationCenter.default.publisher(for: .userDataDidUpdate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                let newInvestorId = self.userService.currentUser?.id
                let newRole = self.userService.currentUser?.role

                // Reload if user ID changed OR role changed (for role testing)
                if newInvestorId != self.boundInvestorId || newRole != self.currentRole {
                    print("🔄 CompletedInvestmentsViewModel: User data changed (ID: \(newInvestorId ?? "nil") -> \(self.boundInvestorId ?? "nil"), Role: \(newRole?.displayName ?? "nil") -> \(self.currentRole?.displayName ?? "nil")) - reloading")
                    self.boundInvestorId = newInvestorId
                    self.currentRole = newRole
                    // Re-setup investment publisher subscription with new investor ID
                    self.setupInvestmentPublisher()
                }
            }
            .store(in: &roleChangeCancellables)

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
            .store(in: &roleChangeCancellables)
    }

    // MARK: - Setup Bindings

    private func setupBindings() {
        setupRoleChangeObservers()
        setupInvestmentPublisher()
    }

    private func setupInvestmentPublisher() {
        // Cancel existing investment publisher subscription
        cancellables.removeAll()

        // Observe investment changes from service
        let investorId = boundInvestorId
        let publisher: AnyPublisher<[Investment], Never>
        if let investorId = investorId {
            publisher = investmentService.investmentsPublisher(for: investorId)
        } else {
            publisher = investmentService.investmentsPublisher
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
            .store(in: &cancellables)

        // Initial load
        loadCompletedInvestments()
    }

    /// Reconfigures ViewModel with services from environment (preferred)
    func reconfigure(with services: AppServices) {
        // Cancel existing subscriptions
        cancellables.removeAll()
        roleChangeCancellables.removeAll()

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
        refreshInvestmentDocRefs()
        refreshDisplayData()
        setupBindings()
    }

    var currentUser: User? {
        userService.currentUser
    }

    // MARK: - Data Loading

    func loadCompletedInvestments() {
        isLoading = true

        if let investorId = boundInvestorId {
            investments = investmentService.getInvestments(for: investorId)
        } else {
            investments = []
        }
        refreshInvestmentDocRefs()
        refreshDisplayData()
        checkAndUpdateInvestmentCompletion()

        // Auto-select current year for completed investments
        if selectedYear == nil && !availableYears.isEmpty {
            selectedYear = availableYears.first
        }

        isLoading = false
    }

    /// Beleg-/Rechnungsnummern aus Services (MVVM: keine Logik in der View).
    private func refreshInvestmentDocRefs() {
        let userId = userService.currentUser?.id ?? ""
        var refs: [String: (docNumber: String?, invoiceNumber: String?)] = [:]
        for inv in investments {
            let docs = documentService.getDocumentsForInvestment(inv.id)
            let docNumber = docs.first { $0.type == .investorCollectionBill }?.accountingDocumentNumber
            let batchId = inv.batchId ?? ""
            let invoiceNumber = batchId.isEmpty
                ? nil
                : invoiceService.getServiceChargeInvoiceForBatch(batchId, userId: userId)?.invoiceNumber
            refs[inv.id] = (docNumber, invoiceNumber)
        }
        investmentDocRefs = refs
    }

    /// Trader-Usernames, Trade-Nummern und Statement-Summaries aus Services (MVVM: keine Logik in der View).
    private func refreshDisplayData() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            var tradeIds: Set<String> = []
            for inv in investments {
                for p in poolTradeParticipationService.getParticipations(forInvestmentId: inv.id) {
                    tradeIds.insert(p.tradeId)
                }
            }
            let tradesById = await InvestorInvestmentStatementAggregator.resolveTradesForPoolParticipations(
                investedTradeIds: tradeIds,
                localTrades: tradeLifecycleService.completedTrades,
                tradeAPIService: tradeAPIService
            )
            var usernames: [String: String] = [:]
            var tradeNums: [String: String] = [:]
            var summaries: [String: InvestorInvestmentStatementSummary] = [:]
            let commissionRate = configurationService.effectiveCommissionRate
            let calculationService = InvestorCollectionBillCalculationService()

            for inv in investments {
                usernames[inv.id] = traderDataService.getTrader(by: inv.traderId)?.username ?? "---"
                let participations = poolTradeParticipationService.getParticipations(forInvestmentId: inv.id)

                if let first = participations.first,
                   let trade = tradesById[first.tradeId] {
                    tradeNums[inv.id] = String(format: "%03d", trade.tradeNumber)
                } else {
                    tradeNums[inv.id] = "---"
                }
                if let summary = InvestorInvestmentStatementAggregator.summarizeInvestment(
                    investmentId: inv.id,
                    poolTradeParticipationService: poolTradeParticipationService,
                    tradeLifecycleService: tradeLifecycleService,
                    invoiceService: invoiceService,
                    investmentService: investmentService,
                    calculationService: calculationService,
                    commissionCalculationService: commissionCalculationService,
                    additionalTradesById: tradesById,
                    commissionRate: commissionRate
                ) {
                    summaries[inv.id] = summary
                }
            }
            traderUsernames = usernames
            tradeNumbers = tradeNums
            investmentSummaries = summaries

            refreshCanonicalSummaries(for: investments)
        }
    }

    /// Lädt die server-kanonischen Summaries (ROI2) async und schreibt sie in
    /// `canonicalSummaries`. Fallbacks (fehlende Bills / Netzwerkfehler) bleiben
    /// einfach unbelegt → die View nutzt dann `investmentSummaries` als Fallback.
    private func refreshCanonicalSummaries(for investments: [Investment]) {
        let service = settlementAPIService
        guard service != nil else { return }
        let relevantIds = investments
            .filter { $0.status == .completed || $0.reservationStatus == .completed }
            .map { $0.id }
        guard !relevantIds.isEmpty else { return }

        Task { [weak self] in
            var result: [String: ServerInvestmentCanonicalSummary] = [:]
            for id in relevantIds {
                if let summary = await ServerCalculatedReturnResolver.resolveCanonicalSummary(
                    investmentId: id,
                    settlementAPIService: service
                ) {
                    result[id] = summary
                }
            }
            await MainActor.run { [weak self] in
                self?.canonicalSummaries = result
            }
        }
    }

    // MARK: - Filtered Investment Lists

    /// Returns investments filtered by completed/cancelled, plus partially-completed (active with completed pool status)
    var completedInvestments: [Investment] {
        let fullyDone = investments.filter { $0.status == .completed || $0.status == .cancelled }
        // Since each pool is an investment, check if active investment has completed pool status
        let partials = investments.filter { inv in
            inv.status == .active && inv.reservationStatus == .completed
        }
        let completed = fullyDone + partials
        print("🔍 CompletedInvestmentsViewModel.completedInvestments:")
        print("   📊 Total investments: \(investments.count)")
        print("   ✅ Completed investments: \(completed.count)")
        for (index, inv) in completed.enumerated() {
            print("      [\(index)] Investment \(inv.id): trader='\(inv.traderName)', amount=€\(inv.amount), currentValue=€\(inv.currentValue), performance=\(inv.performance)%, completedAt=\(inv.completedAt?.description ?? "nil")")
        }
        return completed
    }

    /// Checks if investments should be marked as completed
    /// Note: Since each pool is now an investment, completion checking is handled by InvestmentCompletionService
    private func checkAndUpdateInvestmentCompletion() {
        // The service's checkAndUpdateInvestmentCompletion() should handle the actual updates
        // This method is just for logging/debugging - the service will publish updates via the publisher
        let activeInvestments = investments.filter { $0.status == .active && $0.reservationStatus == .completed }
        if !activeInvestments.isEmpty {
            print("🔍 CompletedInvestmentsViewModel.checkAndUpdateInvestmentCompletion:")
            print("   📊 Found \(activeInvestments.count) active investments with completed pool status")
            print("   ℹ️ Service should handle the actual status update - waiting for publisher update")
        }
    }

    /// Returns completed/partial investments filtered by time period
    var completedInvestmentsByTimePeriod: [Investment] {
        let allCompleted = completedInvestments
        let cutoffDate = selectedTimePeriod.cutoffDate()

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
        completedInvestmentsByTimePeriod
    }

    /// Available years for filtering completed investments
    var availableYears: [Int] {
        let years = completedInvestments.compactMap { investment -> Int? in
            guard let completedAt = investment.completedAt else { return nil }
            return Calendar.current.component(.year, from: completedAt)
        }
        return Array(Set(years)).sorted(by: >)
    }

    // MARK: - Error Handling

    func clearError() {
        errorMessage = nil
        showError = false
    }

    func showError(_ error: AppError) {
        errorMessage = error.errorDescription ?? "An error occurred"
        showError = true
    }

    func handleError(_ error: Error) {
        let appError = error.toAppError()
        errorMessage = appError.errorDescription ?? "An error occurred"
        showError = true
    }

    /// Filters completed investments by the selected time period
    func filterCompletedInvestments(by period: InvestmentTimePeriod) {
        selectedTimePeriod = period
    }
}
