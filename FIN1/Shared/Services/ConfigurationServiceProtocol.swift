import Foundation
import Combine

// MARK: - Pool Balance Distribution Strategy

/// Strategy for handling small remaining pool balances after purchases
enum PoolBalanceDistributionStrategy: String, Codable, CaseIterable {
    case immediateDistribution = "immediate"
    case accumulateUntilThreshold = "accumulate"

    var displayName: String {
        switch self {
        case .immediateDistribution:
            return "Immediate Distribution"
        case .accumulateUntilThreshold:
            return "Accumulate Until Threshold"
        }
    }

    var description: String {
        switch self {
        case .immediateDistribution:
            return "Distribute remaining balance immediately if below threshold"
        case .accumulateUntilThreshold:
            return "Keep small remainders until threshold is reached, then distribute"
        }
    }
}

// MARK: - Configuration Service Protocol
/// Defines the contract for application configuration management
protocol ConfigurationServiceProtocol: ObservableObject, Sendable {
    /// Publisher that fires when any configuration value changes.
    /// Use this instead of `objectWillChange` when holding `any ConfigurationServiceProtocol`.
    var configurationChanged: AnyPublisher<Void, Never> { get }

    var minimumCashReserve: Double { get }
    var initialAccountBalance: Double { get }
    var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy { get }
    var poolBalanceDistributionThreshold: Double { get }
    var traderCommissionRate: Double { get }
    var traderCommissionPercentage: String { get }
    var appServiceChargeRate: Double { get }
    var appServiceChargeRateCompanies: Double { get }
    var appServiceChargePercentage: String { get }

    /// Single source of truth for commission rate with fallback to default
    /// Use this instead of manually checking `traderCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate`
    var effectiveCommissionRate: Double { get }

    /// Single source of truth for app service charge rate with fallback to default
    /// Use this instead of manually checking `appServiceChargeRate ?? CalculationConstants.ServiceCharges.appServiceChargeRate`
    var effectiveAppServiceChargeRate: Double { get }
    func effectiveAppServiceChargeRate(for accountTypeRaw: String?) -> Double

    /// Admin-configurable daily transaction limit (EUR), independent of risk class.
    /// Source of truth is the backend Configuration; CalculationConstants is fallback only.
    var dailyTransactionLimit: Double { get }

    /// Admin-configurable weekly transaction limit (EUR), independent of risk class.
    var weeklyTransactionLimit: Double { get }

    /// Admin-configurable monthly transaction limit (EUR), independent of risk class.
    var monthlyTransactionLimit: Double { get }

    /// Minimum capital per investment slot (EUR) from `getConfig` / admin limits.
    var minimumInvestmentAmount: Double { get }

    /// Maximum capital per investment slot (EUR) from `getConfig` / admin limits.
    var maximumInvestmentAmount: Double { get }

    var isAdminMode: Bool { get }

    /// Wenn true, wird die Commission-Breakdown-Tabelle in der Trader-Gutschrift angezeigt (Admin-Option).
    var showCommissionBreakdownInCreditNote: Bool { get }
    /// Wenn true, sind Belegnummern im Kontoauszug klickbar und öffnen den referenzierten Beleg.
    var showDocumentReferenceLinksInAccountStatement: Bool { get }

    /// Maximum recommended risk exposure as percentage of assets (e.g. 2.0 = 2%). Shown on dashboard.
    var maximumRiskExposurePercent: Double { get }

    /// Legacy key name; semantics now: controls only account actions (deposit/withdraw).
    /// Kontoansicht (Balance + Historie) stays available regardless of this flag.
    var walletFeatureEnabled: Bool { get }

    /// ADR-007 Phase-2 migration flag.
    /// When `true`, the iOS client stops writing the App-Service-Charge `Invoice` locally and
    /// instead invokes the `bookAppServiceCharge` Cloud function. The server-side path is
    /// idempotent (batch-level) and the server-side `afterSave Invoice` trigger continues to
    /// book the BankContra and AppLedger entries. Default `false` for safe rollout.
    var serviceChargeInvoiceFromBackend: Bool { get }
    /// Stability guard: when `false`, iOS must not use the legacy client fallback write path.
    var serviceChargeLegacyClientFallbackEnabled: Bool { get }

    // MARK: - Customer Support Configuration
    var slaMonitoringInterval: TimeInterval { get }

    // MARK: - Parse Server Configuration
    var parseServerURL: String? { get }
    var parseApplicationId: String? { get }
    var parseLiveQueryURL: String? { get }

    // MARK: - Configuration Management
    func updateMinimumCashReserve(_ value: Double) async throws
    func updateMinimumCashReserve(_ value: Double, for userId: String) async throws
    func getMinimumCashReserve(for userId: String) -> Double
    func updateInitialAccountBalance(_ value: Double) async throws
    func updatePoolBalanceDistributionStrategy(_ strategy: PoolBalanceDistributionStrategy) async throws
    func updatePoolBalanceDistributionThreshold(_ threshold: Double) async throws
    func updateTraderCommissionRate(_ rate: Double) async throws
    func updateShowCommissionBreakdownInCreditNote(_ value: Bool) async throws
    func updateShowDocumentReferenceLinksInAccountStatement(_ value: Bool) async throws
    func updateMaximumRiskExposurePercent(_ value: Double) async throws
    func updateAppServiceChargeRate(_ rate: Double) async throws
    func updateSLAMonitoringInterval(_ interval: TimeInterval) async throws
    func resetToDefaults() async throws
    func getPendingConfigurationChanges() async throws -> [PendingConfigurationChange]
    func approveConfigurationChange(requestId: String, notes: String?) async throws
    func rejectConfigurationChange(requestId: String, reason: String) async throws

    // MARK: - Validation
    func validateMinimumCashReserve(_ value: Double) -> Bool
    func validateInitialAccountBalance(_ value: Double) -> Bool
    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool
    func validateTraderCommissionRate(_ rate: Double) -> Bool
    func validateMaximumRiskExposurePercent(_ value: Double) -> Bool
    func validateAppServiceChargeRate(_ rate: Double) -> Bool
    func validateSLAMonitoringInterval(_ interval: TimeInterval) -> Bool

    // MARK: - Remote configuration (investing / compliance)
    /// Fetches latest `getConfig` from the server so limits and fees match the backend before financial actions (best-effort).
    func refreshConfigurationFromServerIfAvailable() async
}
