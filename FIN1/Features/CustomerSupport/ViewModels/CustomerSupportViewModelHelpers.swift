import Foundation
import Combine

// MARK: - Customer Support ViewModel Helpers
/// Helper classes to organize ViewModel functionality

// MARK: - Sheet Manager

@MainActor
final class CustomerSupportSheetManager: ObservableObject {
    @Published var showCreateTicketSheet = false
    @Published var showRespondTicketSheet = false
    @Published var showEscalateTicketSheet = false
    @Published var showKYCStatusList = false

    /// Parse `objectId` / stable user id for ticket creation (not Kundennummer).
    var preselectedUserId: String?
    var ticketToRespond: SupportTicket?
    var ticketToEscalate: SupportTicket?

    func openCreateTicketSheet(userId: String? = nil) {
        preselectedUserId = userId
        showCreateTicketSheet = true
    }

    func closeCreateTicketSheet() {
        showCreateTicketSheet = false
        preselectedUserId = nil
    }

    func openRespondTicketSheet(for ticket: SupportTicket) {
        ticketToRespond = ticket
        showRespondTicketSheet = true
    }

    func closeRespondTicketSheet() {
        showRespondTicketSheet = false
        ticketToRespond = nil
    }

    func openEscalateTicketSheet(for ticket: SupportTicket) {
        ticketToEscalate = ticket
        showEscalateTicketSheet = true
    }

    func closeEscalateTicketSheet() {
        showEscalateTicketSheet = false
        ticketToEscalate = nil
    }

    func openKYCStatusList() {
        showKYCStatusList = true
    }

    func closeKYCStatusList() {
        showKYCStatusList = false
    }
}

// MARK: - Search Coordinator

@MainActor
final class CustomerSupportSearchCoordinator: ObservableObject {
    private let supportService: CustomerSupportServiceProtocol

    @Published var searchQuery = ""
    @Published var searchResults: [CustomerSearchResult] = []
    @Published var isSearching = false

    init(supportService: CustomerSupportServiceProtocol) {
        self.supportService = supportService
    }

    func setupSearchDebounce(cancellables: inout Set<AnyCancellable>, onSearch: @escaping (String) async -> Void) {
        $searchQuery
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { query in
                Task { @MainActor in
                    await onSearch(query)
                }
            }
            .store(in: &cancellables)
    }

    func performSearch(query: String) async throws -> [CustomerSearchResult] {
        guard !query.isEmpty else {
            searchResults = []
            return []
        }
        isSearching = true
        defer { isSearching = false }
        let results = try await supportService.searchCustomers(query: query)
        searchResults = results
        return results
    }

    func getAllCustomers() async throws -> [CustomerSearchResult] {
        try await supportService.searchCustomers(query: "")
    }
}

// MARK: - Error Handler

@MainActor
final class CustomerSupportErrorHandler: ObservableObject {
    @Published var showError = false
    @Published var errorMessage: String?
    @Published var showSuccess = false
    @Published var successMessage: String?

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
        errorMessage = "Keine Berechtigung: \(permission.displayName)"
        showError = true
    }
}

// MARK: - Ticket Coordinator

@MainActor
final class CustomerSupportTicketCoordinator {
    private let supportService: CustomerSupportServiceProtocol

    init(supportService: CustomerSupportServiceProtocol) {
        self.supportService = supportService
    }

    func loadTickets(userId: String?) async throws -> [SupportTicket] {
        try await supportService.getSupportTickets(userId: userId)
    }
}

// MARK: - Customer Coordinator

@MainActor
final class CustomerSupportCustomerCoordinator {
    private let supportService: CustomerSupportServiceProtocol

    init(supportService: CustomerSupportServiceProtocol) {
        self.supportService = supportService
    }

    func getProfile(userId: String) async throws -> CustomerProfile? {
        try await supportService.getCustomerProfile(userId: userId)
    }
}

// MARK: - KYC Coordinator

@MainActor
final class CustomerSupportKYCCoordinator {
    private let supportService: CustomerSupportServiceProtocol

    init(supportService: CustomerSupportServiceProtocol) {
        self.supportService = supportService
    }

    func getKYCStatus(customerNumber: String) async throws -> CustomerKYCStatus {
        try await supportService.getCustomerKYCStatus(customerNumber: customerNumber)
    }
}

// MARK: - Customer Data Loader

@MainActor
final class CustomerSupportCustomerDataLoader {
    private let supportService: CustomerSupportServiceProtocol

    init(supportService: CustomerSupportServiceProtocol) {
        self.supportService = supportService
    }

    func loadInvestments(userId: String) async throws -> [CustomerInvestmentSummary] {
        try await supportService.getCustomerInvestments(userId: userId)
    }

    func loadDocuments(customerNumber: String) async throws -> [CustomerDocumentSummary] {
        try await supportService.getCustomerDocuments(customerNumber: customerNumber)
    }
}

// MARK: - Ticket Operations Handler

@MainActor
final class CustomerSupportTicketOperationsHandler {
    private let supportService: CustomerSupportServiceProtocol
    private weak var viewModel: CustomerSupportDashboardViewModel?

    init(supportService: CustomerSupportServiceProtocol, viewModel: CustomerSupportDashboardViewModel) {
        self.supportService = supportService
        self.viewModel = viewModel
    }

    func createTicket(userId: String, subject: String, description: String, priority: SupportTicket.TicketPriority) async {
        do {
            let ticket = SupportTicketCreate(userId: userId, subject: subject, description: description, priority: priority)
            _ = try await supportService.createSupportTicket(ticket)
            viewModel?.showSuccessMessage("Ticket wurde erstellt.")
            await viewModel?.load()
        } catch {
            viewModel?.handleError(error)
        }
    }

