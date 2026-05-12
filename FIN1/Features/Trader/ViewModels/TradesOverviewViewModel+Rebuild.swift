import Foundation

@MainActor
extension TradesOverviewViewModel {
    func rebuildTrades() async {
        let (activeSnapshot, completedSnapshot) = getTradeSnapshots()
        self.hasActiveTrade = detectActiveTrade(activeSnapshot, completedSnapshot)

        let (ongoingItems, completedItems) = await processTrades(completedSnapshot)
        updateTradeLists(ongoingItems, completedItems)

        filteringViewModel.updateTrades(ongoing: ongoingTrades, completed: completedTrades)
        await filteringViewModel.filterTrades(by: .last30Days)

        let tableRows = createTableRows(from: filteringViewModel.filteredCompletedTrades)
        self.columnWidths = ColumnWidthCalculator.calculate(for: tableRows)
    }

    func getTradeSnapshots() -> ([Order], [Trade]) {
        guard let traderId = currentTraderId else {
            print("⚠️ TradesOverviewViewModel: No current trader ID - returning empty snapshots")
            return ([], [])
        }

        let activeSnapshot = (orderService?.activeOrders ?? [])
            .filter { $0.traderId == traderId }
        let completedSnapshot = (tradeService?.completedTrades ?? [])
            .filter { $0.traderId == traderId }

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
        let pnl = trade.displayProfit
        let roi = trade.displayROI
        let endDate = trade.completedAt ?? Date()
        let startDate = trade.createdAt
        let totalFees = calculateInvoiceBasedFees(for: trade)
        let commission = await commissionCalculator.calculateCommission(tradeId: trade.id, hasProfit: pnl > 0)

        return TradeOverviewItem(
            tradeId: trade.id,
            tradeNumber: trade.tradeNumber,
            startDate: startDate,
            endDate: endDate,
            profitLoss: pnl,
            returnPercentage: roi,
            commission: commission,
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
        let detailsCommission = await commissionCalculator.calculateCommission(tradeId: trade.id, hasProfit: pnl > 0)
        selectedTrade = TradeOverviewItem(
            tradeId: trade.id,
            tradeNumber: trade.tradeNumber,
            startDate: startDate,
            endDate: endDate,
            profitLoss: pnl,
            returnPercentage: roi,
            commission: detailsCommission,
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
        isLoading = true
        try? await Task.sleep(nanoseconds: UInt64(0.5 * 1_000_000_000))
        filteringViewModel.updateTrades(ongoing: ongoingTrades, completed: completedTrades)
        await filteringViewModel.filterTrades(by: period)
        let tableRows = createTableRows(from: filteringViewModel.filteredCompletedTrades)
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

    func calculateInvoiceBasedProfit(for trade: Trade) -> Double {
        guard let invoiceService = invoiceService else { return 0.0 }
        let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
        let buyInvoice = allInvoices.first { $0.transactionType == .buy }
        let sellInvoices = allInvoices.filter { $0.transactionType == .sell }
        return ProfitCalculationService.calculateTaxableProfit(buyInvoice: buyInvoice, sellInvoices: sellInvoices)
    }

    func calculateInvoiceBasedFees(for trade: Trade) -> Double {
        guard let invoiceService = invoiceService else { return 0.0 }
        let allInvoices = invoiceService.getInvoicesForTrade(trade.id)
        return allInvoices.reduce(0) { $0 + $1.feesTotal }
    }
}
