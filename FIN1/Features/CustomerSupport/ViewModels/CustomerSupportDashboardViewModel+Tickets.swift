import Foundation

// MARK: - CustomerSupportDashboardViewModel + Ticket Operations
/// Extension handling all ticket-related operations

extension CustomerSupportDashboardViewModel {

    // MARK: - Ticket Selection

    func selectTicket(_ ticket: SupportTicket) { selectedTicket = ticket }
    func clearSelectedTicket() { selectedTicket = nil }

    // MARK: - Create Ticket

    func openCreateTicketSheet(userId: String? = nil) {
        preselectedUserId = userId
        showCreateTicketSheet = true
    }

    func closeCreateTicketSheet() {
        showCreateTicketSheet = false
        preselectedUserId = nil
    }

    func createSupportTicket(
        userId: String,
        subject: String,
        description: String,
        priority: SupportTicket.TicketPriority
    ) async {
        guard hasPermission(.createSupportTicket) else {
            showPermissionError(.createSupportTicket)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            let ticket = SupportTicketCreate(
                userId: userId,
                subject: subject,
                description: description,
                priority: priority
            )
            _ = try await supportService.createSupportTicket(ticket)
            showSuccessMessage("Ticket wurde erstellt.")
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Respond to Ticket

    func openRespondTicketSheet(for ticket: SupportTicket) {
        ticketToRespond = ticket
        showRespondTicketSheet = true
    }

    func closeRespondTicketSheet() {
        showRespondTicketSheet = false
        ticketToRespond = nil
    }

    func respondToTicket(_ ticketId: String, message: String, isInternal: Bool) async {
        guard hasPermission(.respondToSupportTicket) else {
            showPermissionError(.respondToSupportTicket)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.respondToTicket(ticketId: ticketId, response: message, isInternal: isInternal)
            showSuccessMessage(isInternal ? "Interne Notiz hinzugefügt." : "Antwort gesendet.")
            self.closeRespondTicketSheet()
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Escalate Ticket

    func openEscalateTicketSheet(for ticket: SupportTicket) {
        ticketToEscalate = ticket
        showEscalateTicketSheet = true
    }

    func closeEscalateTicketSheet() {
        showEscalateTicketSheet = false
        ticketToEscalate = nil
    }

    func escalateTicket(_ ticketId: String, reason: String) async {
        guard hasPermission(.escalateToAdmin) else {
            showPermissionError(.escalateToAdmin)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.escalateTicket(ticketId: ticketId, reason: reason)
            showSuccessMessage("Ticket wurde eskaliert.")
            self.closeEscalateTicketSheet()
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Add Solution

    func openAddSolutionSheet(for ticket: SupportTicket) {
        ticketForAction = ticket
        showAddSolutionSheet = true
    }

    func closeAddSolutionSheet() {
        showAddSolutionSheet = false
        ticketForAction = nil
    }

    func addSolution(ticketId: String, solution: SolutionDetails, customerMessage: String) async {
        guard hasPermission(.respondToSupportTicket) else {
            showPermissionError(.respondToSupportTicket)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.addSolution(ticketId: ticketId, solution: solution, customerMessage: customerMessage)
            showSuccessMessage("Lösung wurde hinzugefügt und an den Kunden gesendet.")
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Internal Note

    func openInternalNoteSheet(for ticket: SupportTicket) {
        ticketForAction = ticket
        showInternalNoteSheet = true
    }

    func closeInternalNoteSheet() {
        showInternalNoteSheet = false
        ticketForAction = nil
    }

    func addInternalNote(ticketId: String, note: String) async {
        guard hasPermission(.respondToSupportTicket) else {
            showPermissionError(.respondToSupportTicket)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.addInternalNote(ticketId: ticketId, note: note)
            showSuccessMessage("Interne Notiz wurde hinzugefügt.")
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Dev Escalation

    func openDevEscalationSheet(for ticket: SupportTicket) {
        ticketForAction = ticket
        showDevEscalationSheet = true
    }

    func closeDevEscalationSheet() {
        showDevEscalationSheet = false
        ticketForAction = nil
    }

    func escalateToDevTeam(ticketId: String, escalation: DevEscalation) async {
        guard hasPermission(.escalateToAdmin) else {
            showPermissionError(.escalateToAdmin)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.escalateToDevTeam(ticketId: ticketId, escalation: escalation)
            showSuccessMessage("Bug wurde an das Entwicklungsteam (\(escalation.devTeam)) eskaliert.")
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Resolve/Close Ticket

    func openResolveTicketSheet(for ticket: SupportTicket) {
        ticketForAction = ticket
        showResolveTicketSheet = true
    }

    func closeResolveTicketSheet() {
        showResolveTicketSheet = false
        ticketForAction = nil
    }

    func resolveTicket(ticketId: String, resolutionNote: String, customerConfirmed: Bool) async {
        guard hasPermission(.respondToSupportTicket) else {
            showPermissionError(.respondToSupportTicket)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.resolveTicket(
                ticketId: ticketId,
                resolutionNote: resolutionNote,
                customerConfirmed: customerConfirmed
            )
            showSuccessMessage("Ticket wurde als gelöst markiert.")
            selectedTicket = nil
            await load()
        } catch {
            handleError(error)
        }
    }

    func closeTicket(ticketId: String, closureReason: String) async {
        guard hasPermission(.respondToSupportTicket) else {
            showPermissionError(.respondToSupportTicket)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.closeTicket(ticketId: ticketId, closureReason: closureReason)
            showSuccessMessage("Ticket wurde geschlossen.")
            selectedTicket = nil
            await load()
        } catch {
            handleError(error)
        }
    }

    func requestCustomerConfirmation(ticketId: String, message: String) async {
        guard hasPermission(.respondToSupportTicket) else {
            showPermissionError(.respondToSupportTicket)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.requestCustomerConfirmation(ticketId: ticketId, message: message)
            showSuccessMessage("Kundenbestätigung angefordert. Status: Wartet auf Kunde")
            await load()
        } catch {
            handleError(error)
        }
    }

    // MARK: - Assign Ticket

    func openAssignTicketSheet(for ticket: SupportTicket) {
        ticketForAction = ticket
        showAssignTicketSheet = true
    }

    func closeAssignTicketSheet() {
        showAssignTicketSheet = false
        ticketForAction = nil
    }

    func getAvailableAgents() async -> [CSRAgent] {
        do {
            return try await supportService.getAvailableAgents()
        } catch {
            handleError(error)
            return []
        }
    }

    func assignTicket(ticketId: String, to agentId: String) async {
        guard hasPermission(.respondToSupportTicket) else {
            showPermissionError(.respondToSupportTicket)
            return
        }

        do {
            try await supportService.assignTicket(ticketId: ticketId, to: agentId)
            showSuccessMessage("Ticket wurde neu zugewiesen.")
            Task { await load() }
        } catch {
            handleError(error)
        }
    }

    func getAgentName(for agentId: String) -> String {
        if agentId.hasPrefix("user:") {
            let email = String(agentId.dropFirst(5))
            switch email.lowercased() {
            case "csr1@test.com": return "Stefan Müller"
            case "csr2@test.com": return "Anna Schmidt"
            case "csr3@test.com": return "Markus Weber"
            default:
                return email.components(separatedBy: "@").first?.capitalized ?? agentId
            }
        }
        return agentId
    }
}

