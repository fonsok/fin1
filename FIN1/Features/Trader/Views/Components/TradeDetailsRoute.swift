import SwiftUI

// MARK: - Trade Details Route
/// Helper route that satisfies navigationDestination(item:) Hashable requirement.
/// `Hashable` is declared on the struct; `View` is a separate extension so isolation matches Swift 6 rules.
struct TradeDetailsRoute: Hashable {
    let tradeNumber: Int
    let trades: [TradeOverviewItem]

    static func == (lhs: TradeDetailsRoute, rhs: TradeDetailsRoute) -> Bool {
        lhs.tradeNumber == rhs.tradeNumber
    }

    func hash(into hasher: inout Hasher) { hasher.combine(tradeNumber) }
}

extension TradeDetailsRoute: View {
    var body: some View {
        guard let trade = trades.first(where: { $0.tradeNumber == tradeNumber }) ?? trades.first else {
            return AnyView(Text("Trade not found").foregroundColor(.red))
        }
        return AnyView(TradeDetailsViewWrapper(trade: trade))
    }
}
