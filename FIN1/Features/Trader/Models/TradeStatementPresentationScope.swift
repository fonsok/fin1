import Foundation

/// Limits TradeStatement / invoice comparison to a single trader leg (TBC vs TSC).
enum TradeStatementPresentationScope: Equatable {
    case fullTrade
    case buyLegOnly
    case sellLegOnly(matchingBelegNumber: String?)

    /// When false, do not synthesize KAUF from `Trade.buyOrder` if no buy invoice exists.
    var allowsBuyLegFromFullTradeFallback: Bool {
        switch self {
        case .fullTrade, .buyLegOnly: return true
        case .sellLegOnly: return false
        }
    }
}
