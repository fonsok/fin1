import Foundation
import Combine

// MARK: - Audit Logging Service Protocol
/// Defines the contract for auditable action logging
/// Compliant with AML, GDPR, and regulatory requirements

protocol AuditLoggingServiceProtocol: AnyObject {
    /// Log a customer support action for audit trail
    func logAction(_ action: AuditAction) async

    /// Log access to sensitive customer data
    func logDataAccess(_ access: DataAccessLog) async

    /// Log a compliance event (e.g., sensitive data change)
    func logComplianceEvent(_ event: ComplianceEvent) async

    /// Retrieve audit logs for a specific customer (admin only)
    func getAuditLogs(for customerId: String, dateRange: DateInterval?) async throws -> [AuditLogEntry]

    /// Retrieve actions by a specific agent
    func getAgentActions(agentId: String, dateRange: DateInterval?) async throws -> [AuditLogEntry]

    // MARK: - Convenience Methods

    /// Log a simple view action
    func logViewAction(
        agentId: String,
        agentRole: UserRole,
        customerId: String,
        viewedData: String
    ) async

    /// Log a customer data modification with compliance check
    func logModificationWithCompliance(
        agentId: String,
        agentRole: UserRole,
        customerId: String,
        permission: CustomerSupportPermission,
        fieldName: String,
        previousValue: String,
        newValue: String,
        complianceEventType: ComplianceEventType?
    ) async
}





