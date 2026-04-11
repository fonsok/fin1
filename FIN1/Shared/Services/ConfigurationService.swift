import Foundation
@preconcurrency import Dispatch
import Combine

// MARK: - Configuration Service Implementation
/// Manages application configuration settings with admin controls
/// Note: Safe to use with DispatchQueue.async closures due to [weak self] capture pattern
final class ConfigurationService: ConfigurationServiceProtocol, ServiceLifecycle {

    // MARK: - Change Publisher
    lazy var configurationChanged: AnyPublisher<Void, Never> = {
        objectWillChange.map { _ in () }.eraseToAnyPublisher()
    }()

    // MARK: - Published Properties
    @Published var minimumCashReserve: Double = 20.0
    @Published var initialAccountBalance: Double = 0.0
    @Published var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy = .immediateDistribution // internal(set) for extension access
    @Published var poolBalanceDistributionThreshold: Double = 5.0 // internal(set) for extension access
    @Published var traderCommissionRate: Double = 0.10 // internal(set) for extension access
    @Published var appServiceChargeRate: Double = 0.02 // internal(set) for extension access
    @Published var showCommissionBreakdownInCreditNote: Bool = true // internal(set) for extension access
    @Published var maximumRiskExposurePercent: Double = 2.0 // internal(set) for extension access
    @Published var walletFeatureEnabled: Bool = false // internal(set) for extension access
    @Published var slaMonitoringInterval: TimeInterval = 300.0 // 5 minutes default, internal(set) for extension access
    @Published private(set) var isAdminMode: Bool = false

    // MARK: - Parse Server Configuration
    var parseServerURL: String? {
        // Priority:
        // 1) Info.plist override (works on iOS devices)
        // 2) Environment variable (useful for local dev/tests)
        // 3) FIN1 server default (behind nginx on port 80)
        var resolved: String?

        if let value = Bundle.main.object(forInfoDictionaryKey: "FIN1ParseServerURL") as? String,
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved = value
        }

