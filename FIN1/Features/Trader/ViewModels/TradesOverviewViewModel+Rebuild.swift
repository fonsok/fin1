import Foundation

@MainActor
extension TradesOverviewViewModel {
    func rebuildTrades() async {
        let (activeSnapshot, completedSnapshot) = self.getTradeSnapshots()
        self.hasActiveTrade = self.detectActiveTrade(activeSnapshot, completedSnapshot)

        let traderId = self.currentTraderId ?? ""
        await self.commissionCalculator.refreshCommissionCache(traderId: traderId)

        let (ongoingItems, completedItems) = await processTrades(completedSnapshot)
        self.updateTradeLists(ongoingItems, completedItems)

        filteringViewModel.updateTrades(ongoing: ongoingTrades, completed: completedTrades)
        await self.filterTrades(by: self.lastFilteredTimePeriod)

        let tableRows = self.createTableRows(from: filteringViewModel.filteredCompletedTrades)
        self.columnWidths = ColumnWidthCalculator.calculate(for: tableRows)

        let pendingCommissionTradeIds = completedItems
            .filter { $0.profitLoss > 0 && $0.commission <= 0 }
            .compactMap(\.tradeId)
        self.commissionCalculator.scheduleDeferredCommissionRefreshIfNeeded(
            traderId: traderId,
            tradeIds: pendingCommissionTradeIds
        ) { [weak self] in
            await self?.rebuildTradesWithoutDeferredScheduler()
        }
    }

    /// Rebuild without re-arming the deferred commission refresh (avoids recursive scheduler loops).
    private func rebuildTradesWithoutDeferredScheduler() async {
        let (activeSnapshot, completedSnapshot) = self.getTradeSnapshots()
        self.hasActiveTrade = self.detectActiveTrade(activeSnapshot, completedSnapshot)
        let traderId = self.currentTraderId ?? ""
        await self.commissionCalculator.refreshCommissionCache(traderId: traderId)
        let (ongoingItems, completedItems) = await processTrades(completedSnapshot)
        self.updateTradeLists(ongoingItems, completedItems)
        filteringViewModel.updateTrades(ongoing: ongoingTrades, completed: completedTrades)
        await self.filterTrades(by: self.lastFilteredTimePeriod)
        let tableRows = self.createTableRows(from: filteringViewModel.filteredCompletedTrades)
        self.columnWidths = ColumnWidthCalculator.calculate(for: tableRows)
    }

    func getTradeSnapshots() -> ([Order], [Trade]) {
        guard let traderId = currentTraderId else {
            print("⚠️ TradesOverviewViewModel: No current trader ID - returning empty snapshots")
            return ([], [])
        }

        let activeSnapshot = (orderService?.activeOrders ?? [])
            .filter { $0.traderId == traderId }
        let completedSnapshot = TraderDepotTradeFilter.tradesForDepotDisplay(
            (tradeService?.completedTrades ?? [])
                .filter { $0.traderId == traderId }
        )

        return (activeSnapshot, completedSnapshot)
    }

    func detectActiveTrade(_ activeSnapshot: [Order], _ completedSnapshot: [Trade]) -> Bool {
        let activeBuys = activeSnapshot.contains { $0.type == .buy && $0.buyStatus == .executed }
        return completedSnapshot.contains { !$0.isCompleted } || activeBuys
    }

    func processTrades(_ trades: [Trade]) async -> ([TradeOverviewItem], [TradeOverviewItem]) {
        var ongoingItems: [TradeOverviewItem] = []
        var completedItems: [TradeOverviewItem] = []

        for trade in trades {
            let item = await createTradeOverviewItem(for: trade)
            if trade.isCompleted {
                completedItems.append(item)
            } else {
                ongoingItems.append(item)
            }
        }

        return (ongoingItems, completedItems)
    }

