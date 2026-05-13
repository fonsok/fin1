import Foundation

extension CustomerSupportService {
    // MARK: - Agent Operations

    func getAvailableAgents() async throws -> [CSRAgent] {
        try await validatePermission(.viewCustomerSupportHistory)
        return mockAgents
    }

    func assignTicket(ticketId: String, to agentId: String) async throws {
        try await validatePermission(.respondToSupportTicket)
        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }
        let ticket = mockTickets[ticketIndex]
        let previousAgentId = ticket.assignedTo
        if previousAgentId == agentId {
            logger.info("ℹ️ Ticket \(ticket.ticketNumber) bereits diesem Agent zugewiesen")
            return
        }
        guard let newAgentIndex = mockAgents.firstIndex(where: { $0.id == agentId }) else {
            throw CustomerSupportError.invalidRequest("Agent nicht gefunden")
        }
        guard mockAgents[newAgentIndex].canAcceptTickets else {
            throw CustomerSupportError.invalidRequest(
                "Agent kann keine weiteren Tickets annehmen (\(mockAgents[newAgentIndex].currentTicketCount)/\(CSRAgent.maxTickets) Tickets)"
            )
        }
        if let oldAgentId = previousAgentId, let oldAgentIndex = mockAgents.firstIndex(where: { $0.id == oldAgentId }) {
            self.mockAgents[oldAgentIndex].currentTicketCount = max(0, self.mockAgents[oldAgentIndex].currentTicketCount - 1)
            logger.info("📉 Agent \(self.mockAgents[oldAgentIndex].name) Ticket-Anzahl verringert")
        }
        mockAgents[newAgentIndex].currentTicketCount += 1
        mockTickets[ticketIndex].assignedTo = agentId
        mockTickets[ticketIndex].updatedAt = Date()
        if mockTickets[ticketIndex].status == .open {
            mockTickets[ticketIndex].status = .inProgress
        }
        let newAgentName = mockAgents[newAgentIndex].name
        await logAction(
            .respondToSupportTicket,
            customerId: ticket.userId,
            description: "Ticket \(ticket.ticketNumber) zugewiesen an \(newAgentName)"
        )
        await self.sendAgentAssignmentNotification(ticket: mockTickets[ticketIndex], agent: mockAgents[newAgentIndex])
        logger.info("✅ Ticket \(ticket.ticketNumber) assigned to \(newAgentName) (\(agentId))")
    }

    // MARK: - Helpers

    func mapCategoryToPriority(_ category: String) -> SupportTicket.TicketPriority {
        switch category {
        case "Security Concern", "Account Issue":
            return .high
        case "Technical Problem", "Billing & Payments":
            return .medium
        default:
            return .low
        }
    }

    func applyAutoAssignment(to ticket: inout SupportTicket, customerLanguage: String?, logPrefix: String) {
        let assignmentResult = assignmentService.findBestAgent(for: ticket, agents: mockAgents, customerLanguage: customerLanguage)
        let ticketNumber = ticket.ticketNumber
        switch assignmentResult {
        case .assigned(let agentId, let agentName, let reason):
            ticket.assignedTo = agentId
            ticket.status = .inProgress
            logger.info("🎯 Auto-assigned \(logPrefix) \(ticketNumber) to \(agentName): \(reason)")
            if let agentIndex = mockAgents.firstIndex(where: { $0.id == agentId }) {
                mockAgents[agentIndex].currentTicketCount += 1
                let ticketForNotification = ticket
                Task { await self.sendAgentAssignmentNotification(ticket: ticketForNotification, agent: self.mockAgents[agentIndex]) }
            }
        case .queued(let reason):
            logger.info("📥 \(logPrefix.capitalized) \(ticketNumber) queued: \(reason)")
        case .failed(let error):
            logger.error("❌ Auto-assignment failed: \(error)")
        }
    }

    func sendTicketResponseNotification(ticket: SupportTicket, endUserObjectId: String, ticketId: String) async {
        let customer = mockCustomers.first(where: { $0.id == endUserObjectId })
        let notifyUserId = customer?.id ?? endUserObjectId
        notificationService.createNotification(
            title: "Neue Antwort auf Support-Ticket",
            message: "Ihr Ticket \"\(ticket.subject)\" hat eine neue Antwort erhalten.",
            type: .system,
            priority: .medium,
            for: notifyUserId,
            metadata: ["ticketId": ticketId]
        )
        logger.info("📧 Notification sent to user \(notifyUserId) (userId: \(endUserObjectId)) for ticket \(ticketId)")
        if let concreteService = notificationService as? NotificationService {
            logger.info("📧 NotificationService has \(concreteService.notifications.count) total notifications")
            let userNotifications = concreteService.notifications.filter { $0.userId == notifyUserId }
            logger.info("📧 User \(notifyUserId) has \(userNotifications.count) notifications")
        }
    }

    func sendAgentAssignmentNotification(ticket: SupportTicket, agent: CSRAgent) async {
        notificationService.createNotification(
            title: "Neues Ticket zugewiesen",
            message: "Ticket \(ticket.ticketNumber): \"\(ticket.subject)\" wurde Ihnen zugewiesen. Priorität: \(ticket.priority.displayName)",
            type: .system,
            priority: ticket.priority == .urgent || ticket.priority == .high ? .high : .medium,
            for: agent.id,
            metadata: [
                "ticketId": ticket.id,
                "ticketNumber": ticket.ticketNumber,
                "userId": ticket.userId,
                "priority": ticket.priority.rawValue
            ]
        )
        logger.info("📧 Assignment notification sent to CSR \(agent.name) (\(agent.id)) for ticket \(ticket.ticketNumber)")
        if let concreteService = notificationService as? NotificationService {
            let agentNotifications = concreteService.notifications.filter { $0.userId == agent.id }
            logger.info("📧 Agent \(agent.name) has \(agentNotifications.count) notifications")
        }
    }
}
