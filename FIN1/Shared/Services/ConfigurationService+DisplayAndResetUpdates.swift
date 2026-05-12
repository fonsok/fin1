import Foundation
@preconcurrency import Dispatch

extension ConfigurationService {
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
                Task { @MainActor in self.showCommissionBreakdownInCreditNote = value }
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
                        "display": ["showCommissionBreakdownInCreditNote": value]
                    ]
                )
            } catch {}
        }
    }

    func updateShowDocumentReferenceLinksInAccountStatement(_ value: Bool) async throws {
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

                self.configuration.showDocumentReferenceLinksInAccountStatement = value
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"
                Task { @MainActor in self.showDocumentReferenceLinksInAccountStatement = value }
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
                        "display": ["showDocumentReferenceLinksInAccountStatement": value]
                    ]
                )
            } catch {}
        }
    }

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
                Task { @MainActor in self.maximumRiskExposurePercent = value }
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
            } catch {}
        }
    }

    func updateAppServiceChargeRate(_ rate: Double) async throws {
        guard userService.currentUser?.role == .admin else {
            throw ConfigurationError.unauthorizedAccess
        }
        guard validateAppServiceChargeRate(rate) else {
            throw ConfigurationError.invalidValue("App service charge rate must be between 0.0 (0%) and 0.1 (10%)")
        }

        if let client = getParseAPIClient() {
            let response = try await requestConfigurationChangeViaBackend(
                client: client,
                parameterName: "appServiceChargeRate",
                newValue: rate,
                reason: "Admin configuration update"
            )
            if response.requiresApproval {
                print("⏳ App service charge rate change requires 4-eyes approval. Request ID: \(response.fourEyesRequestId ?? "unknown")")
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

                self.configuration.appServiceChargeRate = rate
                self.configuration.lastUpdated = Date()
                self.configuration.updatedBy = self.userService.currentUser?.id ?? "unknown"
                Task { @MainActor in self.appServiceChargeRate = rate }
                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func updateSLAMonitoringInterval(_ interval: TimeInterval) async throws {
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
                Task { @MainActor in self.slaMonitoringInterval = interval }
                self.saveConfiguration()
                continuation.resume()
            }
        }
    }

    func resetToDefaults() async throws {
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
                Task { @MainActor in self.updatePublishedValues() }
                self.saveConfiguration()
                continuation.resume()
            }
        }
    }
}
