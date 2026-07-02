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

        if let tradeNumber = extractTradeNumberFromDocumentName(doc.name) {
            let currentYear = TradeNumberFormatting.calendarYear()
            if let foundByNumber = completedTrades.first(where: {
                $0.tradeNumber == tradeNumber.number
                    && (tradeNumber.year == nil || $0.resolvedTradeNumberYear == tradeNumber.year)
            }) ?? completedTrades.first(where: {
                $0.tradeNumber == tradeNumber.number && $0.resolvedTradeNumberYear == currentYear
            }) ?? completedTrades.first(where: { $0.tradeNumber == tradeNumber.number }) {
                await self.publishTrade(foundByNumber)
                return true
            }
        }

        if let tradeNumber = extractTradeNumberFromDocumentName(doc.name),
           !doc.userId.isEmpty,
           let fetched = await fetchTradeFromBackend(
               tradeNumber: tradeNumber.number,
               tradeNumberYear: tradeNumber.year,
               traderId: doc.userId
           ) {
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

    func fetchTradeFromBackend(tradeNumber: Int, tradeNumberYear: Int? = nil, traderId: String?) async -> Trade? {
        guard let parseAPIClient else { return nil }
        var query: [String: Any] = ["tradeNumber": tradeNumber]
        if let tradeNumberYear {
            query["tradeNumberYear"] = tradeNumberYear
        } else {
            query["tradeNumberYear"] = TradeNumberFormatting.calendarYear()
        }
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
            tradeNumberYear: foundTrade.tradeNumberYear,
            startDate: foundTrade.createdAt,
            endDate: foundTrade.completedAt ?? foundTrade.updatedAt,
            profitLoss: foundTrade.currentPnL ?? 0,
            returnPercentage: 0,
            commission: 0,
            isCommissionPending: false,
            isActive: foundTrade.isActive,
            statusText: foundTrade.status.rawValue,
            statusDetail: "",
            onDetailsTapped: {},
            grossProfit: grossProfit,
            totalFees: totalFees
        )

        trade = tradeOverview
    }

    func extractTradeNumberFromDocumentName(_ name: String) -> (number: Int, year: Int?)? {
        let yearPattern = #"(\d{4})-(\d{3})"#
        if let regex = try? NSRegularExpression(pattern: yearPattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let yearRange = Range(match.range(at: 1), in: name),
           let numberRange = Range(match.range(at: 2), in: name),
           let year = Int(String(name[yearRange])),
           let number = Int(String(name[numberRange])) {
            return (number, year)
        }

        let legacyPattern = #"Trade(\d+)"#
        if let regex = try? NSRegularExpression(pattern: legacyPattern),
           let match = regex.firstMatch(in: name, range: NSRange(name.startIndex..., in: name)),
           let range = Range(match.range(at: 1), in: name),
           let number = Int(String(name[range])) {
            return (number, nil)
        }
        return nil
    }
}
