@testable import FIN1
import XCTest

/// Tests for CSRRole enum and role-based permissions
final class CSRRoleTests: XCTestCase {

    // MARK: - Role Properties Tests

    func testCSRRole_DisplayNames_AreCorrect() {
        XCTAssertEqual(CSRRole.level1.displayName, "Level 1 Support")
        XCTAssertEqual(CSRRole.level2.displayName, "Level 2 Support")
        XCTAssertEqual(CSRRole.fraud.displayName, "Fraud Analyst")
        XCTAssertEqual(CSRRole.compliance.displayName, "Compliance Officer")
        XCTAssertEqual(CSRRole.techSupport.displayName, "Tech Support")
        XCTAssertEqual(CSRRole.teamlead.displayName, "Teamlead")
    }

    func testCSRRole_ShortNames_AreCorrect() {
        XCTAssertEqual(CSRRole.level1.shortName, "L1")
        XCTAssertEqual(CSRRole.level2.shortName, "L2")
        XCTAssertEqual(CSRRole.fraud.shortName, "Fraud")
        XCTAssertEqual(CSRRole.compliance.shortName, "Compliance")
        XCTAssertEqual(CSRRole.techSupport.shortName, "Tech")
        XCTAssertEqual(CSRRole.teamlead.shortName, "Lead")
    }

    func testCSRRole_Icons_AreDefined() {
        for role in CSRRole.allCases {
            XCTAssertFalse(role.icon.isEmpty, "Icon should be defined for \(role)")
        }
    }

    // MARK: - Approval Authority Tests

    func testCSRRole_CanApprove_OnlyTeamleadAndCompliance() {
        XCTAssertFalse(CSRRole.level1.canApprove)
        XCTAssertFalse(CSRRole.level2.canApprove)
        XCTAssertFalse(CSRRole.fraud.canApprove)
        XCTAssertTrue(CSRRole.compliance.canApprove)
        XCTAssertFalse(CSRRole.techSupport.canApprove)
        XCTAssertTrue(CSRRole.teamlead.canApprove)
    }

    // MARK: - Permission Tests

    func testLevel1_HasReadPermissions() {
        let permissions = CSRRole.level1.permissions

        XCTAssertTrue(permissions.contains(.viewCustomerProfile))
        // ❌ Banking Best Practice: L1 should NOT have access to detailed trade data
        XCTAssertFalse(permissions.contains(.viewCustomerTrades), "L1 should not have trade access (too sensitive)")
        XCTAssertTrue(permissions.contains(.viewCustomerInvestments))
        XCTAssertTrue(permissions.contains(.createSupportTicket))
    }

    func testLevel1_DoesNotHaveTradeAccess() {
        let permissions = CSRRole.level1.permissions
        // Banking Best Practice: Trade data (prices, volumes, strategies) is too sensitive for L1
        XCTAssertFalse(permissions.contains(.viewCustomerTrades))
    }

    func testLevel2_HasTradeAccess() {
        let permissions = CSRRole.level2.permissions
        // L2 can view detailed trades for support inquiries
        XCTAssertTrue(permissions.contains(.viewCustomerTrades))
    }

    func testLevel1_DoesNotHaveWritePermissions() {
        let permissions = CSRRole.level1.permissions

        XCTAssertFalse(permissions.contains(.resetCustomerPassword))
        XCTAssertFalse(permissions.contains(.unlockCustomerAccount))
        XCTAssertFalse(permissions.contains(.suspendAccountTemporary))
    }

    func testLevel2_HasMorePermissionsThanLevel1() {
        let level1Permissions = CSRRole.level1.permissions
        let level2Permissions = CSRRole.level2.permissions

        XCTAssertTrue(level2Permissions.count > level1Permissions.count)
        XCTAssertTrue(level2Permissions.contains(.resetCustomerPassword))
        XCTAssertTrue(level2Permissions.contains(.unlockCustomerAccount))
    }

    func testFraud_HasFraudSpecificPermissions() {
        let permissions = CSRRole.fraud.permissions

        XCTAssertTrue(permissions.contains(.viewFraudAlerts))
        XCTAssertTrue(permissions.contains(.suspendAccountTemporary))
        XCTAssertTrue(permissions.contains(.blockPaymentCard))
        XCTAssertTrue(permissions.contains(.viewTransactionPatterns))
    }

    func testCompliance_HasComplianceSpecificPermissions() {
        let permissions = CSRRole.compliance.permissions

        XCTAssertTrue(permissions.contains(.viewAuditLogs))
        XCTAssertTrue(permissions.contains(.processGDPRRequest))
        XCTAssertTrue(permissions.contains(.createSARReport))
        XCTAssertTrue(permissions.contains(.approveKYCDecision))
    }

    func testTechSupport_HasLimitedPermissions() {
        let permissions = CSRRole.techSupport.permissions

        XCTAssertTrue(permissions.contains(.viewAuditLogs))
        XCTAssertFalse(permissions.contains(.resetCustomerPassword))
        XCTAssertFalse(permissions.contains(.suspendAccountTemporary))
    }

    func testTeamlead_HasAllApprovalPermissions() {
        let permissions = CSRRole.teamlead.permissions

        XCTAssertTrue(permissions.contains(.approveAccountSuspension))
        XCTAssertTrue(permissions.contains(.approveChargeback))
        XCTAssertTrue(permissions.contains(.approveSARSubmission))
        XCTAssertTrue(permissions.contains(.manageAgentPermissions))
    }

    // MARK: - Permission Hierarchy Tests

    func testPermissionHierarchy_TeamleadHasMostPermissions() {
        let allRoles = CSRRole.allCases
        let teamleadCount = CSRRole.teamlead.permissions.count

        for role in allRoles where role != .teamlead {
            XCTAssertLessThanOrEqual(
                role.permissions.count,
                teamleadCount,
                "\(role) should not have more permissions than Teamlead"
            )
        }
    }

    func testPermissionHierarchy_Level2SupersetOfLevel1() {
        let level1Permissions = CSRRole.level1.permissions
        let level2Permissions = CSRRole.level2.permissions

        XCTAssertTrue(level1Permissions.isSubset(of: level2Permissions))
    }

    // MARK: - Codable Tests

    func testCSRRole_EncodesAndDecodes() throws {
        for role in CSRRole.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(role)

            let decoder = JSONDecoder()
            let decodedRole = try decoder.decode(CSRRole.self, from: data)

            XCTAssertEqual(role, decodedRole)
        }
    }
}
