import Foundation

// MARK: - SLA Monitoring Service Protocol
/// Protocol for monitoring SLA violations and triggering automatic escalations

@MainActor
protocol SLAMonitoringServiceProtocol {
    /// Check all active tickets for SLA violations and escalate if needed
    func checkAndEscalateViolations() async throws

    /// Start periodic monitoring of SLA violations
    /// If interval is nil, uses configured interval from ConfigurationService
    func startMonitoring(interval: TimeInterval?) async

    /// Stop periodic monitoring
    func stopMonitoring()

    /// Check a specific ticket for SLA violation
    func checkTicketForViolation(_ ticket: SupportTicket) async -> Bool
}

