import Foundation
import Combine

// MARK: - Order Lifecycle Coordinator Implementation
/// Handles order lifecycle management and business logic
/// Focused on order creation, status progression, and completion
final class OrderLifecycleCoordinator: OrderLifecycleCoordinatorProtocol {

    // MARK: - Dependencies
    private let orderManagementService: any OrderManagementServiceProtocol
    private let orderStatusSimulationService: any OrderStatusSimulationServiceProtocol
    private let tradingNotificationService: any TradingNotificationServiceProtocol
    private let tradeLifecycleService: any TradeLifecycleServiceProtocol
    private let tradeMatchingService: any TradeMatchingServiceProtocol
    private let cashBalanceService: any CashBalanceServiceProtocol
    private let investmentActivationService: (any InvestmentActivationServiceProtocol)?
    private let profitDistributionService: (any ProfitDistributionServiceProtocol)?
    private let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    private let userService: any UserServiceProtocol
    private let investmentService: (any InvestmentServiceProtocol)?
    private let documentService: (any DocumentServiceProtocol)?
    private let configurationService: (any ConfigurationServiceProtocol)?
    private let investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?
    private let commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    private let auditLoggingService: (any AuditLoggingServiceProtocol)?

    // MARK: - Initialization
    init(
        orderManagementService: any OrderManagementServiceProtocol,
        orderStatusSimulationService: any OrderStatusSimulationServiceProtocol,
        tradingNotificationService: any TradingNotificationServiceProtocol,
        tradeLifecycleService: any TradeLifecycleServiceProtocol,
        tradeMatchingService: any TradeMatchingServiceProtocol,
        cashBalanceService: any CashBalanceServiceProtocol,
        investmentActivationService: (any InvestmentActivationServiceProtocol)? = nil,
        profitDistributionService: (any ProfitDistributionServiceProtocol)? = nil,
        poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)? = nil,
        userService: any UserServiceProtocol,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        documentService: (any DocumentServiceProtocol)? = nil,
        configurationService: (any ConfigurationServiceProtocol)? = nil,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil
    ) {
        self.orderManagementService = orderManagementService
        self.orderStatusSimulationService = orderStatusSimulationService
        self.tradingNotificationService = tradingNotificationService
        self.tradeLifecycleService = tradeLifecycleService
        self.tradeMatchingService = tradeMatchingService
        self.cashBalanceService = cashBalanceService
        self.investmentActivationService = investmentActivationService
        self.profitDistributionService = profitDistributionService
        self.poolTradeParticipationService = poolTradeParticipationService
        self.userService = userService
        self.investmentService = investmentService
        self.documentService = documentService
        self.configurationService = configurationService
        self.investorGrossProfitService = investorGrossProfitService
        self.commissionCalculationService = commissionCalculationService
        self.auditLoggingService = auditLoggingService
    }

    // MARK: - Order Management

    func placeBuyOrder(parameters: BuyOrderParameters) async throws -> OrderBuy {
        let buyOrder = try await orderManagementService.placeBuyOrder(
            symbol: parameters.symbol,
            quantity: parameters.quantity,
            price: parameters.price,
            optionDirection: parameters.optionDirection,
            description: parameters.description,
            orderInstruction: parameters.orderInstruction,
            limitPrice: parameters.limitPrice,
            strike: parameters.strike,
            subscriptionRatio: parameters.subscriptionRatio,
            denomination: parameters.denomination
        )

        // Start status progression simulation
        orderStatusSimulationService.startOrderStatusProgression(buyOrder.id) { [weak self] status, order in
            Task { @MainActor in
                await self?.handleOrderCompletion(orderId: order.id, status: status, order: order)
            }
        }

        return buyOrder
    }

    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell {
        return try await orderManagementService.placeSellOrder(symbol: symbol, quantity: quantity, price: price)
    }

    func submitOrder(_ order: OrderSell) async throws {
        // Add the sell order to active orders
        let genericOrder = Order(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            type: .sell,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            createdAt: order.createdAt,
            executedAt: order.executedAt,
            confirmedAt: order.confirmedAt,
            updatedAt: order.updatedAt,
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            originalHoldingId: order.originalHoldingId,
            status: "submitted"
        )

        // Also add to OrderManagementService for status progression
        await orderManagementService.addOrderToActiveOrders(genericOrder)

        // ✅ MiFID II Compliance: Log sell order placement
        if let auditLoggingService = auditLoggingService {
            let userId = userService.currentUser?.id ?? order.traderId
            let underlyingAsset = order.underlyingAsset ?? order.description
            let complianceEvent = ComplianceEvent(
                eventType: .orderPlaced,
                agentId: userId,
                customerId: userId,
                description: "Sell order placed: \(underlyingAsset) - \(order.quantity) @ €\(order.price.formatted(.number.precision(.fractionLength(2))))",
                severity: .medium,
                requiresReview: false,
                notes: "Order ID: \(order.id), Symbol: \(order.symbol), Total: €\(order.totalAmount.formatted(.number.precision(.fractionLength(2))))"
            )
            
            // Log asynchronously - don't block order placement if logging fails
            Task {
                await auditLoggingService.logComplianceEvent(complianceEvent)
            }
        }

        // Start status progression simulation for sell orders
        orderStatusSimulationService.startOrderStatusProgression(order.id) { [weak self] status, order in
            Task { @MainActor in
                await self?.handleOrderCompletion(orderId: order.id, status: status, order: order)
            }
        }

        // Send notification
        await tradingNotificationService.sendOrderStatusNotification(orderId: order.id, status: "submitted")
    }

    func cancelOrder(_ orderId: String) async throws {
        orderStatusSimulationService.stopOrderStatusProgression(orderId)
        try await orderManagementService.cancelOrder(orderId)
        
        // ✅ MiFID II Compliance: Log order cancellation
        if let auditLoggingService = auditLoggingService {
            let userId = userService.currentUser?.id ?? "unknown"
            let complianceEvent = ComplianceEvent(
                eventType: .orderCancelled,
                agentId: userId,
                customerId: userId,
                description: "Order cancelled: \(orderId)",
                severity: .low,
                requiresReview: false,
                notes: "Order ID: \(orderId)"
            )
            
            Task {
                await auditLoggingService.logComplianceEvent(complianceEvent)
            }
        }
    }

    func updateOrderStatus(_ orderId: String, status: String) async throws {
        try await orderManagementService.updateOrderStatus(orderId, status: status)
    }

    // MARK: - Order Completion Handling

    func handleOrderCompletion(orderId: String, status: String, order: Order) async {
        // Update the order status
        try? await orderManagementService.updateOrderStatus(orderId, status: status)

        // Send notification
        await tradingNotificationService.sendOrderStatusNotification(orderId: orderId, status: status)

        // Handle order completion based on order type
        if status == "completed" {
            // ✅ MiFID II Compliance: Log order completion
            if let auditLoggingService = auditLoggingService {
                let userId = userService.currentUser?.id ?? order.traderId
                let orderType = order.type == .buy ? "Buy" : "Sell"
                let underlyingAsset = order.underlyingAsset ?? order.description
                let complianceEvent = ComplianceEvent(
                    eventType: .orderCompleted,
                    agentId: userId,
                    customerId: userId,
                    description: "\(orderType) order completed: \(underlyingAsset) - \(order.quantity) @ €\(order.price.formatted(.number.precision(.fractionLength(2))))",
                    severity: .medium,
                    requiresReview: false,
                    notes: "Order ID: \(orderId), Symbol: \(order.symbol), Total: €\(order.totalAmount.formatted(.number.precision(.fractionLength(2))))"
                )
                
                Task {
                    await auditLoggingService.logComplianceEvent(complianceEvent)
                }
            }
            
            if order.type == .buy {
                await handleBuyOrderCompletion(orderId: orderId, order: order)
            } else if order.type == .sell {
                await handleSellOrderCompletion(orderId: orderId, order: order)
            }
        }
    }

    private func handleBuyOrderCompletion(orderId: String, order: Order) async {
        // Create OrderBuy from the completed order
        let buyOrder = OrderBuy(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: .completed,
            createdAt: order.createdAt,
            executedAt: order.executedAt,
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            subscriptionRatio: order.subscriptionRatio,
            denomination: order.denomination
        )

        // Create Trade from the completed buy order
        let trade = try? await tradeLifecycleService.createNewTrade(buyOrder: buyOrder)

        if let trade = trade {
            // Update cash balance (money goes out for buy order)
            await cashBalanceService.processBuyOrderExecution(amount: order.totalAmount)

            // Activate investments for this buy order
            if let investmentActivationService = investmentActivationService {
                _ = await investmentActivationService.activateInvestmentsForBuyOrder(order: order, trade: trade)
            }

            // Show buy confirmation
            await tradingNotificationService.showBuyConfirmation(for: trade)

            // Generate invoice and send notification with trade ID and trade number
            await tradingNotificationService.generateInvoiceAndNotification(for: order, tradeId: trade.id, tradeNumber: trade.tradeNumber)

            // Remove completed order from ongoing (activeOrders)
            try? await orderManagementService.cancelOrder(orderId)
        }
    }

    func handleSellOrderCompletion(orderId: String, order: Order) async {
        print("🔍 DEBUG: handleSellOrderCompletion - orderId: \(orderId), originalHoldingId: \(order.originalHoldingId ?? "nil")")

        // Create OrderSell from the completed order
        let sellOrder = OrderSell(
            id: order.id,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: .confirmed,
            createdAt: order.createdAt,
            executedAt: order.executedAt,
            confirmedAt: Date(),
            updatedAt: Date(),
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            originalHoldingId: order.originalHoldingId
        )

        // Find the existing Trade that contains this sell order
        // CRITICAL: Filter trades by trader ID to ensure sell order is matched to correct trader's trade
        let allTrades = tradeLifecycleService.completedTrades
        let trades = allTrades.filter { $0.traderId == sellOrder.traderId }
        print("🔍 DEBUG: Looking for trade match - trades count: \(trades.count) (filtered from \(allTrades.count) total), sellOrder.traderId: \(sellOrder.traderId), originalHoldingId: \(sellOrder.originalHoldingId ?? "nil")")

        let updatedTrade = await tradeMatchingService.findAndUpdateTradeWithSellOrder(
            sellOrder: sellOrder,
            trades: trades,
            tradeLifecycleService: tradeLifecycleService
        )

        print("🔍 DEBUG: Trade matching result - updatedTrade: \(updatedTrade?.id ?? "nil")")

        // FIRST: Remove completed order from ongoing (activeOrders) before showing overlay
        // This ensures the depot is updated before the success message is displayed
        try? await orderManagementService.cancelOrder(orderId)

        // Notify depot view model about completed sell order (to refresh holdings)
        await MainActor.run {
            NotificationCenter.default.post(
                name: .sellOrderCompleted,
                object: nil,
                userInfo: ["order": order]
            )
        }

        if let trade = updatedTrade {
            // Update cash balance (money comes in for sell order)
            await cashBalanceService.processSellOrderExecution(amount: order.totalAmount)

            // Generate invoice and send notification for sell order with trade ID and trade number
            await tradingNotificationService.generateInvoiceAndNotification(for: order, tradeId: trade.id, tradeNumber: trade.tradeNumber)

            // Check if trade is now fully completed and generate Collection Bill
            if trade.isCompleted {
                // RACE CONDITION FIX: Ensure completion logic runs only once per trade
                if let documentService = documentService, documentService.documentExists(for: trade.id, ofType: .traderCollectionBill) {
                    print("ℹ️ Trade #\(trade.tradeNumber) completion logic already ran; skipping duplicate run.")
                    // Still show the confirmation after depot is updated
                    await tradingNotificationService.showSellConfirmation(for: trade)
                    return
                }

                print("🎯 Trade #\(trade.tradeNumber) is now fully completed - generating Collection Bill")
                await tradingNotificationService.generateCollectionBillDocument(for: trade)

                // Distribute profit to investors if trade involved pots
                if let profitDistributionService = profitDistributionService {
                    _ = await profitDistributionService.distributeProfit(for: trade, order: order)

                    // Generate Credit Note document for trader commission
                    await generateCreditNoteIfCommissionExists(for: trade)
                }

                // Mark pool as completed for investments that participated in this trade
                if let investmentService = investmentService, let poolTradeParticipationService = poolTradeParticipationService {
                    // Find participations for this trade and complete only those investments' pools
                    let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)
                    if participations.isEmpty {
                        print("ℹ️ No pool participations recorded for trade \(trade.id); skipping completion")
                    } else {
                        for participation in participations {
                            await investmentService.markActiveInvestmentAsCompleted(for: participation.investmentId)
                            print("✅ OrderLifecycleCoordinator: Marked completed pool for investment \(participation.investmentId) (trade \(trade.id))")
                        }
                    }
                } else {
                    print("⚠️ OrderLifecycleCoordinator: services unavailable - pool completion skipped!")
                }
            }

            // LAST: Show sell confirmation with the updated Trade (after depot is fully updated)
            await tradingNotificationService.showSellConfirmation(for: trade)
        } else {
            // Generate invoice even if no trade found (no trade ID available)
            await tradingNotificationService.generateInvoiceAndNotification(for: order, tradeId: nil, tradeNumber: nil)
        }
    }

    // MARK: - Credit Note Generation

    /// Generates a Credit Note document if commission was earned from the trade
    /// Uses centralized gross-profit-based calculation to ensure consistency with Credit Note detail view
    /// - Parameter trade: The completed trade
    private func generateCreditNoteIfCommissionExists(for trade: Trade) async {
        // Require all calculation services - do not generate credit note with potentially incorrect values
        guard let poolTradeParticipationService = poolTradeParticipationService,
              let investmentService = investmentService,
              let investorGrossProfitService = investorGrossProfitService,
              let commissionCalculationService = commissionCalculationService else {
            print("📄 CreditNote: Required calculation services unavailable - skipping to avoid incorrect values")
            return
        }

        // Get participations for this trade
        let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)

        guard !participations.isEmpty else {
            print("📄 CreditNote: No investor participations for trade #\(trade.tradeNumber) - no commission")
            return
        }

        // Get commission rate from admin configuration (single source of truth)
        let commissionRate = configurationService?.effectiveCommissionRate ?? CalculationConstants.FeeRates.traderCommissionRate

        // Group participations by investment to calculate commission per investor
        let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }
        let allInvestments = investmentService.investments

        var totalCommission: Double = 0.0
        var totalGrossProfit: Double = 0.0

        // Calculate commission using centralized services (single source of truth)
        // This ensures stored values exactly match what Credit Note detail view displays
        for (investmentId, _) in participationsByInvestment {
            guard allInvestments.first(where: { $0.id == investmentId }) != nil else {
                continue
            }

            do {
                let investorGrossProfit = try await investorGrossProfitService.getGrossProfit(
                    for: investmentId,
                    tradeId: trade.id
                )
                let investorCommission = try await commissionCalculationService.calculateCommissionForInvestor(
                    investmentId: investmentId,
                    tradeId: trade.id,
                    commissionRate: commissionRate
                )
                totalGrossProfit += investorGrossProfit
                totalCommission += investorCommission
            } catch {
                print("⚠️ CreditNote: Error calculating commission for investment \(investmentId): \(error)")
            }
        }

        guard totalCommission > 0 else {
            print("📄 CreditNote: Commission is €0 for trade #\(trade.tradeNumber) - skipping")
            return
        }

        print("📄 CreditNote: Generating for trade #\(trade.tradeNumber)")
        print("   💰 Commission: €\(String(format: "%.2f", totalCommission))")
        print("   📊 Gross Profit: €\(String(format: "%.2f", totalGrossProfit))")

        // Generate the credit note document
        await tradingNotificationService.generateCreditNoteDocument(
            for: trade,
            commissionAmount: totalCommission,
            grossProfit: totalGrossProfit
        )
    }
}