    func createTradeOverviewItem(for trade: Trade) async -> TradeOverviewItem {
        let pnl = self.resolveOverviewProfit(for: trade)
        let roi = self.resolveOverviewROI(for: trade, profit: pnl)
        let endDate = trade.completedAt ?? Date()
        let startDate = trade.createdAt
        let totalFees = self.calculateInvoiceBasedFees(for: trade)
        let hasProfit = pnl > 0
        let commission = await commissionCalculator.calculateCommission(tradeId: trade.id, hasProfit: hasProfit)
        let isCommissionPending = TradesOverviewCommissionAmounts.isCommissionPending(
            tradeIsCompleted: trade.isCompleted,
            hasProfit: hasProfit,
            commission: commission
        )

        return TradeOverviewItem(
            tradeId: trade.id,
            tradeNumber: trade.tradeNumber,
            tradeNumberYear: trade.tradeNumberYear,
            startDate: startDate,
            endDate: endDate,
            profitLoss: pnl,
            returnPercentage: roi,
            commission: commission,
            isCommissionPending: isCommissionPending,
            isActive: !trade.isCompleted,
            statusText: trade.status.displayName,
            statusDetail: trade.status.displayName,
            onDetailsTapped: { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.handleTradeDetailsTapped(
                        trade: trade,
                        grossProfit: pnl,
                        totalFees: totalFees,
                        pnl: pnl,
                        roi: roi,
                        startDate: startDate,
                        endDate: endDate,
                        commission: commission
                    )
                }
            },
            grossProfit: pnl,
            totalFees: totalFees
        )
    }

    func handleTradeDetailsTapped(
        trade: Trade,
        grossProfit: Double,
        totalFees: Double,
        pnl: Double,
        roi: Double,
        startDate: Date,
        endDate: Date,
        commission: Double
    ) async {
        let hasProfit = pnl > 0
        let detailsCommission = await commissionCalculator.calculateCommission(tradeId: trade.id, hasProfit: hasProfit)
        selectedTrade = TradeOverviewItem(
            tradeId: trade.id,
            tradeNumber: trade.tradeNumber,
            tradeNumberYear: trade.tradeNumberYear,
            startDate: startDate,
            endDate: endDate,
            profitLoss: pnl,
            returnPercentage: roi,
            commission: detailsCommission,
            isCommissionPending: TradesOverviewCommissionAmounts.isCommissionPending(
                tradeIsCompleted: trade.isCompleted,
                hasProfit: hasProfit,
                commission: detailsCommission
            ),
            isActive: !trade.isCompleted,
            statusText: trade.status.displayName,
            statusDetail: trade.status.displayName,
            onDetailsTapped: {},
            grossProfit: grossProfit,
            totalFees: totalFees
        )
        showTradeDetails = true
    }

    func updateTradeLists(_ ongoingItems: [TradeOverviewItem], _ completedItems: [TradeOverviewItem]) {
        self.ongoingTrades = ongoingItems.sorted { $0.endDate > $1.endDate }
        self.completedTrades = completedItems.sorted { $0.tradeNumber > $1.tradeNumber }
    }

    func filterTrades(by period: TradeTimePeriod) async {
        self.lastFilteredTimePeriod = period
        isLoading = true
        try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
        filteringViewModel.updateTrades(ongoing: ongoingTrades, completed: completedTrades)
        await filteringViewModel.filterTrades(by: period)
        let tableRows = self.createTableRows(from: filteringViewModel.filteredCompletedTrades)
        self.columnWidths = ColumnWidthCalculator.calculate(for: tableRows)
        isLoading = false
    }

    func createTableRows(from trades: [TradeOverviewItem]) -> [TradeTableRowData] {
        trades.map { trade in
            TradeTableRowData(from: trade, displayNumber: nil)
        }
    }

    func calculateGrossProfit(for trade: Trade) -> Double {
        statisticsService?.calculateGrossProfit(for: trade) ?? 0.0
    }

    func calculateTotalFees(for trade: Trade) -> Double {
        statisticsService?.calculateTotalFees(for: trade) ?? 0.0
    }

    /// Read-time: stored SSOT first unless stale vs cumulative sell legs; then recompute.
    func resolveOverviewProfit(for trade: Trade) -> Double {
        if let stored = trade.calculatedProfit,
           !ProfitCalculationService.isStoredProfitStale(for: trade) {
            return stored
        }
        if let invoiceService {
            let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
            let buyInvoice = allInvoices.first { $0.transactionType == .buy }
            let sellInvoices = allInvoices.filter { $0.transactionType == .sell }
            if let profit = ProfitCalculationService.resolveRealizedProfit(
                for: trade,
                buyInvoice: buyInvoice,
                sellInvoices: sellInvoices
            ) {
                return profit
            }
        }
        return trade.displayProfit
    }

    func resolveOverviewROI(for trade: Trade, profit: Double) -> Double {
        guard trade.totalSoldQuantity > 0 else { return 0.0 }
        let buySecuritiesValue = trade.buyOrder.price * trade.totalSoldQuantity
        let buyFees = FeeCalculationService.calculateTotalFees(for: buySecuritiesValue)
        let totalBuyCost = buySecuritiesValue + buyFees
        return ProfitCalculationService.calculateReturnPercentage(
            grossProfit: profit,
            investedAmount: totalBuyCost
        ) ?? trade.displayROI
    }

    func calculateInvoiceBasedFees(for trade: Trade) -> Double {
        guard let invoiceService = invoiceService else { return 0.0 }
        let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
        return allInvoices.reduce(0) { $0 + $1.feesTotal }
    }
}
