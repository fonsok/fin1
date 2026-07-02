import SwiftUI

// MARK: - Trade Details Route
/// Helper route that satisfies navigationDestination(item:) Hashable requirement.
/// `Hashable` is declared on the struct; `View` is a separate extension so isolation matches Swift 6 rules.
struct TradeDetailsRoute: Hashable {
    let tradeNumber: Int
    let tradeNumberYear: Int?
    let trades: [TradeOverviewItem]

    static func == (lhs: TradeDetailsRoute, rhs: TradeDetailsRoute) -> Bool {
        lhs.tradeNumber == rhs.tradeNumber && lhs.tradeNumberYear == rhs.tradeNumberYear
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.tradeNumber)
        hasher.combine(self.tradeNumberYear)
    }

    private func matches(_ item: TradeOverviewItem) -> Bool {
        guard item.tradeNumber == self.tradeNumber else { return false }
        guard let tradeNumberYear else { return true }
        return item.resolvedTradeNumberYear == tradeNumberYear
    }
}

extension TradeDetailsRoute: View {
    var body: some View {
        let currentYear = TradeNumberFormatting.calendarYear()
        guard let trade = trades.first(where: { matches($0) && $0.resolvedTradeNumberYear == currentYear })
            ?? trades.first(where: { matches($0) })
            ?? trades.first else {
            return AnyView(Text("Trade not found").foregroundColor(.red))
        }
        return AnyView(TradeDetailsViewWrapper(trade: trade))
    }
}