    func respondToTicket(_ ticketId: String, message: String, isInternal: Bool, selectedTicketId: String?) async {
        do {
            try await supportService.respondToTicket(ticketId: ticketId, response: message, isInternal: isInternal)
            viewModel?.showSuccessMessage("Antwort wurde gesendet.")
            await viewModel?.load()
        } catch {
            viewModel?.handleError(error)
        }
    }

    func escalateTicket(_ ticketId: String, reason: String) async {
        do {
            try await supportService.escalateTicket(ticketId: ticketId, reason: reason)
            viewModel?.showSuccessMessage("Ticket wurde eskaliert.")
            await viewModel?.load()
        } catch {
            viewModel?.handleError(error)
        }
    }
}

// MARK: - Customer Operations Handler

@MainActor
final class CustomerSupportCustomerOperationsHandler {
    private let supportService: CustomerSupportServiceProtocol
    private weak var viewModel: CustomerSupportDashboardViewModel?

    init(supportService: CustomerSupportServiceProtocol, viewModel: CustomerSupportDashboardViewModel) {
        self.supportService = supportService
        self.viewModel = viewModel
    }

    func initiatePasswordReset(customerNumber: String) async {
        do {
            try await supportService.initiatePasswordReset(customerNumber: customerNumber)
            viewModel?.showSuccessMessage("Passwort-Reset wurde initiiert.")
        } catch {
            viewModel?.handleError(error)
        }
    }

    func unlockAccount(customerNumber: String, reason: String) async {
        do {
            try await supportService.unlockAccount(customerNumber: customerNumber, reason: reason)
            viewModel?.showSuccessMessage("Konto wurde entsperrt.")
        } catch {
            viewModel?.handleError(error)
        }
    }
}

// MARK: - Customer Selection Handler

@MainActor
final class CustomerSupportCustomerSelectionHandler {
    private let supportService: CustomerSupportServiceProtocol
    private let dataLoader: CustomerSupportCustomerDataLoader
    private weak var viewModel: CustomerSupportDashboardViewModel?

    init(supportService: CustomerSupportServiceProtocol, dataLoader: CustomerSupportCustomerDataLoader, viewModel: CustomerSupportDashboardViewModel) {
        self.supportService = supportService
        self.dataLoader = dataLoader
        self.viewModel = viewModel
    }

    func selectCustomer(_ result: CustomerSearchResult) async {
        do {
            let profile = try await supportService.getCustomerProfile(userId: result.id)
            viewModel?.selectedCustomer = profile
            if let profile {
                viewModel?.customerKYCStatus = try await supportService.getCustomerKYCStatus(customerNumber: profile.customerNumber)
                viewModel?.customerInvestments = try await dataLoader.loadInvestments(userId: profile.id)
                viewModel?.customerDocuments = try await dataLoader.loadDocuments(customerNumber: profile.customerNumber)
            }
        } catch {
            viewModel?.handleError(error)
        }
    }
}

// MARK: - KYC Operations Handler

@MainActor
final class CustomerSupportKYCOperationsHandler {
    private let supportService: CustomerSupportServiceProtocol
    private weak var viewModel: CustomerSupportDashboardViewModel?

    init(supportService: CustomerSupportServiceProtocol, viewModel: CustomerSupportDashboardViewModel) {
        self.supportService = supportService
        self.viewModel = viewModel
    }

    func loadKYCStatusList() async {
        do {
            let customers = try await supportService.searchCustomers(query: "")
            viewModel?.kycStatusList = customers
        } catch {
            viewModel?.handleError(error)
        }
    }
}

// MARK: - ViewModel Builder

enum CustomerSupportViewModelBuilder {
    struct Handlers {
        let ticketOperationsHandler: CustomerSupportTicketOperationsHandler
        let customerOperationsHandler: CustomerSupportCustomerOperationsHandler
        let customerSelectionHandler: CustomerSupportCustomerSelectionHandler
        let kycOperationsHandler: CustomerSupportKYCOperationsHandler
    }

    @MainActor
    static func buildHandlers(
        supportService: CustomerSupportServiceProtocol,
        ticketCoordinator: CustomerSupportTicketCoordinator,
        customerCoordinator: CustomerSupportCustomerCoordinator,
        kycCoordinator: CustomerSupportKYCCoordinator,
        customerDataLoader: CustomerSupportCustomerDataLoader,
        viewModel: CustomerSupportDashboardViewModel
    ) -> Handlers {
        Handlers(
            ticketOperationsHandler: CustomerSupportTicketOperationsHandler(supportService: supportService, viewModel: viewModel),
            customerOperationsHandler: CustomerSupportCustomerOperationsHandler(supportService: supportService, viewModel: viewModel),
            customerSelectionHandler: CustomerSupportCustomerSelectionHandler(supportService: supportService, dataLoader: customerDataLoader, viewModel: viewModel),
            kycOperationsHandler: CustomerSupportKYCOperationsHandler(supportService: supportService, viewModel: viewModel)
        )
    }
}

// MARK: - Permissions Helper

enum CustomerSupportPermissionsHelper {
    static func permissionsByCategory(hasPermission: (CustomerSupportPermission) -> Bool) -> [PermissionCategory: [CustomerSupportPermission]] {
        var result: [PermissionCategory: [CustomerSupportPermission]] = [:]
        for permission in CustomerSupportPermission.allCases {
            if hasPermission(permission) {
                let category = permission.category
                if result[category] == nil {
                    result[category] = []
                }
                result[category]?.append(permission)
            }
        }
        return result
    }
}

