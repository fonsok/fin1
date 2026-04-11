import Foundation
import Combine
import os.log

// MARK: - Customer Support Service Implementation
/// Handles customer support operations with RBAC and audit logging
/// Implements least privilege principle and compliance checks
///
/// This service is split into multiple files for maintainability:
/// - `CustomerSupportService.swift` - Core: properties, init, permissions, helpers
/// - `CustomerSupportService+CustomerData.swift` - Customer search and data access
/// - `CustomerSupportService+Tickets.swift` - Ticket operations (CSR and user)
/// - `CustomerSupportService+Modifications.swift` - Account modifications

final class CustomerSupportService: CustomerSupportServiceProtocol, ServiceLifecycle {

    // MARK: - Properties (Internal for Extensions)

    let logger = Logger(subsystem: "com.fin.app", category: "CustomerSupport")
    let auditService: AuditLoggingServiceProtocol
    let userService: any UserServiceProtocol
    let notificationService: any NotificationServiceProtocol
    let assignmentService: TicketAssignmentService
    let satisfactionSurveyService: SatisfactionSurveyServiceProtocol

    // Real data services for investments and trades
    let investmentService: (any InvestmentServiceProtocol)?
    let tradeLifecycleService: (any TradeLifecycleServiceProtocol)?

    /// Returns the current agent's permissions based on their CSR role
    /// Falls back to standard permissions if no CSR role is set
    var currentPermissions: Set<CustomerSupportPermission> {
        if let csrRole = userService.currentUser?.csrRole {
            return CustomerSupportPermissionSet.forRole(csrRole)
        }
        return fallbackPermissions
    }

    /// Fallback permissions for non-CSR users or when role is not set
    private var fallbackPermissions: Set<CustomerSupportPermission>
    var mockCustomers: [CustomerProfile] = []
    var mockTickets: [SupportTicket] = []
    var mockAgents: [CSRAgent] = []

    // Backend integration
    var ticketAPIService: TicketAPIServiceProtocol?

    // MARK: - Initialization

    init(
        auditService: AuditLoggingServiceProtocol,
        userService: any UserServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        satisfactionSurveyService: SatisfactionSurveyServiceProtocol,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        tradeLifecycleService: (any TradeLifecycleServiceProtocol)? = nil,
        permissionSet: Set<CustomerSupportPermission> = CustomerSupportPermissionSet.level1,
        assignmentConfiguration: TicketAssignmentService.Configuration = .default
    ) {
        self.auditService = auditService
        self.userService = userService
        self.notificationService = notificationService
        self.satisfactionSurveyService = satisfactionSurveyService
        self.investmentService = investmentService
        self.tradeLifecycleService = tradeLifecycleService
        self.fallbackPermissions = permissionSet
        self.assignmentService = TicketAssignmentService(configuration: assignmentConfiguration)
        self.mockCustomers = CustomerSupportMockData.createMockCustomers()
        self.mockTickets = CustomerSupportMockData.createMockTickets(customers: mockCustomers)
        self.mockAgents = CustomerSupportMockData.createMockAgents()
    }

    // MARK: - ServiceLifecycle

    func start() { logger.info("CustomerSupportService started") }
    func stop() { logger.info("CustomerSupportService stopped") }
    func reset() { logger.info("CustomerSupportService reset") }

    // MARK: - Backend Configuration

    /// Configures the ticket API service for backend synchronization
    func configure(ticketAPIService: TicketAPIServiceProtocol) {
        self.ticketAPIService = ticketAPIService
    }

    // MARK: - Backend Synchronization

