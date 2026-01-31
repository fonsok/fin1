import Foundation

// MARK: - Permission Set
/// Defines the default permissions for customer support representatives
struct CustomerSupportPermissionSet {
    /// Level 1: Standard customer support representative (read + basic support)
    /// ⚠️ Banking Best Practice: L1 has minimal access (Principle of Least Privilege)
    /// L1 can view basic customer info but NOT sensitive trade data (prices, volumes, strategies)
    /// Trade-related inquiries must be escalated to L2
    static let level1: Set<CustomerSupportPermission> = [
        // Read-only permissions (basic customer info only)
        .viewCustomerProfile,
        .viewCustomerKYCStatus,
        .viewCustomerInvestments,  // Investment overview (not detailed trades)
        // ❌ .viewCustomerTrades removed - too sensitive for L1 (Banking Best Practice)
        .viewCustomerDocuments,
        .viewCustomerNotifications,
        .viewCustomerSupportHistory,
        // Support operations
        .createSupportTicket,
        .respondToSupportTicket,
        .addInternalNote,
        // Limited write (with approval)
        .updateCustomerContact
    ]

    /// Level 2: Senior support (L1 + write access + escalation + trade access)
    /// ✅ L2 can view detailed trade data (prices, volumes, strategies) for support inquiries
    static let level2: Set<CustomerSupportPermission> = {
        var permissions = level1
        // Add trade viewing permission (L2+ only)
        permissions.insert(.viewCustomerTrades)
        // Write access
        permissions.insert(.updateCustomerAddress)
        permissions.insert(.updateCustomerName)
        permissions.insert(.resetCustomerPassword)
        permissions.insert(.unlockCustomerAccount)
        permissions.insert(.escalateToAdmin)
        permissions.insert(.initiateKYCReview)
        return permissions
    }()

    /// Fraud Analyst: Fraud detection and temporary account actions
    static let fraudAnalyst: Set<CustomerSupportPermission> = {
        var permissions = level1
        permissions.insert(.viewFraudAlerts)
        permissions.insert(.viewTransactionPatterns)
        permissions.insert(.flagSuspiciousActivity)
        permissions.insert(.suspendAccountTemporary)
        permissions.insert(.suspendAccountExtended)  // Requires 4-Augen
        permissions.insert(.blockPaymentCard)
        permissions.insert(.initiateChargeback)      // Requires 4-Augen
        permissions.insert(.viewAMLFlags)
        permissions.insert(.escalateToAdmin)
        return permissions
    }()

    /// Compliance Officer: KYC, AML, GDPR operations
    /// ✅ Needs trade access for AML checks and SAR reports (regulatory requirement)
    static let complianceOfficer: Set<CustomerSupportPermission> = {
        var permissions = level1
        // Add trade viewing permission (required for AML/SAR analysis)
        permissions.insert(.viewCustomerTrades)
        permissions.insert(.viewAuditLogs)
        permissions.insert(.requestComplianceCheck)
        permissions.insert(.initiateKYCReview)
        permissions.insert(.approveKYCDecision)      // 4-Augen
        permissions.insert(.viewAMLFlags)
        permissions.insert(.viewSARReports)
        permissions.insert(.createSARReport)         // Requires 4-Augen
        permissions.insert(.processGDPRRequest)
        permissions.insert(.approveGDPRDeletion)     // 4-Augen
        permissions.insert(.approveSARSubmission)    // Approver role
        permissions.insert(.approveAccountSuspension) // Approver role
        return permissions
    }()

    /// Tech Support: Logs and technical analysis
    static let techSupport: Set<CustomerSupportPermission> = {
        var permissions = level1
        permissions.insert(.viewAuditLogs)
        permissions.insert(.escalateToAdmin)
        // Tech Support has no write access to customer data
        return permissions
    }()

    /// Teamlead: All permissions including approval authority
    static let teamlead: Set<CustomerSupportPermission> = {
        var permissions = level2
        // Add fraud permissions (read + some actions)
        permissions.insert(.viewFraudAlerts)
        permissions.insert(.viewTransactionPatterns)
        permissions.insert(.viewAMLFlags)
        // Add compliance permissions
        permissions.insert(.viewAuditLogs)
        permissions.insert(.viewSARReports)
        permissions.insert(.requestComplianceCheck)
        // Add approval authority (4-Augen)
        permissions.insert(.approveAccountSuspension)
        permissions.insert(.approveChargeback)
        permissions.insert(.approveSARSubmission)
        permissions.insert(.approveKYCDecision)
        permissions.insert(.approveGDPRDeletion)
        // Administration
        permissions.insert(.manageAgentPermissions)
        return permissions
    }()

    /// Get permissions for a specific role
    static func forRole(_ role: CSRRole) -> Set<CustomerSupportPermission> {
        switch role {
        case .level1: return level1
        case .level2: return level2
        case .fraud: return fraudAnalyst
        case .compliance: return complianceOfficer
        case .techSupport: return techSupport
        case .teamlead: return teamlead
        }
    }

    // MARK: - Legacy aliases for backward compatibility

    @available(*, deprecated, renamed: "level1")
    static var standard: Set<CustomerSupportPermission> { level1 }

    @available(*, deprecated, renamed: "level2")
    static var senior: Set<CustomerSupportPermission> { level2 }
}
