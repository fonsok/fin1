import Foundation
@preconcurrency import Dispatch
import Combine

// MARK: - Configuration Service Implementation
/// Manages application configuration settings with admin controls
/// Note: Safe to use with DispatchQueue.async closures due to [weak self] capture pattern
/// @unchecked Sendable: Safe because we use [weak self] in all async closures and proper queue synchronization
final class ConfigurationService: ConfigurationServiceProtocol, ServiceLifecycle, @unchecked Sendable {

    // MARK: - Published Properties
    @Published var minimumCashReserve: Double = 12.0 // internal(set) for extension access
    @Published var initialAccountBalance: Double = 50000.0 // internal(set) for extension access
    @Published var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy = .immediateDistribution // internal(set) for extension access
    @Published var poolBalanceDistributionThreshold: Double = 5.0 // internal(set) for extension access
    @Published var traderCommissionRate: Double = 0.05 // internal(set) for extension access
    @Published var platformServiceChargeRate: Double = 0.015 // internal(set) for extension access
    @Published var showCommissionBreakdownInCreditNote: Bool = true // internal(set) for extension access
    @Published var slaMonitoringInterval: TimeInterval = 300.0 // 5 minutes default, internal(set) for extension access
    @Published private(set) var isAdminMode: Bool = false

    // MARK: - Parse Server Configuration
    var parseServerURL: String? {
        // Priority:
        // 1) Info.plist override (works on iOS devices)
        // 2) Environment variable (useful for local dev/tests)
        // 3) FIN1 server default (behind nginx on port 80)
        if let value = Bundle.main.object(forInfoDictionaryKey: "FIN1ParseServerURL") as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        if let value = ProcessInfo.processInfo.environment["PARSE_SERVER_URL"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        return "http://192.168.178.24/parse"
    }

    var parseApplicationId: String? {
        // Priority:
        // 1) Info.plist (recommended via .xcconfig)
        // 2) Environment variable (useful for local dev/tests)
        // 3) Default
        if let value = Bundle.main.object(forInfoDictionaryKey: "FIN1ParseApplicationId") as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        if let value = ProcessInfo.processInfo.environment["PARSE_APPLICATION_ID"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return value
        }
        return "fin1-app-id"
    }

    var parseLiveQueryURL: String? {
        // Convert http/https to ws/wss for Live Query
        guard let serverURL = parseServerURL else { return nil }
        return serverURL
            .replacingOccurrences(of: "http://", with: "ws://")
            .replacingOccurrences(of: "https://", with: "wss://")
    }

    // MARK: - Private Properties
    var configuration: AppConfiguration = .default // internal for extension access
    let userService: any UserServiceProtocol // internal for extension access
    let queue = DispatchQueue(label: "com.fin.app.configuration", attributes: .concurrent) // internal for extension access
    private let configurationKey = "FIN1_AppConfiguration"
    private var parseAPIClient: (any ParseAPIClientProtocol)?

    // MARK: - Initialization
    init(userService: any UserServiceProtocol) {
        self.userService = userService
        loadConfiguration()
        setupUserRoleObservation()
    }

    /// Injects Parse API client for fetching/saving config from Parse (getConfig / updateConfig).
    func configureParseAPIClient(_ client: (any ParseAPIClientProtocol)?) {
        queue.async(flags: .barrier) { [weak self] in
            self?.parseAPIClient = client
        }
    }

    // MARK: - ServiceLifecycle
    func start() {
        loadConfiguration()
        // Update admin mode status when service starts
        updateAdminModeStatus()
        // Merge display settings from Parse if available
        Task { await fetchRemoteDisplayConfig() }
    }

    func stop() {
        // Configuration service doesn't need cleanup
    }

    func reset() {
        configuration = .default
        updatePublishedValues()
        saveConfiguration()
    }

    // MARK: - Configuration Management
    // Note: Update methods are in ConfigurationService+Updates.swift extension

    // MARK: - Validation
    func validateMinimumCashReserve(_ value: Double) -> Bool {
        return value >= 1.0 && value <= 1000.0
    }

    func validateInitialAccountBalance(_ value: Double) -> Bool {
        return value >= 1000.0 && value <= 1000000.0
    }

    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool {
        return value >= 1.0 && value <= 100.0
    }

    func validateTraderCommissionRate(_ rate: Double) -> Bool {
        return rate >= 0.0 && rate <= 1.0 // 0% to 100%
    }

    func validatePlatformServiceChargeRate(_ rate: Double) -> Bool {
        return rate >= 0.0 && rate <= 0.1 // 0% to 10% (reasonable limit for service charges)
    }

    func validateSLAMonitoringInterval(_ interval: TimeInterval) -> Bool {
        return interval >= 60.0 && interval <= 3600.0 // 1 minute to 1 hour
    }

    // MARK: - Private Methods
    func loadConfiguration() { // internal for extension access
        queue.async { [weak self] in
            guard let self = self else { return }

            if let data = UserDefaults.standard.data(forKey: self.configurationKey),
               let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
                self.configuration = config
                // Backward compatibility: if traderCommissionRate is nil (missing from old config), set it to default
                if self.configuration.traderCommissionRate == nil {
                    self.configuration.traderCommissionRate = CalculationConstants.FeeRates.traderCommissionRate
                }
                // Backward compatibility: if platformServiceChargeRate is nil (missing from old config), set it to default
                if self.configuration.platformServiceChargeRate == nil {
                    self.configuration.platformServiceChargeRate = CalculationConstants.ServiceCharges.platformServiceChargeRate
                }
                // Backward compatibility: if slaMonitoringInterval is 0 (missing from old config), set it to default
                if self.configuration.slaMonitoringInterval == 0 {
                    self.configuration.slaMonitoringInterval = 300.0
                }
                // Backward compatibility: if showCommissionBreakdownInCreditNote is nil (missing from old config), set to true
                if self.configuration.showCommissionBreakdownInCreditNote == nil {
                    self.configuration.showCommissionBreakdownInCreditNote = true
                }
                // Save updated config with new fields if needed
                if self.configuration.traderCommissionRate == nil || self.configuration.platformServiceChargeRate == nil || self.configuration.slaMonitoringInterval == 0 || self.configuration.showCommissionBreakdownInCreditNote == nil {
                    self.saveConfiguration()
                }
            } else {
                self.configuration = .default
                self.saveConfiguration()
            }

            Task { @MainActor in
                self.updatePublishedValues()
            }
        }
    }

