import Combine
import Foundation

// MARK: - Order Lifecycle Coordinator Implementation
/// Handles order lifecycle management and business logic
/// Focused on order creation, status progression, and completion
@MainActor
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
    private let configurationService: any ConfigurationServiceProtocol
    private let investorGrossProfitService: (any InvestorGrossProfitServiceProtocol)?
    private let commissionCalculationService: (any CommissionCalculationServiceProtocol)?
    private let auditLoggingService: (any AuditLoggingServiceProtocol)?
    private let settlementAPIService: (any SettlementAPIServiceProtocol)?

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

        // Start status progression simulation
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

        // Add the sell order to active orders (Parse objectId when backend save succeeded)
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

        // Also add to OrderManagementService for status progression
        await self.orderManagementService.addOrderToActiveOrders(genericOrder)

        // ✅ MiFID II Compliance: Log sell order placement
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

            // Log asynchronously - don't block order placement if logging fails
            Task {
                await auditLoggingService.logComplianceEvent(complianceEvent)
            }
        }

        // Start status progression simulation for sell orders
        self.orderStatusSimulationService.startOrderStatusProgression(persistedSellOrder.id) { [weak self] status, order in
            await self?.handleOrderCompletion(orderId: order.id, status: status, order: order)
        }

        // Send notification
        await self.tradingNotificationService.sendOrderStatusNotification(orderId: persistedSellOrder.id, status: "submitted")
    }

    /// Maps sell order `originalHoldingId` (buy order id or trade id) to Parse Trade objectId.
    private func resolveTradeId(for sellOrder: OrderSell) -> String? {
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

        // ✅ MiFID II Compliance: Log order cancellation
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

    // MARK: - Order Completion Handling

    func handleOrderCompletion(orderId: String, status: String, order: Order) async {
        // Paired buy: server settlement when UI reaches executed (both legs transition together on Parse).
        if order.type == .buy,
           status == "executed",
           self.orderManagementService.pairedBuyExecutionId(for: orderId) != nil {
            do {
                try await self.orderManagementService.finalizePairedBuyExecution(for: orderId) // → commitPairedBuyExecution on server
                try? await self.tradeLifecycleService.refreshCompletedTrades()
            } catch {
                print("❌ OrderLifecycleCoordinator: Paired buy finalize failed — \(error.localizedDescription)")
                self.orderManagementService.reportOrderStatusFailure(
                    "Pool-Mirror konnte nicht ausgeführt werden: \(error.localizedDescription)"
                )
                self.orderStatusSimulationService.stopOrderStatusProgression(orderId)
            }
        }

        // Sell: sync `executed` to backend so Order afterSave updates Trade + ledger
        if order.type == .sell && status == "executed" {
            await self.orderManagementService.syncActiveOrderToBackend(orderId)
            try? await self.tradeLifecycleService.refreshCompletedTrades()
        }

        // Send notification
        await self.tradingNotificationService.sendOrderStatusNotification(orderId: orderId, status: status)

        // Handle order completion based on order type
        if status == "completed" {
            // ✅ MiFID II Compliance: Log order completion
            if let auditLoggingService = auditLoggingService {
                let userId = self.userService.currentUser?.id ?? order.traderId
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
                await self.handleBuyOrderCompletion(orderId: orderId, order: order)
            } else if order.type == .sell {
                await self.handleSellOrderCompletion(orderId: orderId, order: order)
            }
        }
    }

    private func handleBuyOrderCompletion(orderId: String, order: Order) async {
        // Paired buy: trades/invoices/bookings + pool mirror activation are server SSOT — no local duplicate.
        if self.orderManagementService.pairedBuyExecutionId(for: orderId) != nil {
            try? await self.tradeLifecycleService.refreshCompletedTrades()
            if let trade = self.resolveTraderLegTrade(forBuyOrderId: orderId) {
                if order.isMirrorPoolOrder != true {
                    await self.cashBalanceService.processBuyOrderExecution(amount: order.totalAmount)
                }
                await self.tradingNotificationService.showBuyConfirmation(for: trade)
                await self.syncPairedBuySettlementDocuments(for: order, traderTrade: trade)
            } else {
                print(
                    "⚠️ OrderLifecycleCoordinator: paired buy completed but TRADER leg trade not found for order \(orderId)"
                )
            }
            await self.refreshInvestmentsAfterPoolMirrorActivation()
            await self.orderManagementService.removeActiveOrder(orderId)
            return
        }

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
            denomination: order.denomination,
            isMirrorPoolOrder: order.isMirrorPoolOrder
        )

        try? await self.tradeLifecycleService.refreshCompletedTrades()
        let serverLinkedTrade = self.tradeLifecycleService.completedTrades.first(where: { $0.buyOrder.id == orderId })
        let trade: Trade?
        if let serverLinkedTrade {
            trade = serverLinkedTrade
        } else {
            trade = try? await self.tradeLifecycleService.createNewTrade(buyOrder: buyOrder)
        }

        if let trade = trade {
            // Trader cash debit belongs only to trader-originated buy orders.
            if order.isMirrorPoolOrder != true {
                await self.cashBalanceService.processBuyOrderExecution(amount: order.totalAmount)
            }

            // Pool mirror activation (RSV→1592) is server-only via executePairedBuy → MIRROR_POOL Order leg.
            // Do not duplicate activation locally — prevents double splits per investor.
            if order.isMirrorPoolOrder == true {
                print(
                    "ℹ️ OrderLifecycleCoordinator: skip local pool activation for mirror order \(order.id) — server SSOT"
                )
            }

            // Show buy confirmation
            await self.tradingNotificationService.showBuyConfirmation(for: trade)

            let bookedByBackend = await self.checkBackendSettlement(for: trade)
            if bookedByBackend {
                await self.syncBuyOrderDocumentsFromBackend(for: order, trade: trade)
            } else {
                await self.tradingNotificationService.generateInvoiceAndNotification(
                    for: order,
                    tradeId: trade.id,
                    tradeNumber: trade.tradeNumber
                )
            }

            // Remove completed order from ongoing (activeOrders)
            await self.orderManagementService.removeActiveOrder(orderId)
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
        let allTrades = self.tradeLifecycleService.completedTrades
        let trades = allTrades.filter { $0.traderId == sellOrder.traderId }
        print(
            "🔍 DEBUG: Looking for trade match - trades count: \(trades.count) (filtered from \(allTrades.count) total), sellOrder.traderId: \(sellOrder.traderId), originalHoldingId: \(sellOrder.originalHoldingId ?? "nil")"
        )

        let updatedTrade = await tradeMatchingService.findAndUpdateTradeWithSellOrder(
            sellOrder: sellOrder,
            trades: trades,
            tradeLifecycleService: self.tradeLifecycleService
        )

        print("🔍 DEBUG: Trade matching result - updatedTrade: \(updatedTrade?.id ?? "nil")")

        // Refresh trades from backend (server Order trigger may have updated Trade already)
        try? await self.tradeLifecycleService.refreshCompletedTrades()

        // FIRST: Remove completed order from ongoing (activeOrders) before showing overlay
        await self.orderManagementService.removeActiveOrder(orderId)

        // Notify depot view model about completed sell order (to refresh holdings)
        await MainActor.run {
            NotificationCenter.default.post(
                name: .sellOrderCompleted,
                object: nil,
                userInfo: ["order": order]
            )
        }

        let latestTrade = self.tradeLifecycleService.completedTrades.first(where: { $0.id == updatedTrade?.id })
            ?? updatedTrade

        if let trade = latestTrade ?? updatedTrade {
            if TraderDepotTradeFilter.isPoolMirrorLeg(trade) {
                print("ℹ️ OrderLifecycleCoordinator: skip trader completion docs for MIRROR_POOL leg")
                await self.tradingNotificationService.showSellConfirmation(for: trade)
                return
            }

            await self.cashBalanceService.processSellOrderExecution(amount: order.totalAmount)

            // Generate invoice and send notification for sell order with trade ID and trade number
            await self.tradingNotificationService.generateInvoiceAndNotification(
                for: order,
                tradeId: trade.id,
                tradeNumber: trade.tradeNumber
            )

            // Check if trade is now fully completed and generate Collection Bill
            if trade.isCompleted {
                let settledByBackend = await self.checkBackendSettlement(for: trade)

                if settledByBackend {
                    print("🎯 Trade #\(trade.tradeNumber) settled by backend — syncing settlement documents to inbox")
                    await self.syncSettlementDocumentsIntoInbox(for: trade)
                } else if let documentService = documentService,
                          documentService.documentExists(for: trade.id, ofType: .traderCollectionBill) {
                    print("ℹ️ Trade #\(trade.tradeNumber) completion logic already ran; skipping duplicate run.")
                    await self.tradingNotificationService.showSellConfirmation(for: trade)
                    return
                } else {
                    print("🎯 Trade #\(trade.tradeNumber) is now fully completed - generating local documents")
                    await self.tradingNotificationService.generateCollectionBillDocument(for: trade)
                    await self.generateCreditNoteIfCommissionExists(for: trade)
                    NotificationCenter.default.post(
                        name: .userDocumentInboxShouldRefresh,
                        object: nil,
                        userInfo: ["force": true]
                    )
                }

                // Distribute profit to investors if trade involved pool capital
                if let profitDistributionService = profitDistributionService, !settledByBackend {
                    _ = await profitDistributionService.distributeProfit(for: trade, order: order)
                }

                // Mark pool as completed for investments that participated in this trade
                if let investmentService = investmentService, let poolTradeParticipationService = poolTradeParticipationService {
                    // Find participations for this trade and complete only those investments' pools
                    let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)
                    if participations.isEmpty {
                        print("ℹ️ No pool participations recorded for trade \(trade.id); fallback to trader-based completion")
                        await investmentService.markInvestmentAsCompleted(for: trade.traderId)
                    } else {
                        for participation in participations {
                            await investmentService.markActiveInvestmentAsCompleted(for: participation.investmentId)
                            print(
                                "✅ OrderLifecycleCoordinator: Marked completed pool for investment \(participation.investmentId) (trade \(trade.id))"
                            )
                        }
                    }
                } else {
                    print("⚠️ OrderLifecycleCoordinator: services unavailable - pool completion skipped!")
                }
            }

            // LAST: Show sell confirmation with the updated Trade (after depot is fully updated)
            await self.tradingNotificationService.showSellConfirmation(for: trade)
        } else {
            // Generate invoice even if no trade found (no trade ID available)
            await self.tradingNotificationService.generateInvoiceAndNotification(for: order, tradeId: nil, tradeNumber: nil)
        }
    }

    // MARK: - Backend Settlement Check

    /// Checks if the backend has already settled this trade (AccountStatement entries + documents created)
    private func checkBackendSettlement(for trade: Trade) async -> Bool {
        guard let settlementAPI = settlementAPIService else { return false }
        return await settlementAPI.isTradeSettledByBackend(tradeId: trade.id)
    }

    /// Resolves the visible TRADER leg after `executePairedBuy` (depot row), not the MIRROR_POOL accounting leg.
    private func resolveTraderLegTrade(forBuyOrderId orderId: String) -> Trade? {
        if let direct = self.tradeLifecycleService.completedTrades.first(where: { $0.buyOrder.id == orderId }) {
            return direct
        }
        guard let pairExecutionId = self.orderManagementService.pairedBuyExecutionId(for: orderId) else {
            return nil
        }
        return self.tradeLifecycleService.completedTrades.first { trade in
            trade.pairExecutionId == pairExecutionId && !TraderDepotTradeFilter.isPoolMirrorLeg(trade)
        }
    }

    /// Merges trader buy Belege plus linked pool-mirror eigenbeleg docs (server attaches mirror trade docs).
    private func syncPairedBuySettlementDocuments(for order: Order, traderTrade: Trade) async {
        await self.syncBuyOrderDocumentsFromBackend(for: order, trade: traderTrade)

        if let pairExecutionId = traderTrade.pairExecutionId ?? self.orderManagementService.pairedBuyExecutionId(for: order.id),
           let mirrorTrade = self.tradeLifecycleService.completedTrades.first(where: {
               $0.pairExecutionId == pairExecutionId && TraderDepotTradeFilter.isPoolMirrorLeg($0)
           }) {
            await self.syncBuyOrderDocumentsFromBackend(for: order, trade: mirrorTrade)
            print(
                "📄 Paired buy \(order.id): synced pool-mirror documents for trade #\(mirrorTrade.tradeNumber)"
            )
        }
    }

    private func refreshInvestmentsAfterPoolMirrorActivation() async {
        guard let investmentService else { return }
        await investmentService.checkAndUpdateInvestmentCompletion()
        NotificationCenter.default.post(name: .investmentStatusUpdated, object: nil)
    }

    /// Merges backend buy-order Belege (order invoice, Kaufabrechnung, Gebühren) into the inbox — no client duplicate.
    private func syncBuyOrderDocumentsFromBackend(for order: Order, trade: Trade) async {
        guard let settlementAPI = settlementAPIService,
              let documentService = documentService else {
            print("ℹ️ OrderLifecycleCoordinator: skip backend buy-doc sync — settlement API unavailable")
            return
        }

        do {
            let settlement = try await settlementAPI.fetchTradeSettlement(tradeId: trade.id)
            let docs = settlement.documents.map { Document(backendSettlementDocument: $0) }
            documentService.mergeDocuments(docs)
            NotificationCenter.default.post(
                name: .userDocumentInboxShouldRefresh,
                object: nil,
                userInfo: ["force": true]
            )
            print(
                "📄 Buy order \(order.id) / trade #\(trade.tradeNumber): merged \(docs.count) backend document(s) "
                    + "(\(docs.compactMap(\.documentNumber).joined(separator: ", ")))"
            )
        } catch {
            print(
                "⚠️ Buy order \(order.id): failed to sync backend documents: \(error.localizedDescription)"
            )
        }
    }

    /// Merges backend `Document` rows (collection bill, credit note, …) into the notifications inbox cache.
    private func syncSettlementDocumentsIntoInbox(for trade: Trade) async {
        guard let settlementAPI = settlementAPIService,
              let documentService = documentService else { return }

        do {
            let settlement = try await settlementAPI.fetchTradeSettlement(tradeId: trade.id)
            let docs = settlement.documents.map { Document(backendSettlementDocument: $0) }
            documentService.mergeDocuments(docs)
            NotificationCenter.default.post(
                name: .userDocumentInboxShouldRefresh,
                object: nil,
                userInfo: ["force": true]
            )
            print(
                "📄 Trade #\(trade.tradeNumber): merged \(docs.count) backend settlement document(s) "
                    + "(\(docs.map(\.type.rawValue).joined(separator: ", ")))"
            )
        } catch {
            print("⚠️ Trade #\(trade.tradeNumber): failed to sync settlement documents: \(error.localizedDescription)")
        }
    }

    // MARK: - Credit Note Generation (local fallback)

    /// Generates a Credit Note document if commission was earned from the trade
    /// Uses centralized gross-profit-based calculation to ensure consistency with Credit Note detail view
    /// - Parameter trade: The completed trade
    private func generateCreditNoteIfCommissionExists(for trade: Trade) async {
        // Phase 3: Try backend settlement for authoritative commission values
        if let settlementAPI = settlementAPIService {
            do {
                let settlement = try await settlementAPI.fetchTradeSettlement(tradeId: trade.id)
                let bookedCommission = TraderCommissionSettlementResolver.totalCommission(from: settlement)
                if settlement.isSettledByBackend, bookedCommission > 0 {
                    print("📄 CreditNote: Using backend-authoritative commission for trade #\(trade.tradeNumber)")
                    await self.tradingNotificationService.generateCreditNoteDocument(
                        for: trade,
                        commissionAmount: bookedCommission,
                        grossProfit: settlement.grossProfit
                    )
                    return
                }
            } catch {
                print("⚠️ CreditNote: Backend fetch failed: \(error.localizedDescription)")
            }
        }

        if self.configurationService.investorMonetaryServerOnly {
            print("⚠️ CreditNote: investorMonetaryServerOnly — no local fallback")
            return
        }

        // Fallback: local estimation (dev/preview only)
        guard let poolTradeParticipationService,
              let investmentService,
              let investorGrossProfitService,
              let commissionCalculationService else {
            print("📄 CreditNote: Required services unavailable - skipping")
            return
        }

        let participations = poolTradeParticipationService.getParticipations(forTradeId: trade.id)
        guard !participations.isEmpty else {
            print("📄 CreditNote: No participations for trade #\(trade.tradeNumber) - no commission")
            return
        }

        let commissionRate = self.configurationService.effectiveCommissionRate
        let participationsByInvestment = Dictionary(grouping: participations) { $0.investmentId }
        let allInvestments = investmentService.investments

        var totalCommission: Double = 0.0
        var totalGrossProfit: Double = 0.0

        for (investmentId, _) in participationsByInvestment {
            guard allInvestments.first(where: { $0.id == investmentId }) != nil else { continue }
            do {
                let investorGrossProfit = try await investorGrossProfitService.getGrossProfit(
                    for: investmentId, tradeId: trade.id
                )
                let investorCommission = try await commissionCalculationService.calculateCommissionForInvestor(
                    investmentId: investmentId, tradeId: trade.id, commissionRate: commissionRate
                )
                totalGrossProfit += investorGrossProfit
                totalCommission += investorCommission
            } catch {
                print("⚠️ CreditNote [local fallback]: Error for investment \(investmentId): \(error)")
            }
        }

        guard totalCommission > 0 else {
            print("📄 CreditNote: Commission is €0 for trade #\(trade.tradeNumber) - skipping")
            return
        }

        await self.tradingNotificationService.generateCreditNoteDocument(
            for: trade,
            commissionAmount: totalCommission,
            grossProfit: totalGrossProfit
        )
    }
}
