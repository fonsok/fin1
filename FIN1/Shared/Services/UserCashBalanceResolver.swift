import Foundation

// MARK: - User cash balance (server SSOT — ADR-019 Phase 3)

struct BackendUserCashBalanceResponse: Decodable {
    let userId: String
    let currentBalance: Double
    let source: String
}

enum UserCashBalanceResolver {
    /// Fetches authoritative `UserCashBalance.currentBalance` for the logged-in user.
    static func fetchCurrentBalance(
        settlementAPIService: any SettlementAPIServiceProtocol
    ) async -> Double? {
        do {
            let response = try await settlementAPIService.fetchUserCashBalance()
            return response.currentBalance
        } catch {
            print("⚠️ UserCashBalanceResolver: fetch failed — \(error.localizedDescription)")
            return nil
        }
    }
}