        if let value = ProcessInfo.processInfo.environment["PARSE_SERVER_URL"],
           !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolved = value
        }

        if resolved == nil {
            resolved = "https://192.168.178.20/parse"
        }

        // Simulator: use `FIN1_PARSE_SERVER_URL` from xcconfig (direct LAN HTTP recommended in FIN1-Dev).
        // Optional SSH tunnel: set launch env `PARSE_SERVER_URL=https://localhost:8443/parse` when using
        // `ssh -L 8443:127.0.0.1:443 user@host`.

        return resolved
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
        setupRemoteConfigRefreshOnSignIn()
    }

    /// Injects Parse API client for fetching/saving config from Parse (getConfig / updateConfig).
    func configureParseAPIClient(_ client: (any ParseAPIClientProtocol)?) {
        queue.sync(flags: .barrier) { [weak self] in
            self?.parseAPIClient = client
        }
        Task { [weak self] in
            await self?.fetchRemoteDisplayConfig()
        }
    }

    /// After sign-in, financial parameters must match the authenticated session / server (not cold-start defaults).
    private func setupRemoteConfigRefreshOnSignIn() {
        NotificationCenter.default.publisher(for: .userDidSignIn)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.fetchRemoteDisplayConfig() }
            }
            .store(in: &cancellables)
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
        return value >= 0.01 && value <= 1000.0
    }

    func validateInitialAccountBalance(_ value: Double) -> Bool {
        value >= 0.0 && value <= 1_000_000.0
    }

    func validatePoolBalanceDistributionThreshold(_ value: Double) -> Bool {
        return value >= 1.0 && value <= 100.0
    }

    func validateTraderCommissionRate(_ rate: Double) -> Bool {
        return rate >= 0.0 && rate <= 1.0 // 0% to 100%
    }

    func validateAppServiceChargeRate(_ rate: Double) -> Bool {
        return rate >= 0.0 && rate <= 0.1 // 0% to 10% (reasonable limit for service charges)
    }

    func validateSLAMonitoringInterval(_ interval: TimeInterval) -> Bool {
        return interval >= 60.0 && interval <= 3600.0 // 1 minute to 1 hour
    }

    func validateMaximumRiskExposurePercent(_ value: Double) -> Bool {
        return value >= 0.0 && value <= 100.0
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
                // Backward compatibility: if appServiceChargeRate is nil (missing from old config), set it to default
                if self.configuration.appServiceChargeRate == nil {
                    self.configuration.appServiceChargeRate = CalculationConstants.ServiceCharges.appServiceChargeRate
                }
                // Backward compatibility: if slaMonitoringInterval is 0 (missing from old config), set it to default
                if self.configuration.slaMonitoringInterval == 0 {
                    self.configuration.slaMonitoringInterval = 300.0
                }
                // Backward compatibility: if showCommissionBreakdownInCreditNote is nil (missing from old config), set to true
                if self.configuration.showCommissionBreakdownInCreditNote == nil {
                    self.configuration.showCommissionBreakdownInCreditNote = true
                }
                // Backward compatibility: if maximumRiskExposurePercent is nil (missing from old config), set to 2.0
                if self.configuration.maximumRiskExposurePercent == nil {
                    self.configuration.maximumRiskExposurePercent = 2.0
                }
                // Backward compatibility: if walletFeatureEnabled is nil, set to false
                if self.configuration.walletFeatureEnabled == nil {
                    self.configuration.walletFeatureEnabled = false
                }
                // Save updated config with new fields if needed
                if self.configuration.traderCommissionRate == nil || self.configuration.appServiceChargeRate == nil || self.configuration.slaMonitoringInterval == 0 || self.configuration.showCommissionBreakdownInCreditNote == nil || self.configuration.maximumRiskExposurePercent == nil || self.configuration.walletFeatureEnabled == nil {
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
        appServiceChargeRate = configuration.effectiveAppServiceChargeRate
        showCommissionBreakdownInCreditNote = configuration.showCommissionBreakdownInCreditNote ?? true
        maximumRiskExposurePercent = configuration.effectiveMaximumRiskExposurePercent
        walletFeatureEnabled = configuration.effectiveWalletFeatureEnabled
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

    /// Fetches full config from Parse (getConfig) and merges into local configuration.
    /// This syncs financial parameters (initialAccountBalance, commissionRate, etc.)
    /// and display settings from the server's authoritative Configuration.
    func fetchRemoteDisplayConfig() async {
        let client: (any ParseAPIClientProtocol)? = queue.sync { parseAPIClient }
        guard let client = client else { return }
        do {
            let response: GetConfigResponse = try await client.callFunction(
                "getConfig",
                parameters: ["environment": "production"]
            )
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else { return }
                var changed = false

                if let f = response.financial {
                    let initial = f.initialAccountBalance ?? 0.0
                    if self.configuration.initialAccountBalance != initial {
                        self.configuration.initialAccountBalance = initial
                        changed = true
                    }
                    if let v = f.traderCommissionRate {
                        self.configuration.traderCommissionRate = v
                        changed = true
                    }
                    if let v = f.appServiceChargeRate ?? f.platformServiceChargeRate {
                        self.configuration.appServiceChargeRate = v
                        changed = true
                    }
                    if let v = f.minimumCashReserve {
                        self.configuration.minimumCashReserve = v
                        changed = true
                    }
                }
                if let v = response.display?.showCommissionBreakdownInCreditNote {
                    self.configuration.showCommissionBreakdownInCreditNote = v
                    changed = true
                }
                if let v = response.display?.maximumRiskExposurePercent {
                    self.configuration.maximumRiskExposurePercent = v
                    changed = true
                }
                if let v = response.display?.walletFeatureEnabled {
                    self.configuration.walletFeatureEnabled = v
                    changed = true
                }

                if changed {
                    self.saveConfiguration()
                    Task { @MainActor in
                        self.updatePublishedValues()
                    }
                }
            }
        } catch {
            print("⚠️ ConfigurationService: Failed to fetch remote config: \(error.localizedDescription)")
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
    let financial: FinancialSection?
    let display: DisplaySection?

    struct FinancialSection: Decodable {
        let initialAccountBalance: Double?
        let traderCommissionRate: Double?
        let platformServiceChargeRate: Double?
        let appServiceChargeRate: Double?
        let minimumCashReserve: Double?
    }
    struct DisplaySection: Decodable {
        let showCommissionBreakdownInCreditNote: Bool?
        let maximumRiskExposurePercent: Double?
        let walletFeatureEnabled: Bool?
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
    case appServiceChargeRate
    case initialAccountBalance
    case orderFeeRate
    case orderFeeMin
    case orderFeeMax

    var displayName: String {
        switch self {
        case .traderCommissionRate: return "Trader Commission Rate"
        case .appServiceChargeRate: return "App Service Charge Rate"
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
