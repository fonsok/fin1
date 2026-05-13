import Foundation

@MainActor
extension CollectionBillDocumentViewModel {
    func resolveTradeTarget() async -> Bool {
        let doc = routingDocument

        try? await tradeLifecycleService.loadCompletedTrades()

        var completedTrades = tradeLifecycleService.completedTrades

        if let tradeId = doc.tradeId,
           completedTrades.first(where: { $0.id == tradeId }) == nil,
           let fetched = await fetchTradeFromBackend(tradeId: tradeId) {
            completedTrades = completedTrades + [fetched]
        }

        if let tradeId = doc.tradeId,
           let foundById = completedTrades.first(where: { $0.id == tradeId }) {
            await self.publishTrade(foundById)
            return true
        }

        if let tradeNumber = extractTradeNumberFromDocumentName(doc.name),
           let foundByNumber = completedTrades.first(where: { $0.tradeNumber == tradeNumber }) {
            await self.publishTrade(foundByNumber)
            return true
        }

        if let tradeNumber = extractTradeNumberFromDocumentName(doc.name),
           !doc.userId.isEmpty,
           let fetched = await fetchTradeFromBackend(tradeNumber: tradeNumber, traderId: doc.userId) {
            await self.publishTrade(fetched)
            return true
        }

        print("❌ CollectionBillDocumentViewModel: Unable to resolve trade information for document '\(doc.name)'")
        return false
    }

    func fetchTradeFromBackend(tradeId: String) async -> Trade? {
        guard let parseAPIClient else { return nil }
        do {
            let parseTrade: ParseTrade = try await parseAPIClient.fetchObject(
                className: "Trade",
                objectId: tradeId,
                include: nil
            )
            return try parseTrade.toTrade()
        } catch {
            print("ℹ️ CollectionBillDocumentViewModel: trade fetch by id failed for '\(tradeId)': \(error.localizedDescription)")
            return nil
        }
    }

    func fetchTradeFromBackend(tradeNumber: Int, traderId: String?) async -> Trade? {
        guard let parseAPIClient else { return nil }
        var query: [String: Any] = ["tradeNumber": tradeNumber]
        if let traderId, !traderId.isEmpty {
            query["traderId"] = traderId
        }
        do {
            let rows: [ParseTrade] = try await parseAPIClient.fetchObjects(
                className: "Trade",
                query: query,
                include: nil,
                orderBy: "-updatedAt",
                limit: 5
            )
            guard let first = rows.first else { return nil }
            return try first.toTrade()
        } catch {
            print("ℹ️ CollectionBillDocumentViewModel: trade fetch by number failed (\(tradeNumber)): \(error.localizedDescription)")
            return nil
        }
    }

    func publishTrade(_ foundTrade: Trade) async {
        print("✅ CollectionBillDocumentViewModel: Found trade: ID=\(foundTrade.id), Number=\(foundTrade.tradeNumber)")
        resolvedFullTrade = foundTrade

        let grossProfit = tradingStatisticsService.calculateGrossProfit(for: foundTrade)
        let totalFees = tradingStatisticsService.calculateTotalFees(for: foundTrade)

        let tradeOverview = TradeOverviewItem(
            tradeId: foundTrade.id,
            tradeNumber: foundTrade.tradeNumber,
            startDate: foundTrade.createdAt,
            endDate: foundTrade.completedAt ?? foundTrade.updatedAt,
            profitLoss: foundTrade.currentPnL ?? 0,
            returnPercentage: 0,
            commission: 0,
            isActive: foundTrade.isActive,
            statusText: foundTrade.status.rawValue,
            statusDetail: "",
            onDetailsTapped: {},
            grossProfit: grossProfit,
            totalFees: totalFees
        )

        trade = tradeOverview
        isLoading = false
    }

    func extractTradeNumberFromDocumentName(_ name: String) -> Int? {
        // Extract trade number from "CollectionBill_Trade1_20251024_Z2CBXA7T.pdf" format
        let pattern = #"Trade(\d+)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name) {
            return Int(String(name[range]))
        }
        return nil
    }
}
