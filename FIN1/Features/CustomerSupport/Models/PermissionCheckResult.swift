import Foundation

// MARK: - Permission Check Result
/// Result of a permission check operation
struct PermissionCheckResult {
    let permission: CustomerSupportPermission
    let isAllowed: Bool
    let requiresApproval: Bool
    let reason: String?

    static func allowed(_ permission: CustomerSupportPermission) -> PermissionCheckResult {
        PermissionCheckResult(
            permission: permission,
            isAllowed: true,
            requiresApproval: permission.requiresApproval,
            reason: nil
        )
    }

    static func denied(_ permission: CustomerSupportPermission, reason: String) -> PermissionCheckResult {
        PermissionCheckResult(
            permission: permission,
            isAllowed: false,
            requiresApproval: false,
            reason: reason
        )
    }
}