    func saveConfiguration() { // internal for extension access
        queue.async { [weak self] in
            guard let self = self else { return }

            if let data = try? JSONEncoder().encode(self.configuration) {
                UserDefaults.standard.set(data, forKey: self.configurationKey)
            }
        }
    }

    func updatePublishedValues() { // internal for extension access
        minimumCashReserve = configuration.minimumCashReserve
        initialAccountBalance = configuration.initialAccountBalance
        poolBalanceDistributionStrategy = configuration.poolBalanceDistributionStrategy
        poolBalanceDistributionThreshold = configuration.poolBalanceDistributionThreshold
        traderCommissionRate = configuration.effectiveTraderCommissionRate
        platformServiceChargeRate = configuration.effectivePlatformServiceChargeRate
        showCommissionBreakdownInCreditNote = configuration.showCommissionBreakdownInCreditNote ?? true
        slaMonitoringInterval = configuration.slaMonitoringInterval
    }

    private func setupUserRoleObservation() {
        // Update admin mode status initially
        updateAdminModeStatus()
    }

    /// Updates the isAdminMode property based on current user role
    private func updateAdminModeStatus() {
        Task { @MainActor [weak self] in
            self?.isAdminMode = self?.userService.currentUser?.role == .admin
        }
    }

    /// Fetches display config from Parse (getConfig) and merges into local configuration.
    func fetchRemoteDisplayConfig() async {
        let client: (any ParseAPIClientProtocol)? = queue.sync { parseAPIClient }
        guard let client = client else { return }
        do {
            let response: GetConfigResponse = try await client.callFunction(
                "getConfig",
                parameters: ["environment": "production"]
            )
            if let value = response.display?.showCommissionBreakdownInCreditNote {
                queue.async(flags: .barrier) { [weak self] in
                    guard let self = self else { return }
                    self.configuration.showCommissionBreakdownInCreditNote = value
                    self.saveConfiguration()
                    Task { @MainActor in
                        self.updatePublishedValues()
                    }
                }
            }
        } catch {
            // No session or network error: keep local config
        }
    }

    /// Returns the current Parse API client (for updateConfig in extension). Thread-safe read.
    func getParseAPIClient() -> (any ParseAPIClientProtocol)? {
        queue.sync { parseAPIClient }
    }

    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Parse config API responses (internal for use in ConfigurationService+Updates)
struct GetConfigResponse: Decodable {
    let display: DisplaySection?
    struct DisplaySection: Decodable {
        let showCommissionBreakdownInCreditNote: Bool?
    }
}

struct UpdateConfigResponse: Decodable {
    let display: GetConfigResponse.DisplaySection?
}

// MARK: - 4-Eyes Configuration Change Response Models

/// Response from requestConfigurationChange Cloud Function
struct ConfigurationChangeRequestResponse: Decodable {
    let success: Bool
    let requiresApproval: Bool
    let fourEyesRequestId: String?
    let message: String
}

/// Response from approveConfigurationChange Cloud Function
struct ConfigurationChangeApprovalResponse: Decodable {
    let success: Bool
    let message: String
    let appliedValue: Double?
}

/// Pending configuration change request
struct PendingConfigurationChange: Decodable, Identifiable {
    let id: String
    let parameterName: String
    let oldValue: Double
    let newValue: Double
    let reason: String
    let requesterId: String
    let requesterEmail: String?
    let requesterRole: String
    let createdAt: Date
    let expiresAt: Date
}

/// Response from getPendingConfigurationChanges Cloud Function
struct PendingConfigurationChangesResponse: Decodable {
    let requests: [PendingConfigurationChange]
    let total: Int
}

// MARK: - Critical Parameters Definition
/// Parameters that require 4-eyes approval for changes
enum CriticalConfigurationParameter: String, CaseIterable {
    case traderCommissionRate
    case platformServiceChargeRate
    case initialAccountBalance
    case orderFeeRate
    case orderFeeMin
    case orderFeeMax

    var displayName: String {
        switch self {
        case .traderCommissionRate: return "Trader Commission Rate"
        case .platformServiceChargeRate: return "Platform Service Charge Rate"
        case .initialAccountBalance: return "Initial Account Balance"
        case .orderFeeRate: return "Order Fee Rate"
        case .orderFeeMin: return "Order Fee Minimum"
        case .orderFeeMax: return "Order Fee Maximum"
        }
    }

    static func isCritical(_ parameterName: String) -> Bool {
        return CriticalConfigurationParameter(rawValue: parameterName) != nil
    }
}
