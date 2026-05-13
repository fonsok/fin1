@testable import FIN1
import XCTest

/// Tests for CustomerSupportPermission enum and related functionality
final class CustomerSupportPermissionTests: XCTestCase {

    // MARK: - Display Name Tests

    func testPermission_AllCasesHaveDisplayNames() {
        for permission in CustomerSupportPermission.allCases {
            XCTAssertFalse(
                permission.displayName.isEmpty,
                "Permission \(permission) should have a display name"
            )
        }
    }

    // MARK: - Category Tests

    func testPermission_AllCasesHaveCategories() {
        for permission in CustomerSupportPermission.allCases {
            // Just accessing category should not crash
            _ = permission.category
        }
    }

    func testPermission_ViewingPermissionsAreInViewingCategory() {
        let viewingPermissions: [CustomerSupportPermission] = [
            .viewCustomerProfile,
            .viewCustomerKYCStatus,
            .viewCustomerInvestments,
            .viewCustomerTrades,
            .viewCustomerDocuments,
            .viewCustomerNotifications,
            .viewCustomerSupportHistory
        ]

        for permission in viewingPermissions {
            XCTAssertEqual(
                permission.category,
                .viewing,
                "\(permission) should be in viewing category"
            )
        }
    }

    func testPermission_FraudPermissionsAreInFraudCategory() {
        let fraudPermissions: [CustomerSupportPermission] = [
            .viewFraudAlerts,
            .suspendAccountTemporary,
            .suspendAccountExtended,
            .blockPaymentCard,
            .initiateChargeback,
            .viewTransactionPatterns,
            .flagSuspiciousActivity
        ]

        for permission in fraudPermissions {
            XCTAssertEqual(
                permission.category,
                .fraud,
                "\(permission) should be in fraud category"
            )
        }
    }

    // MARK: - Approval Requirement Tests

    func testPermission_SensitiveActionsRequireApproval() {
        let sensitivePermissions: [CustomerSupportPermission] = [
            .updateCustomerAddress,
            .updateCustomerName,
            .suspendAccountExtended,
            .initiateChargeback,
            .createSARReport,
            .approveGDPRDeletion
        ]

        for permission in sensitivePermissions {
            XCTAssertTrue(
                permission.requiresApproval,
                "\(permission) should require approval"
            )
        }
    }

    func testPermission_ReadOnlyActionsDoNotRequireApproval() {
        let readOnlyPermissions: [CustomerSupportPermission] = [
            .viewCustomerProfile,
            .viewCustomerTrades,
            .viewAuditLogs,
            .viewFraudAlerts
        ]

        for permission in readOnlyPermissions {
            XCTAssertFalse(
                permission.requiresApproval,
                "\(permission) should not require approval"
            )
        }
    }

    // MARK: - Read-Only Tests

    func testPermission_ReadOnlyFlagIsCorrect() {
        let readOnlyPermissions: [CustomerSupportPermission] = [
            .viewCustomerProfile,
            .viewCustomerKYCStatus,
            .viewCustomerInvestments,
            .viewCustomerTrades,
            .viewCustomerDocuments,
            .viewCustomerNotifications,
            .viewCustomerSupportHistory,
            .viewAuditLogs,
            .viewFraudAlerts,
            .viewTransactionPatterns,
            .viewSARReports,
            .viewAMLFlags
        ]

        for permission in readOnlyPermissions {
            XCTAssertTrue(
                permission.isReadOnly,
                "\(permission) should be read-only"
            )
        }
    }

    func testPermission_WritePermissionsAreNotReadOnly() {
        let writePermissions: [CustomerSupportPermission] = [
            .updateCustomerContact,
            .resetCustomerPassword,
            .unlockCustomerAccount,
            .suspendAccountTemporary,
            .blockPaymentCard
        ]

        for permission in writePermissions {
            XCTAssertFalse(
                permission.isReadOnly,
                "\(permission) should not be read-only"
            )
        }
    }

    // MARK: - Compliance Check Tests

    func testPermission_SensitiveChangesTriggerComplianceCheck() {
        let complianceTriggering: [CustomerSupportPermission] = [
            .updateCustomerAddress,
            .updateCustomerName,
            .resetCustomerPassword,
            .suspendAccountTemporary,
            .suspendAccountExtended,
            .blockPaymentCard,
            .flagSuspiciousActivity
        ]

        for permission in complianceTriggering {
            XCTAssertTrue(
                permission.triggersComplianceCheck,
                "\(permission) should trigger compliance check"
            )
        }
    }

    // MARK: - AML Documentation Tests

    func testPermission_AMLActionsRequireDocumentation() {
        let amlPermissions: [CustomerSupportPermission] = [
            .createSARReport,
            .flagSuspiciousActivity,
            .suspendAccountExtended,
            .viewAMLFlags
        ]

        for permission in amlPermissions {
            XCTAssertTrue(
                permission.requiresAMLDocumentation,
                "\(permission) should require AML documentation"
            )
        }
    }

    // MARK: - Permission Check Result Tests

    func testPermissionCheckResult_Allowed() {
        let result = PermissionCheckResult.allowed(.viewCustomerProfile)

        XCTAssertTrue(result.isAllowed)
        XCTAssertNil(result.reason)
        XCTAssertEqual(result.permission, .viewCustomerProfile)
    }

    func testPermissionCheckResult_Denied() {
        let result = PermissionCheckResult.denied(.resetCustomerPassword, reason: "Insufficient permissions")

        XCTAssertFalse(result.isAllowed)
        XCTAssertEqual(result.reason, "Insufficient permissions")
        XCTAssertEqual(result.permission, .resetCustomerPassword)
    }

    func testPermissionCheckResult_AllowedWithApproval() {
        let result = PermissionCheckResult.allowed(.updateCustomerAddress)

        XCTAssertTrue(result.isAllowed)
        XCTAssertTrue(result.requiresApproval)
    }

    // MARK: - Codable Tests

    func testPermission_EncodesAndDecodes() throws {
        for permission in CustomerSupportPermission.allCases {
            let encoder = JSONEncoder()
            let data = try encoder.encode(permission)

            let decoder = JSONDecoder()
            let decodedPermission = try decoder.decode(CustomerSupportPermission.self, from: data)

            XCTAssertEqual(permission, decodedPermission)
        }
    }
}
