import Combine
import Foundation
import os.log

// MARK: - SLA Monitoring Service
/// Monitors tickets for SLA violations and automatically escalates when deadlines are breached

@MainActor
final class SLAMonitoringService: SLAMonitoringServiceProtocol {

    // MARK: - Dependencies

    private weak var supportService: CustomerSupportServiceProtocol?
    private let auditService: AuditLoggingServiceProtocol
    private let notificationService: any NotificationServiceProtocol
    private let configurationService: any ConfigurationServiceProtocol
    private let logger = Logger(subsystem: "com.fin.app", category: "SLAMonitoring")

    // MARK: - Properties

    /// Touched from `deinit` (nonisolated); start/stop run on the main actor in practice.
    private nonisolated(unsafe) var monitoringTask: Task<Void, Never>?
    private var escalatedTicketIds: Set<String> = []
    private let slaConfig = SLAConfiguration.default
    private nonisolated(unsafe) var configurationObserver: AnyCancellable?

    // MARK: - Initialization

    init(
        supportService: CustomerSupportServiceProtocol?,
        auditService: AuditLoggingServiceProtocol,
        notificationService: any NotificationServiceProtocol,
        configurationService: any ConfigurationServiceProtocol
    ) {
        self.supportService = supportService
        self.auditService = auditService
        self.notificationService = notificationService
        self.configurationService = configurationService

        // Observe configuration changes and restart monitoring with new interval
        self.setupConfigurationObserver()
    }

    private func setupConfigurationObserver() {
        // Cast to concrete type to access @Published publisher
        // This is safe because AppServicesBuilder always creates ConfigurationService
        guard let configService = configurationService as? ConfigurationService else {
            self.logger.warning("⚠️ ConfigurationService is not the expected concrete type")
            return
        }

        self.configurationObserver = configService.$slaMonitoringInterval
            .dropFirst() // Skip initial value
            .sink { [weak self] (newInterval: TimeInterval) in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.logger.info("🔄 SLA monitoring interval changed to \(newInterval)s, restarting...")
                    self.stopMonitoring()
                    await self.startMonitoring(interval: newInterval)
                }
            }
    }

    // MARK: - Monitoring Control

    func startMonitoring(interval: TimeInterval? = nil) async {
        self.stopMonitoring()

        // Use provided interval or read from configuration
        let monitoringInterval = interval ?? self.configurationService.slaMonitoringInterval

        self.logger.info("🔍 Starting SLA monitoring with interval: \(monitoringInterval)s")

        self.monitoringTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                do {
                    try await self?.checkAndEscalateViolations()
                } catch {
                    self?.logger.error("❌ SLA monitoring error: \(error.localizedDescription)")
                }

                try? await Task.sleep(nanoseconds: UInt64(monitoringInterval * 1_000_000_000))
            }
        }
    }

    func stopMonitoring() {
        self.monitoringTask?.cancel()
        self.monitoringTask = nil
        self.logger.info("🛑 SLA monitoring stopped")
    }

    // MARK: - Violation Checking

    func checkAndEscalateViolations() async throws {
        guard let supportService = supportService else {
            self.logger.warning("⚠️ Support service not available for SLA monitoring")
            return
        }

        // Get all active tickets
        let tickets = try await supportService.getSupportTickets(userId: nil)
        let activeTickets = tickets.filter { ticket in
            ticket.status != .resolved &&
                ticket.status != .closed &&
                ticket.status != .archived
        }

        self.logger.info("🔍 Checking \(activeTickets.count) active tickets for SLA violations")

        var violationCount = 0

        for ticket in activeTickets {
            let hasViolation = await checkTicketForViolation(ticket)

            if hasViolation && !self.escalatedTicketIds.contains(ticket.id) {
                do {
                    try await self.escalateTicketForSLAViolation(ticket)
                    self.escalatedTicketIds.insert(ticket.id)
                    violationCount += 1
                } catch {
                    self.logger.error("❌ Failed to escalate ticket \(ticket.ticketNumber): \(error.localizedDescription)")
                }
            }
        }

        if violationCount > 0 {
            self.logger.info("⚠️ Escalated \(violationCount) ticket(s) due to SLA violations")
        }
    }

    func checkTicketForViolation(_ ticket: SupportTicket) async -> Bool {
        let slaInfo = ticket.getSLAInfo(config: self.slaConfig)

        // Check if either first response or resolution SLA is breached
        return slaInfo.firstResponseStatus == .breached || slaInfo.resolutionStatus == .breached
    }

    // MARK: - Automatic Escalation

    private func escalateTicketForSLAViolation(_ ticket: SupportTicket) async throws {
        guard let supportService = supportService else {
            throw CustomerSupportError.serviceUnavailable
        }

        let slaInfo = ticket.getSLAInfo(config: self.slaConfig)

        // Determine which SLA was violated
        var violationReason = "SLA-Deadline überschritten"
        if slaInfo.firstResponseStatus == .breached && slaInfo.resolutionStatus == .breached {
            violationReason = "Erste Antwort und Lösung: SLA-Deadline überschritten"
        } else if slaInfo.firstResponseStatus == .breached {
            violationReason = "Erste Antwort: SLA-Deadline überschritten"
        } else if slaInfo.resolutionStatus == .breached {
            violationReason = "Lösung: SLA-Deadline überschritten"
        }

        // Escalate the ticket (using internal method to bypass permission check)
        try await supportService.escalateTicketInternal(ticketId: ticket.id, reason: violationReason, isAutomatic: true)

        // Add internal note about automatic escalation
        let escalationNote = "⚠️ Automatische Eskalation: \(violationReason). Ticket wurde automatisch eskaliert, da die SLA-Deadline überschritten wurde."
        try await supportService.respondToTicket(ticketId: ticket.id, response: escalationNote, isInternal: true)

        // Send notification to assigned agent (if any)
        if let assignedAgentId = ticket.assignedTo {
            await self.sendSLAViolationNotification(
                ticket: ticket,
                agentId: assignedAgentId,
                violationReason: violationReason
            )
        }

        // Log compliance event
        let event = ComplianceEvent(
            eventType: .escalation,
            agentId: "system",
            customerId: ticket.userId,
            description: "Automatische Eskalation: Ticket \(ticket.ticketNumber) - \(violationReason)",
            severity: .high,
            requiresReview: true
        )
        await self.auditService.logComplianceEvent(event)

        self.logger.warning("⚠️ Automatically escalated ticket \(ticket.ticketNumber) due to SLA violation: \(violationReason)")
    }

    // MARK: - Notifications

    private func sendSLAViolationNotification(
        ticket: SupportTicket,
        agentId: String,
        violationReason: String
    ) async {
        self.notificationService.createNotification(
            title: "⚠️ SLA-Verletzung: Ticket \(ticket.ticketNumber)",
            message: "Das Ticket wurde automatisch eskaliert. \(violationReason)",
            type: .system,
            priority: .high,
            for: agentId,
            metadata: [
                "ticketId": ticket.id,
                "ticketNumber": ticket.ticketNumber,
                "violationType": "sla_breach",
                "autoEscalated": "true"
            ]
        )

        self.logger.info("📧 SLA violation notification sent to agent \(agentId) for ticket \(ticket.ticketNumber)")
    }

    // MARK: - Cleanup

    deinit {
        // Cannot call main-actor-isolated `stopMonitoring()` from `deinit`; cancel task directly.
        monitoringTask?.cancel()
        monitoringTask = nil
        configurationObserver?.cancel()
    }
}