    /// Syncs pending tickets to the backend
    func syncToBackend() async {
        guard let apiService = ticketAPIService else {
            print("⚠️ CustomerSupportService: No API service configured, skipping sync")
            return
        }

        print("📤 CustomerSupportService: Syncing pending tickets to backend...")

        // Sync pending tickets (without Parse objectId or with local- prefix)
        let pendingTickets = mockTickets.filter { ticket in
            ticket.id.starts(with: "local-") ||
            !ticket.id.contains("-") || // UUID without Parse objectId format
            ticket.id.count == 36 // Standard UUID format (not Parse objectId)
        }

        print("📤 CustomerSupportService: Found \(pendingTickets.count) pending tickets to sync")

        for ticket in pendingTickets {
            do {
                let ticketCreate = SupportTicketCreate(
                    userId: ticket.userId,
                    subject: ticket.subject,
                    description: ticket.description,
                    priority: ticket.priority
                )

                let syncedTicket = try await apiService.createTicket(ticketCreate)

                // Update local ticket with Parse objectId
                await MainActor.run {
                    if let index = self.mockTickets.firstIndex(where: { $0.id == ticket.id }) {
                        self.mockTickets[index] = syncedTicket
                    }
                }

                print("✅ CustomerSupportService: Synced ticket \(ticket.ticketNumber)")
            } catch {
                print("⚠️ CustomerSupportService: Failed to sync ticket \(ticket.ticketNumber): \(error.localizedDescription)")
            }
        }

        print("✅ CustomerSupportService: Background sync completed")
    }

    // MARK: - Permission Checking

    func hasPermission(_ permission: CustomerSupportPermission) -> Bool {
        currentPermissions.contains(permission)
    }

    func checkPermission(_ permission: CustomerSupportPermission) -> PermissionCheckResult {
        guard currentPermissions.contains(permission) else {
            return .denied(permission, reason: "Keine Berechtigung für diese Aktion")
        }
        return .allowed(permission)
    }

    // MARK: - Internal Helpers (Used by Extensions)

    var currentAgentId: String {
        userService.currentUser?.id ?? "unknown"
    }

    var currentAgentRole: UserRole {
        userService.userRole ?? .other
    }

    var currentCSRRole: CSRRole? {
        userService.currentUser?.csrRole
    }

    var currentAgentName: String {
        guard let user = userService.currentUser else { return "Unbekannter Agent" }
        var nameParts: [String] = []
        if !user.academicTitle.isEmpty { nameParts.append(user.academicTitle) }
        if !user.firstName.isEmpty { nameParts.append(user.firstName) }
        if !user.lastName.isEmpty { nameParts.append(user.lastName) }
        return nameParts.isEmpty ? user.username : nameParts.joined(separator: " ")
    }

    func validatePermission(_ permission: CustomerSupportPermission) async throws {
        let result = checkPermission(permission)
        guard result.isAllowed else {
            throw CustomerSupportError.permissionDenied(result.reason ?? "Keine Berechtigung")
        }
    }

    func logAction(
        _ permission: CustomerSupportPermission,
        customerId: String?,
        description: String,
        actionType: AuditActionType = .update
    ) async {
        let action = AuditAction(
            agentId: currentAgentId,
            agentRole: currentAgentRole.rawValue,
            customerId: customerId,
            actionType: actionType,
            permission: permission,
            description: description
        )
        await auditService.logAction(action)
    }

    func logDataAccess(
        dataCategory: DataCategory,
        accessType: DataAccessType,
        fields: [String],
        purpose: String,
        customerId: String? = nil
    ) async {
        guard let customerId = customerId else { return }

        let access = DataAccessLog(
            agentId: currentAgentId,
            customerId: customerId,
            dataCategory: dataCategory,
            accessType: accessType,
            fields: fields,
            purpose: purpose,
            legalBasis: .legitimateInterests
        )
        await auditService.logDataAccess(access)
    }
}

// MARK: - Customer Support Error

enum CustomerSupportError: Error, LocalizedError {
    case permissionDenied(String)
    case customerNotFound
    case ticketNotFound
    case invalidRequest(String)
    case complianceCheckFailed(String)
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let reason): return "Zugriff verweigert: \(reason)"
        case .customerNotFound: return "Kunde nicht gefunden"
        case .ticketNotFound: return "Ticket nicht gefunden"
        case .invalidRequest(let reason): return "Ungültige Anfrage: \(reason)"
        case .complianceCheckFailed(let reason): return "Compliance-Prüfung fehlgeschlagen: \(reason)"
        case .serviceUnavailable: return "Service nicht verfügbar"
        }
    }
}
