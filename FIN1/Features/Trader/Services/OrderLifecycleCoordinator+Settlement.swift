import Foundation

// MARK: - Backend settlement sync, paired-buy documents, credit note fallback

extension OrderLifecycleCoordinator {

    /// Checks if the backend has already settled this trade (AccountStatement entries + documents created).
    func checkBackendSettlement(for trade: Trade) async -> Bool {
        guard let settlementAPI = settlementAPIService else { return false }
        return await settlementAPI.isTradeSettledByBackend(tradeId: trade.id)
    }

    /// Resolves the visible TRADER leg after `executePairedBuy` (depot row), not the MIRROR_POOL accounting leg.
    func resolveTraderLegTrade(forBuyOrderId orderId: String) -> Trade? {
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
    func syncPairedBuySettlementDocuments(for order: Order, traderTrade: Trade) async {
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

    func refreshInvestmentsAfterPoolMirrorActivation() async {
        guard let investmentService else { return }
        if let currentUser = userService.currentUser, currentUser.role == .trader {
            await investmentService.fetchFromBackendForTrader(user: currentUser)
        }
        await investmentService.checkAndUpdateInvestmentCompletion()
        NotificationCenter.default.post(name: .investmentStatusUpdated, object: nil)
    }

    func legacyBuyBlockedByPoolMirrorRequirement(for order: Order) async -> Bool {
        guard let investmentService else { return false }

        if let currentUser = userService.currentUser, currentUser.role == .trader {
            await investmentService.fetchFromBackendForTrader(user: currentUser)
        }

        let dataProvider = BuyOrderInvestmentDataProvider(
            investmentService: investmentService,
            traderDataService: nil
        )
        let localPoolCapital = TraderPairedBuyPlacementGuard.localReservedPoolCapital(
            investmentService: investmentService,
            investmentDataProvider: dataProvider,
            currentUser: self.userService.currentUser
        )

        let parseAPIClient = (configurationService as? ConfigurationService)?.getParseAPIClient()
        let investmentAPIService = parseAPIClient.map { InvestmentAPIService(apiClient: $0) }
        let currentUser = self.userService.currentUser

        if let blockReason = await TraderPairedBuyPlacementGuard.blockReason(
            mirrorPoolQuantity: 0,
            localReservedPoolCapital: localPoolCapital,
            parseAPIClient: parseAPIClient,
            investmentAPIService: investmentAPIService,
            traderId: order.traderId,
            traderUsername: currentUser?.username,
            traderName: currentUser.map { "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces) }
        ) {
            print("⚠️ OrderLifecycleCoordinator: legacy buy blocked — \(blockReason)")
            return true
        }

        return false
    }

    /// Merges backend buy-order Belege (order invoice, Kaufabrechnung, Gebühren) into the inbox — no client duplicate.
    func syncBuyOrderDocumentsFromBackend(for order: Order, trade: Trade) async {
        guard let settlementAPI = settlementAPIService,
              let documentService = documentService else {
            print("ℹ️ OrderLifecycleCoordinator: skip backend buy-doc sync — settlement API unavailable")
            return
        }

        do {
            let settlement = try await settlementAPI.fetchTradeSettlement(tradeId: trade.id)
            let docs = Document.inboxEligible(from: settlement.documents)
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

    /// After each sell leg (including partial sells), merge TSC/CN rows from the backend into the inbox.
    /// `trade.isCompleted` is false for partial sells, but the server already books per-leg Belege.
    func syncTraderSellDocumentsIntoInboxAfterSell(for trade: Trade) async {
        if await self.checkBackendSettlement(for: trade) {
            await self.syncSettlementDocumentsIntoInbox(for: trade)
            return
        }
        NotificationCenter.default.post(
            name: .userDocumentInboxShouldRefresh,
            object: nil,
            userInfo: ["force": true]
        )
    }

    /// Merges backend `Document` rows (collection bill, credit note, …) into the notifications inbox cache.
    func syncSettlementDocumentsIntoInbox(for trade: Trade) async {
        guard let settlementAPI = settlementAPIService,
              let documentService = documentService else { return }

        do {
            let settlement = try await settlementAPI.fetchTradeSettlement(tradeId: trade.id)
            let docs = Document.inboxEligible(from: settlement.documents)
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

    /// Generates a Credit Note document if commission was earned (local fallback when backend unsettled).
    func generateCreditNoteIfCommissionExists(for trade: Trade) async {
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
