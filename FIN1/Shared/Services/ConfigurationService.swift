import Foundation
@preconcurrency import Dispatch
import Combine

// MARK: - Configuration Service Implementation
/// Manages application configuration settings with admin controls
/// Note: Safe to use with DispatchQueue.async closures due to [weak self] capture pattern
/// @unchecked Sendable: Safe because we use [weak self] in all async closures and proper queue synchronization
final class ConfigurationService: ConfigurationServiceProtocol, ServiceLifecycle, @unchecked Sendable {

    // MARK: - Published Properties
    @Published private(set) var minimumCashReserve: Double = 12.0
    @Published private(set) var initialAccountBalance: Double = 50000.0
    @Published private(set) var poolBalanceDistributionStrategy: PoolBalanceDistributionStrategy = .immediateDistribution
    @Published private(set) var poolBalanceDistributionThreshold: Double = 5.0
    @Published private(set) var traderCommissionRate: Double = 0.05
    @Published private(set) var slaMonitoringInterval: TimeInterval = 300.0 // 5 minutes default
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
    private var configuration: AppConfiguration = .default
    private let userService: any UserServiceProtocol
    private let queue = DispatchQueue(label: "com.fin.app.configuration", attributes: .concurrent)
    private let configurationKey = "FIN1_AppConfiguration"

    // MARK: - Initialization
    init(userService: any UserServiceProtocol) {
        self.userService = userService
        loadConfiguration()
        setupUserRoleObservation()
    }

    // MARK: - ServiceLifecycle
    func start() {
        loadConfiguration()
        // Update admin mode status when service starts
        updateAdminModeStatus()
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
    func updateMinimumCashReserve(_ value: Double) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validateMinimumCashReserve(value) else {
            throw ConfigurationError.invalidValue("Minimum cash reserve must be between 1.0 and 1000.0")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.minimumCashReserve = value
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.minimumCashReserve = value
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func updateMinimumCashReserve(_ value: Double, for userId: String) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validateMinimumCashReserve(value) else {
            throw ConfigurationError.invalidValue("Minimum cash reserve must be between 1.0 and 1000.0")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.userMinimumCashReserves[userId] = value
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func getMinimumCashReserve(for userId: String) -> Double {
        return queue.sync {
            // Return user-specific value if exists, otherwise return global default
            return configuration.userMinimumCashReserves[userId] ?? configuration.minimumCashReserve
        }
    }

    func updateInitialAccountBalance(_ value: Double) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validateInitialAccountBalance(value) else {
            throw ConfigurationError.invalidValue("Initial account balance must be between 1000.0 and 1000000.0")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.initialAccountBalance = value
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.initialAccountBalance = value
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func updatePoolBalanceDistributionStrategy(_ strategy: PoolBalanceDistributionStrategy) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.poolBalanceDistributionStrategy = strategy
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.poolBalanceDistributionStrategy = strategy
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func updatePoolBalanceDistributionThreshold(_ threshold: Double) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validatePoolBalanceDistributionThreshold(threshold) else {
            throw ConfigurationError.invalidValue("Pool balance distribution threshold must be between 1.0 and 100.0")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.poolBalanceDistributionThreshold = threshold
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.poolBalanceDistributionThreshold = threshold
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func updateTraderCommissionRate(_ rate: Double) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validateTraderCommissionRate(rate) else {
            throw ConfigurationError.invalidValue("Trader commission rate must be between 0.0 (0%) and 1.0 (100%)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.traderCommissionRate = rate // Now stored as non-optional
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.traderCommissionRate = rate
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func updateSLAMonitoringInterval(_ interval: TimeInterval) async throws {
        // Check admin or CSR role
        guard let userRole = userService.currentUser?.role,
              userRole == .admin || userRole == .customerService else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validateSLAMonitoringInterval(interval) else {
            throw ConfigurationError.invalidValue("SLA monitoring interval must be between 60 seconds (1 minute) and 3600 seconds (1 hour)")
        }

        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.slaMonitoringInterval = interval
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.slaMonitoringInterval = interval
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func resetToDefaults() async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration = .default
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.updatePublishedValues()
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

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

    func validateSLAMonitoringInterval(_ interval: TimeInterval) -> Bool {
        return interval >= 60.0 && interval <= 3600.0 // 1 minute to 1 hour
    }

    // MARK: - Private Methods
    private func loadConfiguration() {
        queue.async { [weak self] in
            guard let self = self else { return }

            if let data = UserDefaults.standard.data(forKey: self.configurationKey),
               let config = try? JSONDecoder().decode(AppConfiguration.self, from: data) {
                self.configuration = config
                // Backward compatibility: if traderCommissionRate is nil (missing from old config), set it to default
                if self.configuration.traderCommissionRate == nil {
                    self.configuration.traderCommissionRate = CalculationConstants.FeeRates.traderCommissionRate
                }
                // Backward compatibility: if slaMonitoringInterval is 0 (missing from old config), set it to default
                if self.configuration.slaMonitoringInterval == 0 {
                    self.configuration.slaMonitoringInterval = 300.0
                }
                // Save updated config with new fields if needed
                if self.configuration.traderCommissionRate == nil || self.configuration.slaMonitoringInterval == 0 {
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

    private func saveConfiguration() {
        queue.async { [weak self] in
            guard let self = self else { return }

            if let data = try? JSONEncoder().encode(self.configuration) {
                UserDefaults.standard.set(data, forKey: self.configurationKey)
            }
        }
    }

    private func updatePublishedValues() {
        minimumCashReserve = configuration.minimumCashReserve
        initialAccountBalance = configuration.initialAccountBalance
        poolBalanceDistributionStrategy = configuration.poolBalanceDistributionStrategy
        poolBalanceDistributionThreshold = configuration.poolBalanceDistributionThreshold
        traderCommissionRate = configuration.effectiveTraderCommissionRate
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

    private var cancellables = Set<AnyCancellable>()
}
