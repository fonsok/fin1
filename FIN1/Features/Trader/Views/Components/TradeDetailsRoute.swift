import SwiftUI

// MARK: - Trade Details Route
/// Helper route that satisfies navigationDestination(item:) Hashable requirement
struct TradeDetailsRoute: View, Hashable {
    let tradeNumber: Int
    let trades: [TradeOverviewItem]

    static func == (lhs: TradeDetailsRoute, rhs: TradeDetailsRoute) -> Bool {
        lhs.tradeNumber == rhs.tradeNumber
    }

    func hash(into hasher: inout Hasher) { hasher.combine(tradeNumber) }

    var body: some View {
        guard let trade = trades.first(where: { $0.tradeNumber == tradeNumber }) ?? trades.first else {
            return AnyView(Text("Trade not found").foregroundColor(.red))
        }
        return AnyView(TradeDetailsViewWrapper(trade: trade))
    }
}
