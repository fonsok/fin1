import Foundation
import Combine

// MARK: - Customer Support Dashboard ViewModel
/// ViewModel for the Customer Support Dashboard
/// Handles RBAC, customer search, tickets, and audited actions
///
/// Split into extensions for maintainability:
/// - Core: Properties, init, permissions, error handling (this file)
/// - +Tickets: Ticket CRUD and workflow operations
/// - +Customers: Customer selection and modifications

@MainActor
final class CustomerSupportDashboardViewModel: ObservableObject {

    // MARK: - Dependencies

    let supportService: CustomerSupportServiceProtocol
    private let auditService: AuditLoggingServiceProtocol
    private let searchCoordinator: CustomerSupportSearchCoordinator
    var cancellables = Set<AnyCancellable>()

    // MARK: - Published Properties - UI State

    @Published var isLoading = false
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var successMessage: String?

    // MARK: - Published Properties - Customer

    @Published var selectedCustomer: CustomerProfile?
    @Published var customerKYCStatus: CustomerKYCStatus?
    @Published var customerInvestments: [CustomerInvestmentSummary] = []
    @Published var customerDocuments: [CustomerDocumentSummary] = []
    @Published var customerTrades: [CustomerTradeSummary] = []
    @Published var selectedInvestmentTimePeriod: InvestmentTimePeriod = .allTime

    @Published var selectedTradeTimePeriod: InvestmentTimePeriod = .allTime
    // MARK: - Published Properties - Tickets

    @Published var supportTickets: [SupportTicket] = []
    @Published var selectedTicket: SupportTicket?
    @Published var kycStatusList: [CustomerSearchResult] = []

    // MARK: - Published Properties - Customer Tickets (for Customer Detail)

    @Published var customerTickets: [SupportTicket] = []
    @Published var isLoadingCustomerTickets = false

    // MARK: - Published Properties - Sheet States

    @Published var showCreateTicketSheet = false
    @Published var showRespondTicketSheet = false
    @Published var showEscalateTicketSheet = false
    @Published var showKYCStatusList = false
    @Published var showAddSolutionSheet = false
    @Published var showDevEscalationSheet = false
    @Published var showResolveTicketSheet = false
    @Published var showAssignTicketSheet = false
    @Published var showInternalNoteSheet = false
    @Published var showTicketQueueSheet = false
    @Published var showAnalyticsDashboard = false
    @Published var showArchiveView = false
    @Published var showTrendAlerts = false
    @Published var showAgentPerformance = false
    @Published var showBulkOperations = false
    @Published var showNotificationPreferences = false
    @Published var showEmailTemplates = false
    @Published var showFAQKnowledgeBase = false
    @Published var showSupportSettings = false

    // MARK: - Published Properties - Agents

    @Published var availableAgents: [CSRAgent] = []

    // MARK: - Sheet Context

    var ticketForAction: SupportTicket?
    var ticketToRespond: SupportTicket?
    var ticketToEscalate: SupportTicket?
    var preselectedCustomerId: String?

    // MARK: - Computed Properties - Search

    var searchQuery: String {
        get { searchCoordinator.searchQuery }
        set { searchCoordinator.searchQuery = newValue }
    }
    var searchResults: [CustomerSearchResult] { searchCoordinator.searchResults }
    var isSearching: Bool { searchCoordinator.isSearching }

    var permissionsByCategory: [PermissionCategory: [CustomerSupportPermission]] {
        CustomerSupportPermissionsHelper.permissionsByCategory(hasPermission: hasPermission)
    }

    /// The current agent's CSR role
    var currentCSRRole: CSRRole? {
        supportService.currentCSRRole
    }

    // MARK: - Initialization

    init(
        supportService: CustomerSupportServiceProtocol,
        auditService: AuditLoggingServiceProtocol,
        searchCoordinator: CustomerSupportSearchCoordinator
    ) {
        self.supportService = supportService
        self.auditService = auditService
        self.searchCoordinator = searchCoordinator

        setupSearchDebounce()
        setupSearchCoordinatorObservation()
    }

    /// Convenience initializer for backward compatibility
    convenience init(
        supportService: CustomerSupportServiceProtocol,
        auditService: AuditLoggingServiceProtocol,
        ticketCoordinator: CustomerSupportTicketCoordinator,
        customerCoordinator: CustomerSupportCustomerCoordinator,
        kycCoordinator: CustomerSupportKYCCoordinator,
        customerDataLoader: CustomerSupportCustomerDataLoader,
        sheetManager: CustomerSupportSheetManager,
        searchCoordinator: CustomerSupportSearchCoordinator,
        errorHandler: CustomerSupportErrorHandler
    ) {
        self.init(
            supportService: supportService,
            auditService: auditService,
            searchCoordinator: searchCoordinator
        )
    }

    // MARK: - Setup

    private func setupSearchCoordinatorObservation() {
        searchCoordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    private func setupSearchDebounce() {
        searchCoordinator.setupSearchDebounce(cancellables: &cancellables) { [weak self] query in
            await self?.performSearch(query: query)
        }
    }

    // MARK: - Loading

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            supportTickets = try await supportService.getSupportTickets(customerId: nil)
            availableAgents = try await supportService.getAvailableAgents()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Search

    private func performSearch(query: String) async {
        do {
            _ = try await searchCoordinator.performSearch(query: query)
        } catch {
            handleError(error)
        }
    }

    func getAllCustomers() async -> [CustomerSearchResult] {
        do {
            return try await searchCoordinator.getAllCustomers()
        } catch {
            handleError(error)
            return []
        }
    }

    // MARK: - Permission Checking

    func hasPermission(_ permission: CustomerSupportPermission) -> Bool {
        supportService.hasPermission(permission)
    }

    // MARK: - Error Handling (Direct - No Separate Handler)

    func handleError(_ error: Error) {
        let appError = error.toAppError()
        errorMessage = appError.errorDescription ?? "An error occurred"
        showError = true
    }

    func clearError() {
        showError = false
        errorMessage = nil
    }

    func showSuccessMessage(_ message: String) {
        successMessage = message
        showSuccess = true
    }

    func clearSuccess() {
        showSuccess = false
        successMessage = nil
    }

    func showPermissionError(_ permission: CustomerSupportPermission) {
        errorMessage = "Keine Berechtigung: \(permission.rawValue)"
        showError = true
    }
}
