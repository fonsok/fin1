import Foundation

// MARK: - Customer Support Service - Customer Data Extension
/// Extension handling customer search and data access operations

extension CustomerSupportService {

    // MARK: - Customer Search

    func searchCustomers(query: String) async throws -> [CustomerSearchResult] {
        try await validatePermission(.viewCustomerProfile)

        await logDataAccess(
            dataCategory: .personalIdentification,
            accessType: .search,
            fields: ["name", "email", "customerId"],
            purpose: "Kundensuche: \(query)"
        )

        // If query is empty, return all customers
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedQuery.isEmpty {
            return mockCustomers.map { mapCustomerToSearchResult($0) }
        }

        let lowercasedQuery = trimmedQuery.lowercased()
        return mockCustomers.compactMap { customer in
            let matches = customer.fullName.lowercased().contains(lowercasedQuery) ||
                          customer.email.lowercased().contains(lowercasedQuery) ||
                          customer.customerId.lowercased().contains(lowercasedQuery)

            guard matches else { return nil }
            return mapCustomerToSearchResult(customer)
        }
    }

    func getCustomerProfile(customerId: String) async throws -> CustomerProfile? {
        try await validatePermission(.viewCustomerProfile)

        guard let customer = mockCustomers.first(where: { $0.customerId == customerId }) else {
            return nil
        }

        await logDataAccess(
            dataCategory: .personalIdentification,
            accessType: .read,
            fields: ["profile"],
            purpose: "Kundenprofil anzeigen",
            customerId: customerId
        )

        await auditService.logViewAction(
            agentId: currentAgentId,
            agentRole: currentAgentRole,
            customerId: customerId,
            viewedData: "Kundenprofil"
        )

        return customer
    }

    // MARK: - Customer Data Access

    func getCustomerInvestments(customerId: String) async throws -> [CustomerInvestmentSummary] {
        try await validatePermission(.viewCustomerInvestments)

        await logDataAccess(
            dataCategory: .investmentData,
            accessType: .read,
            fields: ["investments"],
            purpose: "Investments anzeigen",
            customerId: customerId
        )

        // Fetch real investments if service is available
        if let investmentService = investmentService {
            let realInvestments = investmentService.getInvestments(for: customerId)
            logger.info("📊 CSR: Looking up investments for userId='\(customerId)', found \(realInvestments.count) real investments")
            if !realInvestments.isEmpty {
                return realInvestments.map { investment in
                    CustomerInvestmentSummary(
                        id: investment.id,
                        investmentNumber: "INV-\(investment.sequenceNumber ?? 0)",
                        traderName: investment.traderName,
                        amount: investment.amount,
                        currentValue: investment.currentValue,
                        returnPercentage: investment.performance,
                        status: mapInvestmentStatus(investment.status, reservationStatus: investment.reservationStatus),
                        createdAt: investment.createdAt,
                        completedAt: investment.completedAt
                    )
                }
            }
        } else {
            logger.warning("⚠️ CSR: investmentService not available - cannot fetch real investments")
        }

        // Fall back to mock data if no real investments found
        logger.info("📊 CSR: Using mock investments for userId='\(customerId)'")
        return CustomerSupportMockData.createMockInvestments(for: customerId)
    }

    func getCustomerTrades(customerId: String) async throws -> [CustomerTradeSummary] {
        try await validatePermission(.viewCustomerTrades)

        await logDataAccess(
            dataCategory: .tradingData,
            accessType: .read,
            fields: ["trades"],
            purpose: "Trades anzeigen",
            customerId: customerId
        )

        // Fetch real trades if service is available
        if let tradeLifecycleService = tradeLifecycleService {
            let allTrades = tradeLifecycleService.completedTrades
            let traderTrades = allTrades.filter { $0.traderId == customerId }
            logger.info("📈 CSR: Looking up trades for userId='\(customerId)', found \(traderTrades.count) real trades (from \(allTrades.count) total)")
            if !traderTrades.isEmpty {
                return traderTrades.map { trade in
                    CustomerTradeSummary(
                        id: trade.id,
                        tradeNumber: String(format: "T-%03d", trade.tradeNumber),
                        symbol: trade.symbol,
                        direction: "Buy",
                        quantity: Int(trade.buyOrder.quantity),
                        entryPrice: trade.buyOrder.price,
                        currentPrice: trade.sellOrders.last?.price,
                        profitLoss: trade.calculatedProfit,
                        status: mapTradeStatus(trade.status),
                        createdAt: trade.createdAt
                    )
                }
            }
        } else {
            logger.warning("⚠️ CSR: tradeLifecycleService not available - cannot fetch real trades")
        }

        // Fall back to mock data if no real trades found
        logger.info("📈 CSR: Using mock trades for userId='\(customerId)'")
        return CustomerSupportMockData.createMockTrades(for: customerId)
    }

    // MARK: - Status Mapping Helpers

    private func mapInvestmentStatus(_ status: InvestmentStatus, reservationStatus: InvestmentReservationStatus) -> String {
        switch reservationStatus {
        case .reserved:
            return "submitted"
        case .active, .executing:
            return "active"
        case .closed, .completed:
            return "completed"
        case .cancelled:
            return "cancelled"
        }
    }

    private func mapTradeStatus(_ status: TradeStatus) -> String {
        switch status {
        case .pending:
            return "open"
        case .active:
            return "active"
        case .completed:
            return "completed"
        case .cancelled:
            return "cancelled"
        }
    }

    func getCustomerDocuments(customerId: String) async throws -> [CustomerDocumentSummary] {
        try await validatePermission(.viewCustomerDocuments)

        await logDataAccess(
            dataCategory: .identityDocuments,
            accessType: .read,
            fields: ["documents"],
            purpose: "Dokumente anzeigen",
            customerId: customerId
        )

        return CustomerSupportMockData.createMockDocuments(for: customerId)
    }

    func getCustomerKYCStatus(customerId: String) async throws -> CustomerKYCStatus {
        try await validatePermission(.viewCustomerKYCStatus)

        await logDataAccess(
            dataCategory: .kycAmlData,
            accessType: .read,
            fields: ["kyc_status"],
            purpose: "KYC-Status anzeigen",
            customerId: customerId
        )

        guard let customer = mockCustomers.first(where: { $0.customerId == customerId }) else {
            throw CustomerSupportError.customerNotFound
        }

        return CustomerKYCStatus(
            customerId: customerId,
            overallStatus: customer.isKYCCompleted ? .complete : .inProgress,
            emailVerified: customer.isEmailVerified,
            identityVerified: customer.identificationConfirmed,
            addressVerified: customer.addressConfirmed,
            riskClassification: 3,
            lastUpdated: Date(),
            pendingDocuments: customer.isKYCCompleted ? [] : ["Personalausweis"],
            notes: nil
        )
    }

    // MARK: - Private Helpers

    private func mapCustomerToSearchResult(_ customer: CustomerProfile) -> CustomerSearchResult {
        CustomerSearchResult(
            id: customer.id,
            customerId: customer.customerId,
            fullName: customer.fullName,
            email: customer.email,
            role: customer.role,
            isKYCCompleted: customer.isKYCCompleted,
            accountStatus: customer.accountStatus,
            lastActivity: customer.lastLoginDate
        )
    }
}

