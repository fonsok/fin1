import Foundation
import Combine

// MARK: - Customer Support Service Protocol
/// Defines the contract for customer support operations
/// Implements least privilege principle with granular permissions

protocol CustomerSupportServiceProtocol: AnyObject {
    /// The current agent's permissions
    var currentPermissions: Set<CustomerSupportPermission> { get }

    /// The current agent's CSR role (if applicable)
    var currentCSRRole: CSRRole? { get }

    // MARK: - Permission Checking
    func hasPermission(_ permission: CustomerSupportPermission) -> Bool
    func checkPermission(_ permission: CustomerSupportPermission) -> PermissionCheckResult

    // MARK: - Customer Search (Read-Only)
    func searchCustomers(query: String) async throws -> [CustomerSearchResult]
    func getCustomerProfile(userId: String) async throws -> CustomerProfile?

    // MARK: - Customer Data Access (Audited)
    func getCustomerInvestments(userId: String) async throws -> [CustomerInvestmentSummary]
    func getCustomerTrades(userId: String) async throws -> [CustomerTradeSummary]
    func getCustomerDocuments(customerNumber: String) async throws -> [CustomerDocumentSummary]
    func getCustomerKYCStatus(customerNumber: String) async throws -> CustomerKYCStatus

    // MARK: - Support Operations
    func getSupportTickets(userId: String?) async throws -> [SupportTicket]
    func getUserTickets(userId: String) async throws -> [SupportTicket]
    func getTicket(ticketId: String) async throws -> SupportTicket?
    func createSupportTicket(_ ticket: SupportTicketCreate) async throws -> SupportTicket
    func respondToTicket(ticketId: String, response: String, isInternal: Bool) async throws
    func escalateTicket(ticketId: String, reason: String) async throws
    /// Internal escalation method for automatic escalations (bypasses permission check)
    func escalateTicketInternal(ticketId: String, reason: String, isAutomatic: Bool) async throws

    // MARK: - User Self-Service Ticket Creation
    func createUserTicket(
        userId: String,
        subject: String,
        description: String,
        category: String
    ) async throws -> SupportTicket

    // MARK: - Ticket Assignment
    func getAvailableAgents() async throws -> [CSRAgent]
    func assignTicket(ticketId: String, to agentId: String) async throws

    // MARK: - Solution Development & Documentation
    func addSolution(
        ticketId: String,
        solution: SolutionDetails,
        customerMessage: String
    ) async throws

    func addInternalNote(ticketId: String, note: String) async throws
    func escalateToDevTeam(ticketId: String, escalation: DevEscalation) async throws

    // MARK: - Ticket Resolution
    func resolveTicket(ticketId: String, resolutionNote: String, customerConfirmed: Bool) async throws
    func closeTicket(ticketId: String, closureReason: String) async throws
    func requestCustomerConfirmation(ticketId: String, message: String) async throws

    // MARK: - User Confirmation (Self-Service)
    func userConfirmProblemSolved(ticketId: String, userId: String) async throws
    func userReportProblemNotSolved(ticketId: String, userId: String, additionalInfo: String) async throws

    // MARK: - Ticket Lifecycle Management
    /// Reopen a closed ticket within the 7-day grace period
    func reopenTicket(ticketId: String, reason: String) async throws
    /// User requests to reopen their closed ticket (creates new linked ticket if grace period expired)
    func userRequestReopenTicket(ticketId: String, userId: String, reason: String) async throws -> SupportTicket
    /// Archive old closed tickets (called by background job or manually)
    func archiveOldTickets() async throws -> Int
    /// Get tickets related to a customer (previous tickets, linked tickets)
    func getRelatedTickets(userId: String, excludeTicketId: String?) async throws -> [SupportTicket]

    // MARK: - Analytics & Metrics
    func getTicketMetrics(from startDate: Date, to endDate: Date) async throws -> TicketMetrics
    func getAgentMetrics(agentId: String, from startDate: Date, to endDate: Date) async throws -> AgentMetrics

    // MARK: - Approved Modifications (Compliance Checked)
    func requestAddressChange(customerNumber: String, newAddress: CSAddressChangeInput) async throws -> ChangeRequest
    func requestNameChange(customerNumber: String, newName: CSNameChangeInput) async throws -> ChangeRequest
    func initiatePasswordReset(customerNumber: String) async throws
    func unlockAccount(customerNumber: String, reason: String) async throws

    // MARK: - Backend Synchronization
    func syncToBackend() async
}
