import Foundation

// MARK: - CustomerSupportDashboardViewModel + Customer Operations
/// Extension handling customer selection, data loading, and modifications

extension CustomerSupportDashboardViewModel {

    // MARK: - Customer Selection

    func selectCustomer(_ result: CustomerSearchResult) async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Load customer profile
            if let profile = try await supportService.getCustomerProfile(customerId: result.customerId) {
                selectedCustomer = profile

                // Load role-specific data using the user's actual ID (profile.id)
                // Note: profile.id is the real user ID (e.g., "user:investor1@test.com")
                // which matches investorId/traderId in real investments/trades
                print("🔍 CSR: Loading data for \(profile.role) - userId='\(profile.id)', customerId='\(profile.customerId)'")

                if profile.role.lowercased() == "investor" {
                    customerInvestments = try await supportService.getCustomerInvestments(customerId: profile.id)
                    customerTrades = [] // Clear trades for investor
                    print("🔍 CSR: Loaded \(customerInvestments.count) investments for investor")
                } else if profile.role.lowercased() == "trader" {
                    customerTrades = try await supportService.getCustomerTrades(customerId: profile.id)
                    customerInvestments = [] // Clear investments for trader
                    print("🔍 CSR: Loaded \(customerTrades.count) trades for trader")
                }
            }

            // Load related data using customerId (display number) for profile-related data
            customerKYCStatus = try await supportService.getCustomerKYCStatus(customerId: result.customerId)
            customerDocuments = try await supportService.getCustomerDocuments(customerId: result.customerId)
        } catch {
            handleError(error)
        }
    }

    func clearSelectedCustomer() {
        selectedCustomer = nil
        customerKYCStatus = nil
        customerInvestments = []
        customerTrades = []
        customerDocuments = []
        customerTickets = []
    }

    // MARK: - Customer Tickets

    /// Loads tickets for the currently selected customer
    func loadCustomerTickets(customerId: String) async {
        isLoadingCustomerTickets = true
        defer { isLoadingCustomerTickets = false }

        do {
            customerTickets = try await supportService.getRelatedTickets(
                customerId: customerId,
                excludeTicketId: nil
            )
        } catch {
            // Silently fail - tickets are supplementary info
            customerTickets = []
        }
    }

    /// Active tickets for the customer (not resolved, closed, or archived)
    var activeCustomerTickets: [SupportTicket] {
        customerTickets.filter { ticket in
            ticket.status != .resolved &&
            ticket.status != .closed &&
            ticket.status != .archived
        }
    }

    /// Closed tickets for the customer (resolved, closed, or archived)
    var closedCustomerTickets: [SupportTicket] {
        customerTickets.filter { ticket in
            ticket.status == .resolved ||
            ticket.status == .closed ||
            ticket.status == .archived
        }
    }

    // MARK: - KYC Status List

    func openKYCStatusList() {
        Task {
            await loadKYCStatusList()
            showKYCStatusList = true
        }
    }

    func loadKYCStatusList() async {
        isLoading = true
        defer { isLoading = false }

        do {
            kycStatusList = try await supportService.searchCustomers(query: "")
        } catch {
            handleError(error)
        }
    }

    func closeKYCStatusList() {
        showKYCStatusList = false
    }

    // MARK: - Customer Modifications

    func initiatePasswordReset(customerId: String) async {
        guard hasPermission(.resetCustomerPassword) else {
            showPermissionError(.resetCustomerPassword)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.initiatePasswordReset(customerId: customerId)
            showSuccessMessage("Passwort-Reset wurde initiiert. Der Kunde erhält eine E-Mail.")
        } catch {
            handleError(error)
        }
    }

    func unlockAccount(customerId: String, reason: String) async {
        guard hasPermission(.unlockCustomerAccount) else {
            showPermissionError(.unlockCustomerAccount)
            return
        }
        isLoading = true
        defer { isLoading = false }

        do {
            try await supportService.unlockAccount(customerId: customerId, reason: reason)
            showSuccessMessage("Konto wurde entsperrt.")
        } catch {
            handleError(error)
        }
    }

    // MARK: - Investment Filtering

    /// Filtered investments based on selected time period
    var filteredInvestmentsByTimePeriod: [CustomerInvestmentSummary] {
        guard selectedInvestmentTimePeriod != .allTime else {
            return customerInvestments
        }

        let cutoffDate = selectedInvestmentTimePeriod.cutoffDate()
        return customerInvestments.filter { investment in
            investment.createdAt >= cutoffDate
        }
    }

    // MARK: - Trade Filtering

    /// Filtered trades based on selected time period
    var filteredTradesByTimePeriod: [CustomerTradeSummary] {
        guard selectedTradeTimePeriod != .allTime else {
            return customerTrades
        }

        let cutoffDate = selectedTradeTimePeriod.cutoffDate()
        return customerTrades.filter { trade in
            trade.createdAt >= cutoffDate
        }
    }

    /// Ongoing trades (open or active status)
    var ongoingTrades: [CustomerTradeSummary] {
        filteredTradesByTimePeriod.filter { trade in
            trade.status.lowercased() == "open" || trade.status.lowercased() == "active"
        }
    }

    /// Completed trades (closed or completed status)
    var completedTrades: [CustomerTradeSummary] {
        filteredTradesByTimePeriod.filter { trade in
            trade.status.lowercased() == "closed" || trade.status.lowercased() == "completed"
        }
    }
}
