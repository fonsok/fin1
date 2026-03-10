import Foundation
@preconcurrency import Dispatch

// MARK: - ConfigurationService Update Methods Extension
/// Update methods for ConfigurationService
/// Extracted to separate file to keep ConfigurationService.swift under 400 lines
extension ConfigurationService {

    // MARK: - 4-Eyes Backend Integration

    /// Request a configuration change via backend.
    /// For critical parameters, this creates a 4-eyes request requiring approval.
    func requestConfigurationChangeViaBackend(
        client: any ParseAPIClientProtocol,
        parameterName: String,
        newValue: Double,
        reason: String
    ) async throws -> ConfigurationChangeRequestResponse {
        let response: ConfigurationChangeRequestResponse = try await client.callFunction(
            "requestConfigurationChange",
            parameters: [
                "parameterName": parameterName,
                "newValue": newValue,
                "reason": reason
            ]
        )
        return response
    }

    /// Get pending configuration change requests that need approval.
    func getPendingConfigurationChanges() async throws -> [PendingConfigurationChange] {
        guard let client = getParseAPIClient() else {
            throw ConfigurationError.noBackendConnection
        }

        let response: PendingConfigurationChangesResponse = try await client.callFunction(
            "getPendingConfigurationChanges",
            parameters: [:]
        )
        return response.requests
    }

    /// Approve a pending configuration change.
    func approveConfigurationChange(requestId: String, notes: String?) async throws {
        guard let client = getParseAPIClient() else {
            throw ConfigurationError.noBackendConnection
        }

        var params: [String: Any] = ["requestId": requestId]
        if let notes = notes {
            params["notes"] = notes
        }

        let _: ConfigurationChangeApprovalResponse = try await client.callFunction(
            "approveConfigurationChange",
            parameters: params
        )

        // Refresh local configuration after approval
        await fetchRemoteDisplayConfig()
    }

    /// Reject a pending configuration change.
    func rejectConfigurationChange(requestId: String, reason: String) async throws {
        guard let client = getParseAPIClient() else {
            throw ConfigurationError.noBackendConnection
        }

        let _: ConfigurationChangeApprovalResponse = try await client.callFunction(
            "rejectConfigurationChange",
            parameters: [
                "requestId": requestId,
                "reason": reason
            ]
        )
    }

    // MARK: - Configuration Management

    func updateMinimumCashReserve(_ value: Double) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validateMinimumCashReserve(value) else {
            throw ConfigurationError.invalidValue("Minimum cash reserve must be between 0.01 and 1000.0")
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
            throw ConfigurationError.invalidValue("Minimum cash reserve must be between 0.01 and 1000.0")
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

    /// Update initial account balance for new users.
    /// IMPORTANT: This is a critical parameter and requires 4-eyes approval via backend.
    func updateInitialAccountBalance(_ value: Double) async throws {
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }
        guard validateInitialAccountBalance(value) else {
            throw ConfigurationError.invalidValue("Initial account balance must be between 0.01 and 1000000.0")
        }
        if let client = getParseAPIClient() {
            let response = try await requestConfigurationChangeViaBackend(
                client: client,
                parameterName: "initialAccountBalance",
                newValue: value,
                reason: "Admin configuration update"
            )
            if response.requiresApproval {
                throw ConfigurationError.fourEyesApprovalRequired(requestId: response.fourEyesRequestId ?? "unknown")
            }
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
                Task { @MainActor in self.initialAccountBalance = value }
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

    /// Update trader commission rate.
    /// IMPORTANT: This is a critical parameter and requires 4-eyes approval via backend.
    /// The local update is optimistic - the actual change is applied after backend approval.
    func updateTraderCommissionRate(_ rate: Double) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validateTraderCommissionRate(rate) else {
            throw ConfigurationError.invalidValue("Trader commission rate must be between 0.0 (0%) and 1.0 (100%)")
        }

        // Try to request change via backend (4-eyes for critical parameters)
        if let client = getParseAPIClient() {
            let response = try await requestConfigurationChangeViaBackend(
                client: client,
                parameterName: "traderCommissionRate",
                newValue: rate,
                reason: "Admin configuration update"
            )

            if response.requiresApproval {
                // 4-eyes approval required - don't apply locally yet
                print("⏳ Trader commission rate change requires 4-eyes approval. Request ID: \(response.fourEyesRequestId ?? "unknown")")
                throw ConfigurationError.fourEyesApprovalRequired(requestId: response.fourEyesRequestId ?? "unknown")
            }
        }

        // Apply locally (either non-critical or backend approved immediately)
        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.traderCommissionRate = rate
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

    func updateShowCommissionBreakdownInCreditNote(_ value: Bool) async throws {
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.showCommissionBreakdownInCreditNote = value
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.showCommissionBreakdownInCreditNote = value
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }

        // Persist to Parse when API client is available (admin-only Cloud Function)
        if let client = getParseAPIClient() {
            do {
                let _: UpdateConfigResponse = try await client.callFunction(
                    "updateConfig",
                    parameters: [
                        "environment": "production",
                        "display": ["showCommissionBreakdownInCreditNote": value]
                    ]
                )
            } catch {
                // Local save already applied; Parse persistence optional (e.g. no session yet)
            }
        }
    }

    /// Update maximum risk exposure percent (dashboard disclaimer, 0–100%).
    func updateMaximumRiskExposurePercent(_ value: Double) async throws {
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validateMaximumRiskExposurePercent(value) else {
            throw ConfigurationError.invalidValue("Maximum risk exposure percent must be between 0 and 100")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.maximumRiskExposurePercent = value
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.maximumRiskExposurePercent = value
                }

                self.saveConfiguration()
                continuation.resume()
            }
        }

        if let client = getParseAPIClient() {
            do {
                let _: UpdateConfigResponse = try await client.callFunction(
                    "updateConfig",
                    parameters: [
                        "environment": "production",
                        "display": ["maximumRiskExposurePercent": value]
                    ]
                )
            } catch {
                // Local save already applied; Parse persistence optional
            }
        }
    }

    /// Update platform service charge rate.
    /// IMPORTANT: This is a critical parameter and requires 4-eyes approval via backend.
    func updatePlatformServiceChargeRate(_ rate: Double) async throws {
        // Check admin role dynamically (not cached) to ensure current user has permission
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }

        guard validatePlatformServiceChargeRate(rate) else {
            throw ConfigurationError.invalidValue("Platform service charge rate must be between 0.0 (0%) and 0.1 (10%)")
        }

        // Try to request change via backend (4-eyes for critical parameters)
        if let client = getParseAPIClient() {
            let response = try await requestConfigurationChangeViaBackend(
                client: client,
                parameterName: "platformServiceChargeRate",
                newValue: rate,
                reason: "Admin configuration update"
            )

            if response.requiresApproval {
                // 4-eyes approval required - don't apply locally yet
                print("⏳ Platform service charge rate change requires 4-eyes approval. Request ID: \(response.fourEyesRequestId ?? "unknown")")
                throw ConfigurationError.fourEyesApprovalRequired(requestId: response.fourEyesRequestId ?? "unknown")
            }
        }

        // Apply locally (either non-critical or backend approved immediately)
        return try await withCheckedThrowingContinuation { continuation in
            let queue = self.queue
            queue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: ConfigurationError.saveFailed)
                    return
                }

                self.configuration.platformServiceChargeRate = rate
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"

                Task { @MainActor in
                    self.platformServiceChargeRate = rate
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
}
