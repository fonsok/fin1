import Foundation
import Combine
@testable import FIN1

/// Shared mock for ConfigurationServiceProtocol (e.g. CompletedInvestmentsViewModel, InvestmentsViewModel tests).
final class MockConfigurationService: ConfigurationServiceProtocol {
    var minimumCashReserve: Double = 12.0
    var initialAccountBalance: Double = 50_000.0
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy = .immediateDistribution
    var poolBalanceDistributionThreshold: Double = 5.0
    var traderCommissionRate: Double = 0.10
    var platformServiceChargeRate: Double = 0.015
    var isAdminMode: Bool = false
    var showCommissionBreakdownInCreditNote: Bool = true
    var slaMonitoringInterval: TimeInterval = 300.0
    var parseServerURL: String?
    var parseApplicationId: String?
    var parseLiveQueryURL: String?

    func updateMinimumCashReserve(_ value: Double) async throws { minimumCashReserve = value }
    func updateMinimumCashReserve(_ value: Double, for userId: String) async throws { minimumCashReserve = value }
    func getMinimumCashReserve(for userId: String) -> Double { minimumCashReserve }
    func updateInitialAccountBalance(_ value: Double) async throws { initialAccountBalance = value }
    func updatePoolBalanceDistributionStrategy(_ strategy: PoolBalanceDistributionStrategy) async throws {
        poolBalanceDistributionStrategy = strategy
    }
    func updatePoolBalanceDistributionThreshold(_ threshold: Double) async throws {
        poolBalanceDistributionThreshold = threshold
    }
    func updateTraderCommissionRate(_ rate: Double) async throws { traderCommissionRate = rate }
    func updateShowCommissionBreakdownInCreditNote(_ value: Bool) async throws { showCommissionBreakdownInCreditNote = value }
    func updatePlatformServiceChargeRate(_ rate: Double) async throws { platformServiceChargeRate = rate }
    func updateSLAMonitoringInterval(_ interval: TimeInterval) async throws { slaMonitoringInterval = interval }
    func resetToDefaults() async throws {}
    func validateMinimumCashReserve(_ value: Double) -> Bool { value >= 0 }
    func validateInitialAccountBalance(_ value: Double) -> Bool { value >= 0 }
    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool { value >= 0 }
    func validateTraderCommissionRate(_ rate: Double) -> Bool { rate >= 0 && rate <= 1 }
    func validatePlatformServiceChargeRate(_ rate: Double) -> Bool { rate >= 0 && rate <= 1 }
    func validateSLAMonitoringInterval(_ interval: TimeInterval) -> Bool { interval > 0 }
}
