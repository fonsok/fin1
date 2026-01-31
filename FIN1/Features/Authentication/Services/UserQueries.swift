import Foundation

// MARK: - User Queries Extension
/// Provides computed properties for user state queries
extension UserService {

    // MARK: - User Queries

    var userDisplayName: String {
        currentUser?.displayName ?? "Guest"
    }

    var userRole: UserRole? {
        currentUser?.role
    }

    var isInvestor: Bool {
        currentUser?.role == .investor
    }

    var isTrader: Bool {
        currentUser?.role == .trader
    }
}
