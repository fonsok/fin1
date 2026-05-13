import Foundation

extension CustomerSupportService {
    // MARK: - Ticket Creation

    func createSupportTicket(_ ticket: SupportTicketCreate) async throws -> SupportTicket {
        try await validatePermission(.createSupportTicket)
        let customer = mockCustomers.first(where: { $0.id == ticket.userId })
        let customerName = customer?.fullName ?? "Kunde"
        let customerLanguage = customer?.language

        await logAction(.createSupportTicket, customerId: ticket.userId, description: "Support-Ticket erstellt: \(ticket.subject)")

        var newTicket = SupportTicket(
            id: UUID().uuidString,
            ticketNumber: "TKT-\(Int.random(in: 10_000...99_999))",
            userId: ticket.userId,
            customerName: customerName,
            subject: ticket.subject,
            description: ticket.description,
            status: .open,
            priority: ticket.priority,
            assignedTo: nil,
            createdAt: Date(),
            updatedAt: Date(),
            responses: []
        )
        applyAutoAssignment(to: &newTicket, customerLanguage: customerLanguage, logPrefix: "ticket")

        if let apiService = ticketAPIService {
            do {
                let syncedTicket = try await apiService.createTicket(ticket)
                await MainActor.run { self.mockTickets.append(syncedTicket) }
                logger.info("✅ Support ticket created and synced: \(syncedTicket.ticketNumber)")
                return syncedTicket
            } catch {
                logger.error("⚠️ Failed to sync ticket immediately: \(error.localizedDescription)")
            }
        }

        let ticketToAppend = newTicket
        await MainActor.run { self.mockTickets.append(ticketToAppend) }
        logger.info("✅ Support ticket created: \(newTicket.ticketNumber)")
        return newTicket
    }

    func createUserTicket(userId: String, subject: String, description: String, category: String) async throws -> SupportTicket {
        let customer = mockCustomers.first(where: { $0.id == userId })
        let customerName = customer?.fullName ?? "Benutzer"
        let customerLanguage = customer?.language
        let priority = mapCategoryToPriority(category)
        logger.info("📧 User \(userId) creating support ticket: \(subject)")

        var newTicket = SupportTicket(
            id: UUID().uuidString,
            ticketNumber: "TKT-\(Int.random(in: 10_000...99_999))",
            userId: userId,
            customerName: customerName,
            subject: subject,
            description: description,
            status: .open,
            priority: priority,
            assignedTo: nil,
            createdAt: Date(),
            updatedAt: Date(),
            responses: []
        )
        applyAutoAssignment(to: &newTicket, customerLanguage: customerLanguage, logPrefix: "user ticket")

        if let apiService = ticketAPIService {
            do {
                let ticketCreate = SupportTicketCreate(userId: userId, subject: subject, description: description, priority: priority)
                let syncedTicket = try await apiService.createTicket(ticketCreate)
                await MainActor.run { self.mockTickets.append(syncedTicket) }
                logger.info("✅ Support ticket created and synced: \(syncedTicket.ticketNumber) for user \(userId)")
                return syncedTicket
            } catch {
                logger.error("⚠️ Failed to sync user ticket immediately: \(error.localizedDescription)")
            }
        }

        let ticketToAppend = newTicket
        await MainActor.run { self.mockTickets.append(ticketToAppend) }
        logger.info("✅ Support ticket created: \(newTicket.ticketNumber) for user \(userId)")
        return newTicket
    }

    // MARK: - Ticket Responses / Escalation / Assignment

    func respondToTicket(ticketId: String, response: String, isInternal: Bool) async throws {
        try await validatePermission(.respondToSupportTicket)
        if let apiService = ticketAPIService {
            do {
                let backendResponse = try await apiService.replyToTicket(ticketId: ticketId, message: response, isInternal: isInternal)
                await MainActor.run {
                    if let ticketIndex = self.mockTickets.firstIndex(where: { $0.id == ticketId }) {
                        var ticket = self.mockTickets[ticketIndex]
                        ticket.responses.append(backendResponse)
                        ticket.updatedAt = Date()
                        self.mockTickets[ticketIndex] = ticket
                    }
                }
                logger.info("✅ Ticket response synced to backend")
                return
            } catch {
                logger.error("⚠️ Failed to sync ticket response immediately: \(error.localizedDescription)")
            }
        }

        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }
        let ticket = mockTickets[ticketIndex]
        let endUserObjectId = ticket.userId
        let ticketResponse = TicketResponse(
            id: UUID().uuidString,
            agentId: currentAgentId,
            agentName: currentAgentName,
            message: response,
            isInternal: isInternal,
            createdAt: Date()
        )
        var updatedTicket = ticket
        updatedTicket.responses.append(ticketResponse)
        updatedTicket.status = isInternal ? ticket.status : .inProgress
        updatedTicket.updatedAt = Date()
        await MainActor.run { self.mockTickets[ticketIndex] = updatedTicket }
        let actionDescription = isInternal ? "Interne Notiz auf Ticket \(ticketId)" : "Antwort auf Ticket \(ticketId)"
        await logAction(.respondToSupportTicket, customerId: endUserObjectId, description: actionDescription)
        if !isInternal {
            await sendTicketResponseNotification(ticket: ticket, endUserObjectId: endUserObjectId, ticketId: ticketId)
        }
    }

    func escalateTicket(ticketId: String, reason: String) async throws {
        try await validatePermission(.escalateToAdmin)
        try await self.escalateTicketInternal(ticketId: ticketId, reason: reason, isAutomatic: false)
    }

    func escalateTicketInternal(ticketId: String, reason: String, isAutomatic: Bool) async throws {
        guard let ticketIndex = mockTickets.firstIndex(where: { $0.id == ticketId }) else {
            throw CustomerSupportError.ticketNotFound
        }
        let ticket = mockTickets[ticketIndex]
        if ticket.status != .escalated {
            mockTickets[ticketIndex].status = .escalated
            mockTickets[ticketIndex].updatedAt = Date()
        }
        await logAction(
            .escalateToAdmin,
            customerId: ticket.userId,
            description: isAutomatic ? "Automatische Eskalation: Ticket \(ticketId) - \(reason)" : "Ticket \(ticketId) eskaliert: \(reason)",
            actionType: .escalation
        )
        let event = ComplianceEvent(
            eventType: .escalation,
            agentId: isAutomatic ? "system" : currentAgentId,
            customerId: ticket.userId,
            description: isAutomatic ? "Automatische Eskalation: Ticket \(ticket.ticketNumber) - \(reason)" : "Support-Ticket \(ticket.ticketNumber) an Admin eskaliert",
            severity: .high,
            requiresReview: isAutomatic
        )
        await auditService.logComplianceEvent(event)
        logger.info("📈 Ticket \(ticket.ticketNumber) escalated: \(reason) (automatic: \(isAutomatic))")
    }
}
