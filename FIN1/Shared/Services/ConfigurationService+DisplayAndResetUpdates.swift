@preconcurrency import Dispatch
import Foundation

extension ConfigurationService {
    func updateShowCommissionBreakdownInCreditNote(_ value: Bool) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func updateShowDocumentReferenceLinksInAccountStatement(_ value: Bool) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func updateMaximumRiskExposurePercent(_ value: Double) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func updateAppServiceChargeRate(_ rate: Double) async throws {
        throw ConfigurationError.serverManagedConfiguration
    }

    func resetToDefaults() async throws {
        throw ConfigurationError.serverManagedConfiguration
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
}
