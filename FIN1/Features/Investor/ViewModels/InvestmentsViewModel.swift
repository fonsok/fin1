import SwiftUI
import Foundation
import Combine

final class InvestmentsViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var investments: [Investment] = []
    @Published var selectedYear: Int? // Deprecated: kept for backward compatibility
    @Published var selectedTimePeriod: InvestmentTimePeriod = .last30Days
    @Published var showNewInvestment = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var userService: any UserServiceProtocol
    private var investmentService: any InvestmentServiceProtocol
    private var investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)?
    private var poolTradeParticipationService: any PoolTradeParticipationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    private var roleChangeCancellables = Set<AnyCancellable>() // Separate set for role change observers
    // Capture a stable investorId when this VM is created to avoid cross-user drift
    private var boundInvestorId: String?
    private var currentRole: UserRole? // Track current role to detect role changes
    private var dataProcessor: InvestmentsDataProcessor

    init(userService: any UserServiceProtocol,
         investmentService: any InvestmentServiceProtocol,
         investorCashBalanceService: (any InvestorCashBalanceServiceProtocol)? = nil,
         poolTradeParticipationService: any PoolTradeParticipationServiceProtocol) {
        self.userService = userService
        self.investmentService = investmentService
        self.investorCashBalanceService = investorCashBalanceService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.boundInvestorId = userService.currentUser?.id
        self.currentRole = userService.currentUser?.role
        self.dataProcessor = InvestmentsDataProcessor(poolTradeParticipationService: poolTradeParticipationService)
        setupRoleChangeObservers()
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
                    print("🔄 InvestmentsViewModel: User data changed (ID: \(newInvestorId ?? "nil") -> \(self.boundInvestorId ?? "nil"), Role: \(newRole?.displayName ?? "nil") -> \(self.currentRole?.displayName ?? "nil")) - reloading")
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
                print("🔄 InvestmentsViewModel: Role changed to \(newRole?.displayName ?? "nil") - reloading")
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
                print("🔍 InvestmentsViewModel: Received investment update - count: \(updatedInvestments.count)")
                // Publisher already filtered; assign directly
                self.investments = updatedInvestments
                // Check and update investment completion status after changes
                self.checkAndUpdateInvestmentCompletion()
                print("✅ InvestmentsViewModel: Investments updated for current user - count: \(self.investments.count)")
            }
            .store(in: &cancellables)

        // Initial load
        loadInvestments()
    }

    /// Reconfigures ViewModel with services from environment (single container to avoid omissions)
    func reconfigure(with services: AppServices) {
        // Cancel existing subscriptions
        cancellables.removeAll()
        roleChangeCancellables.removeAll()

        self.userService = services.userService
        self.investmentService = services.investmentService
        self.investorCashBalanceService = services.investorCashBalanceService
        self.poolTradeParticipationService = services.poolTradeParticipationService
        // Refresh bound investor id when VM is explicitly reconfigured
        self.boundInvestorId = services.userService.currentUser?.id

        // Update data processor with new service
        self.dataProcessor = InvestmentsDataProcessor(poolTradeParticipationService: services.poolTradeParticipationService)

        // Re-setup bindings with new service
        setupBindings()
    }

    deinit {
        print("🧹 InvestmentsViewModel deallocated")
    }

    var currentUser: User? {
        userService.currentUser
    }

    // MARK: - Data Loading

    func loadInvestmentsData() {
        isLoading = true

        // Simulate API call using modern Swift concurrency
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            loadInvestments()
            // Auto-select current year for completed investments
            if selectedYear == nil && !availableYears.isEmpty {
                selectedYear = availableYears.first
            }
            isLoading = false
        }
    }

    private func loadInvestments() {
        // Load from service if available, otherwise use mock data
        if !investmentService.investments.isEmpty {
            // Only load investments for the VM's bound investor
            if let investorId = boundInvestorId {
                investments = investmentService.getInvestments(for: investorId)
            } else {
                investments = []
            }
            // Check and update investment completion status after loading
            checkAndUpdateInvestmentCompletion()
            return
        }

        // Mock data - in real app, this would come from API
        investments = []
        checkAndUpdateInvestmentCompletion()
    }

    /// Checks if investments should be marked as completed
    /// Completion checking is handled by InvestmentCompletionService
    private func checkAndUpdateInvestmentCompletion() {
        // Note: Completion checking is handled by InvestmentCompletionService.
        // This method is kept for compatibility but may not be needed in the same way.
        // The service will handle marking investments as completed when their status is completed.
    }

    // MARK: - Investment Management

    func showNewInvestmentSheet() {
        showNewInvestment = true
    }

    func hideNewInvestmentSheet() {
        showNewInvestment = false
    }

    // MARK: - Filtered Investment Lists

    /// Returns investments filtered by active status
    var activeInvestments: [Investment] {
        return investments.filter { $0.status == .active }
    }

    /// Returns investments filtered by completed/cancelled, plus partially-completed (active with completed status)
    /// Sorted by: completion date (newest first), then trader name (A-Z), then investment number
    var completedInvestments: [Investment] {
        let fullyDone = investments.filter { $0.status == .completed || $0.status == .cancelled }
        // Check if active investment has completed status
        let partials = investments.filter { inv in
            inv.status == .active && inv.reservationStatus == .completed
        }
        let completed = fullyDone + partials

        // Sort by: completion date (newest first), then trader name (A-Z), then investment number
        return completed.sorted { first, second in
            // First: completion date (newest first)
            let firstDate = first.completedAt ?? first.updatedAt
            let secondDate = second.completedAt ?? second.updatedAt
            if firstDate != secondDate {
                return firstDate > secondDate
            }
            // Second: trader name (A-Z)
            if first.traderName != second.traderName {
                return first.traderName < second.traderName
            }
            // Third: investment number (ascending)
            let firstNumber = dataProcessor.extractInvestmentNumber(from: first.id.extractInvestmentNumber())
            let secondNumber = dataProcessor.extractInvestmentNumber(from: second.id.extractInvestmentNumber())
            return firstNumber < secondNumber
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

    // MARK: - Investment-Level Data for Table Display

    /// Returns investment rows for ongoing investments
    /// Since each investment is now a first-class entity, we map investments directly to rows
    /// Sorted by: creation date (newest first), then trader name (A-Z), then investment number (ascending)
    var ongoingInvestmentRows: [InvestmentRow] {
        dataProcessor.processOngoingInvestmentRows(from: activeInvestments)
    }

    /// Total amount for ongoing investments
    var totalOngoingAmount: Double {
        dataProcessor.calculateTotalOngoingAmount(from: ongoingInvestmentRows)
    }

    /// Total profit for ongoing investments (if available)
    var totalOngoingProfit: Double? {
        dataProcessor.calculateTotalOngoingProfit(from: ongoingInvestmentRows)
    }

    /// Total return percentage for ongoing investments (if available)
    var totalOngoingReturn: Double? {
        dataProcessor.calculateTotalOngoingReturn(from: ongoingInvestmentRows, totalAmount: totalOngoingAmount)
    }

    // MARK: - Grouped Investment Data for View Display

    /// Returns investments grouped by trader name, with investments sorted by sequence number (ascending)
    /// This ensures Investment 1 appears first within each trader's group
    var groupedOngoingInvestments: [String: [InvestmentRow]] {
        dataProcessor.groupOngoingInvestments(ongoingInvestmentRows)
    }

    /// Returns trader names sorted alphabetically for display
    var sortedTraderNames: [String] {
        dataProcessor.sortedTraderNames(from: groupedOngoingInvestments)
    }

    /// Returns the current selected year, defaulting to current year if none selected
    /// Deprecated: Kept for backward compatibility
    var currentSelectedYear: Int {
        selectedYear ?? Calendar.current.component(.year, from: Date())
    }

    /// Filters completed investments by the selected time period
    func filterCompletedInvestments(by period: InvestmentTimePeriod) {
        selectedTimePeriod = period
    }


    // MARK: - Investment Deletion

    /// Deletes an investment (storno) and refunds the allocated amount to investor's cash balance
    /// - Note: Only the investment's allocated amount is refunded. Platform service charge is NON-REFUNDABLE
    ///   and remains charged even if all investments are deleted and investment is cancelled.
    func deleteInvestment(_ investmentRow: InvestmentRow) async throws {
        // Get the allocated amount for this investment
        let refundAmount = investmentRow.reservation.allocatedAmount

        // Refund ONLY the investment's allocated amount to investor's cash balance
        // Platform service charge is NOT refunded - it's a non-refundable creation charge
        if let investorId = currentUser?.id,
           let cashBalanceService = investorCashBalanceService {
            await cashBalanceService.processRemainingBalanceDistribution(
                investorId: investorId,
                amount: refundAmount,
                investmentId: investmentRow.investmentId
            )
        }

        // Delegate actual deletion to the InvestmentService (source of truth)
        await investmentService.deleteInvestment(
            investmentId: investmentRow.investmentId,
            reservationId: investmentRow.reservation.id
        )
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
}
