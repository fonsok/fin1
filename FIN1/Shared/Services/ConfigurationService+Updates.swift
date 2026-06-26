@preconcurrency import Dispatch
import Foundation

// MARK: - ConfigurationService Update Methods Extension
/// Local read helpers and CSR-only settings. Remote admin parameters are SSOT in the Admin Web Portal.
extension ConfigurationService {

    func getPendingConfigurationChanges() async throws -> [PendingConfigurationChange] {
        throw ConfigurationError.serverManagedConfiguration
    }

    func approveConfigurationChange(requestId: String, notes: String?) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func rejectConfigurationChange(requestId: String, reason: String) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func updateMinimumCashReserve(_ value: Double) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func updateMinimumCashReserve(_ value: Double, for userId: String) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func getMinimumCashReserve(for userId: String) -> Double {
        return queue.sync {
            configuration.userMinimumCashReserves[userId] ?? configuration.minimumCashReserve
        }
    }

    func updateInitialAccountBalance(_ value: Double) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func updatePoolBalanceDistributionStrategy(_ strategy: PoolBalanceDistributionStrategy) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func updatePoolBalanceDistributionThreshold(_ threshold: Double) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func updateTraderCommissionRate(_ rate: Double) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }
}
