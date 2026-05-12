import Foundation

// MARK: - Customer Support Service - Ticket Operations Extension
/// Extension handling all support ticket operations (CSR and user self-service)

extension CustomerSupportService {

    // MARK: - Ticket Retrieval

    func getSupportTickets(userId: String?) async throws -> [SupportTicket] {
        try await validatePermission(.viewCustomerSupportHistory)

        // Try loading from backend first
        if let apiService = ticketAPIService {
            do {
                let backendTickets = try await apiService.fetchTickets(
                    userId: userId,
                    status: nil as SupportTicket.TicketStatus?,
                    limit: 100,
                    skip: 0
                )

                // Update local cache
                await MainActor.run {
                    // Merge with existing tickets (avoid duplicates)
                    for backendTicket in backendTickets {
                        if let index = self.mockTickets.firstIndex(where: { $0.id == backendTicket.id }) {
                            self.mockTickets[index] = backendTicket
                        } else {
                            self.mockTickets.append(backendTicket)
                        }
                    }
                }

                // Return filtered tickets
                if let uid = userId {
                    return backendTickets.filter { $0.userId == uid }
                }
                return backendTickets
            } catch {
                print("⚠️ CustomerSupportService: Failed to load tickets from backend: \(error.localizedDescription)")
                // Fall through to mock data
            }
        }

        // Fallback to mock data
        if let uid = userId {
            return mockTickets.filter { $0.userId == uid }
        }
        return mockTickets
    }

    func getUserTickets(userId: String) async throws -> [SupportTicket] {
        // Users can view their own tickets without permission check

        // Try loading from backend first
        if let apiService = ticketAPIService {
            do {
                let backendTickets = try await apiService.fetchTickets(
                    userId: userId,
                    status: nil as SupportTicket.TicketStatus?,
                    limit: 100,
                    skip: 0
                )

                // Update local cache
                await MainActor.run {
                    for backendTicket in backendTickets {
                        if let index = self.mockTickets.firstIndex(where: { $0.id == backendTicket.id }) {
                            self.mockTickets[index] = backendTicket
                        } else {
                            self.mockTickets.append(backendTicket)
                        }
                    }
                }

                return backendTickets
            } catch {
                print("⚠️ CustomerSupportService: Failed to load user tickets from backend: \(error.localizedDescription)")
                // Fall through to mock data
            }
        }

        // Fallback to mock data
        return mockTickets.filter { $0.userId == userId }
    }

    func getTicket(ticketId: String) async throws -> SupportTicket? {
        // Users can view their own tickets, CSR can view any ticket

        // Try loading from backend first
        if let apiService = ticketAPIService {
            do {
                if let backendTicket = try await apiService.fetchTicket(ticketId: ticketId) {
                    // Update local cache
                    await MainActor.run {
                        if let index = self.mockTickets.firstIndex(where: { $0.id == ticketId }) {
                            self.mockTickets[index] = backendTicket
                        } else {
                            self.mockTickets.append(backendTicket)
                        }
                    }
                    return backendTicket
                }
            } catch {
                print("⚠️ CustomerSupportService: Failed to load ticket from backend: \(error.localizedDescription)")
                // Fall through to mock data
            }
        }

        // Fallback to mock data
        return mockTickets.first(where: { $0.id == ticketId })
    }

}

