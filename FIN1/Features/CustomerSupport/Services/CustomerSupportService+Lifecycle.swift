import Foundation

// MARK: - Customer Support Service - Ticket Lifecycle Extension
/// Handles ticket reopening, archiving, and related tickets

extension CustomerSupportService {

    // MARK: - Ticket Reopening

    /// CSR reopens a ticket within the 7-day grace period
    func reopenTicket(ticketId: String, reason: String) async throws {
        try await validatePermission(.respondToSupportTicket)

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        guard ticket.canReopen else {
            throw CustomerSupportError.invalidRequest("Ticket kann nicht wiedereröffnet werden. Die 7-Tage-Frist ist abgelaufen.")
        }

        // Create reopen response
        let reopenResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: "🔄 Ticket wiedereröffnet: \(reason)",
            isInternal: false,
            createdAt: Date(),
            responseType: .statusChange,
            solutionDetails: nil
        )

        var updatedResponses = ticket.responses
        updatedResponses.append(reopenResponse)

        // Update ticket status
        mockTickets[ticketIndex].status = .inProgress
        mockTickets[ticketIndex].updatedAt = Date()
        mockTickets[ticketIndex].responses = updatedResponses
        mockTickets[ticketIndex].closedAt = nil  // Clear closed date

        // Increase agent ticket count if reassigned to same agent
        if let agentId = ticket.assignedTo,
           let agentIndex = mockAgents.firstIndex(where: { $0.id == agentId }) {
            mockAgents[agentIndex].currentTicketCount += 1
        }

        await logAction(
            .respondToSupportTicket,
            customerId: ticket.userId,
            description: "Ticket \(ticket.ticketNumber) wiedereröffnet: \(reason)"
        )

        logger.info("🔄 Ticket \(ticket.ticketNumber) reopened: \(reason)")
    }

    /// User requests to reopen their ticket
    func userRequestReopenTicket(ticketId: String, userId: String, reason: String) async throws -> SupportTicket {
        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }

        let ticket = mockTickets[ticketIndex]

        // Verify user owns this ticket
        let customer = mockCustomers.first(where: { $0.id == userId })
        guard ticket.userId == userId else {
            throw CustomerSupportError.invalidRequest("Sie können nur eigene Tickets wiedereröffnen")
        }

        // If within grace period, reopen the existing ticket
        if ticket.canReopen {
            // Create reopen response
            let reopenResponse = TicketResponse(
                id: UUID().uuidString,
                agentId: userId,
                agentName: customer?.fullName ?? "Kunde",
                message: "🔄 Kunde hat Ticket wiedereröffnet: \(reason)",
                isInternal: false,
                createdAt: Date(),
                responseType: .statusChange,
                solutionDetails: nil
            )

            var updatedResponses = ticket.responses
            updatedResponses.append(reopenResponse)

            mockTickets[ticketIndex].status = .open
            mockTickets[ticketIndex].updatedAt = Date()
            mockTickets[ticketIndex].responses = updatedResponses
            mockTickets[ticketIndex].closedAt = nil

            // Notify assigned agent
            if let agentId = ticket.assignedTo {
                notificationService.createNotification(
                    title: "Ticket wiedereröffnet",
                    message: "Ticket \(ticket.ticketNumber) wurde vom Kunden wiedereröffnet.",
                    type: .system,
                    priority: .high,
                    for: agentId,
                    metadata: ["ticketId": ticketId, "ticketNumber": ticket.ticketNumber]
                )
            }

            logger.info("🔄 User reopened ticket \(ticket.ticketNumber)")
            return mockTickets[ticketIndex]
        }

        // Grace period expired - create new linked ticket
        let newTicketNumber = self.generateTicketNumber()
        let newTicket = SupportTicket(
            id: UUID().uuidString,
            ticketNumber: newTicketNumber,
            userId: ticket.userId,
            customerName: ticket.customerName,
            subject: "Folgeanfrage: \(ticket.subject)",
            description: "Bezug auf Ticket \(ticket.ticketNumber):\n\n\(reason)",
            status: .open,
            priority: ticket.priority,
            assignedTo: ticket.assignedTo,  // Assign to same agent if possible
            createdAt: Date(),
            updatedAt: Date(),
            responses: [],
            closedAt: nil,
            archivedAt: nil,
            parentTicketId: ticketId
        )

        mockTickets.append(newTicket)

        // Notify assigned agent
        if let agentId = newTicket.assignedTo {
            notificationService.createNotification(
                title: "Neues Folge-Ticket",
                message: "Folge-Ticket \(newTicketNumber) erstellt (Bezug: \(ticket.ticketNumber))",
                type: .system,
                priority: .medium,
                for: agentId,
                metadata: ["ticketId": newTicket.id, "ticketNumber": newTicketNumber, "parentTicketId": ticketId]
            )
        }

        logger.info("📝 New follow-up ticket \(newTicketNumber) created for expired ticket \(ticket.ticketNumber)")
        return newTicket
    }

    // MARK: - Archiving

    /// Archive old closed tickets (30+ days old)
    func archiveOldTickets() async throws -> Int {
        var archivedCount = 0

        for index in mockTickets.indices {
            if mockTickets[index].shouldAutoArchive {
                let ticketNumber = mockTickets[index].ticketNumber
                mockTickets[index].status = .archived
                mockTickets[index].archivedAt = Date()
                archivedCount += 1
                logger.info("📦 Archived ticket \(ticketNumber)")
            }
        }

        if archivedCount > 0 {
            logger.info("📦 Auto-archived \(archivedCount) tickets")
        }

        return archivedCount
    }

    // MARK: - Related Tickets

    /// Get tickets related to a customer
    func getRelatedTickets(userId: String, excludeTicketId: String?) async throws -> [SupportTicket] {
        let tickets = mockTickets
        return tickets.filter { ticket in
            ticket.userId == userId &&
                ticket.id != excludeTicketId &&
                ticket.status != .archived
        }
        .sorted { $0.createdAt > $1.createdAt }
        .prefix(10)
        .map { $0 }
    }

    // MARK: - Helper

    private func generateTicketNumber() -> String {
        let number = Int.random(in: 10_000...99_999)
        return "TKT-\(number)"
    }
}

