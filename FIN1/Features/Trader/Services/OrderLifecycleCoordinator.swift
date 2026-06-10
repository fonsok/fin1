import Combine
import Foundation

// MARK: - Order Lifecycle Coordinator Implementation
/// Handles order lifecycle management and business logic.
/// Split: `OrderLifecycleCoordinator+Completion/BuyCompletion/SellCompletion/Settlement.swift`
@MainActor
final class OrderLifecycleCoordinator: OrderLifecycleCoordinatorProtocol {

    // MARK: - Dependencies (internal for +extension files in this module)

    let orderManagementService: any OrderManagementServiceProtocol
    let orderStatusSimulationService: any OrderStatusSimulationServiceProtocol
    let tradingNotificationService: any TradingNotificationServiceProtocol
    let tradeLifecycleService: any TradeLifecycleServiceProtocol
    let tradeMatchingService: any TradeMatchingServiceProtocol
    let cashBalanceService: any CashBalanceServiceProtocol
    let investmentActivationService: (any InvestmentActivationServiceProtocol)?
    let profitDistributionService: (any ProfitDistributionServiceProtocol)?
    let poolTradeParticipationService: (any PoolTradeParticipationServiceProtocol)?
    let userService: any UserServiceProtocol
    let investmentService: (any InvestmentServiceProtocol)?
    let documentService: (any DocumentServiceProtocol)?
    let configurationService: any ConfigurationServiceProtocol
    let investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?
    let commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    let auditLoggingService: (any AuditLoggingServiceProtocol)?
    let settlementAPIService: (any SettlementAPIServiceProtocol)?

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
        configurationService: any ConfigurationServiceProtocol,
        investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)? = nil,
        commissionCalculationService: (any CommissionCalculationServiceProtocol)? = nil,
        auditLoggingService: (any AuditLoggingServiceProtocol)? = nil,
        settlementAPIService: (any SettlementAPIServiceProtocol)? = nil
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
        self.settlementAPIService = settlementAPIService
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
            denomination: parameters.denomination,
            isMirrorPoolOrder: parameters.isMirrorPoolOrder
        )

        self.orderStatusSimulationService.startOrderStatusProgression(buyOrder.id) { [weak self] status, order in
            await self?.handleOrderCompletion(orderId: order.id, status: status, order: order)
        }

        return buyOrder
    }

    /// Registers the TRADER leg of a paired buy for UI status progression (mirror leg stays server-only).
    func registerPairedBuyTraderOrder(_ order: Order, pairExecutionId: String) async {
        await self.orderManagementService.addOrderToActiveOrders(order)
        self.orderManagementService.registerPairedBuyExecutionLink(
            orderId: order.id,
            pairExecutionId: pairExecutionId
        )

        self.orderStatusSimulationService.startOrderStatusProgression(order.id) { [weak self] status, updatedOrder in
            await self?.handleOrderCompletion(orderId: updatedOrder.id, status: status, order: updatedOrder)
        }
    }

    func placeSellOrder(symbol: String, quantity: Int, price: Double) async throws -> OrderSell {
        return try await self.orderManagementService.placeSellOrder(symbol: symbol, quantity: quantity, price: price)
    }

    func submitOrder(_ order: OrderSell) async throws {
        let tradeId = self.resolveTradeId(for: order)
        if tradeId == nil {
            print("⚠️ OrderLifecycleCoordinator: No tradeId resolved for sell — originalHoldingId: \(order.originalHoldingId ?? "nil")")
        }

        let persistedSellOrder: OrderSell
        do {
            persistedSellOrder = try await self.orderManagementService.persistSellOrder(order, tradeId: tradeId)
        } catch {
            print("❌ OrderLifecycleCoordinator: Failed to persist sell order — \(error.localizedDescription)")
            throw error
        }

        if let tradeId {
            self.orderManagementService.registerSellOrderTradeLink(orderId: persistedSellOrder.id, tradeId: tradeId)
        }

        let genericOrder = Order(
            id: persistedSellOrder.id,
            traderId: persistedSellOrder.traderId,
            symbol: persistedSellOrder.symbol,
            description: persistedSellOrder.description,
            type: .sell,
            quantity: persistedSellOrder.quantity,
            price: persistedSellOrder.price,
            totalAmount: persistedSellOrder.totalAmount,
            createdAt: persistedSellOrder.createdAt,
            executedAt: persistedSellOrder.executedAt,
            confirmedAt: persistedSellOrder.confirmedAt,
            updatedAt: persistedSellOrder.updatedAt,
            optionDirection: persistedSellOrder.optionDirection,
            underlyingAsset: persistedSellOrder.underlyingAsset,
            wkn: persistedSellOrder.wkn,
            category: persistedSellOrder.category,
            strike: persistedSellOrder.strike,
            orderInstruction: persistedSellOrder.orderInstruction,
            limitPrice: persistedSellOrder.limitPrice,
            originalHoldingId: persistedSellOrder.originalHoldingId,
            status: "submitted"
        )

        await self.orderManagementService.addOrderToActiveOrders(genericOrder)

        if let auditLoggingService = auditLoggingService {
            let userId = self.userService.currentUser?.id ?? order.traderId
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

            Task {
                await auditLoggingService.logComplianceEvent(complianceEvent)
            }
        }

        self.orderStatusSimulationService.startOrderStatusProgression(persistedSellOrder.id) { [weak self] status, order in
            await self?.handleOrderCompletion(orderId: order.id, status: status, order: order)
        }

        await self.tradingNotificationService.sendOrderStatusNotification(orderId: persistedSellOrder.id, status: "submitted")
    }

    /// Maps sell order `originalHoldingId` (buy order id or trade id) to Parse Trade objectId.
    func resolveTradeId(for sellOrder: OrderSell) -> String? {
        guard let holdingId = sellOrder.originalHoldingId else { return nil }
        let trades = self.tradeLifecycleService.completedTrades.filter { $0.traderId == sellOrder.traderId }
        let depotTrades = TraderDepotTradeFilter.tradesForDepotDisplay(trades)
        if let trade = depotTrades.first(where: { $0.buyOrder.id == holdingId || $0.id == holdingId }) {
            return trade.id
        }
        return nil
    }

    func cancelOrder(_ orderId: String) async throws {
        self.orderStatusSimulationService.stopOrderStatusProgression(orderId)
        try await self.orderManagementService.cancelOrder(orderId)

        if let auditLoggingService = auditLoggingService {
            let userId = self.userService.currentUser?.id ?? "unknown"
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
        try await self.orderManagementService.updateOrderStatus(orderId, status: status)
    }

    /// Re-attach status progression after depot reload / app resume (paired-buy orders stuck at executed).
    func resumeOrderProgressionForActiveOrders() {
        for order in self.orderManagementService.activeOrders {
            let normalized = order.status.lowercased()
            guard normalized != "completed", normalized != "cancelled" else { continue }

            if let pairId = order.pairExecutionId?.trimmingCharacters(in: .whitespacesAndNewlines),
               !pairId.isEmpty {
                self.orderManagementService.registerPairedBuyExecutionLink(
                    orderId: order.id,
                    pairExecutionId: pairId
                )
            }

            self.orderStatusSimulationService.startOrderStatusProgression(order.id) { [weak self] status, updatedOrder in
                await self?.handleOrderCompletion(orderId: updatedOrder.id, status: status, order: updatedOrder)
            }
        }
    }
}
