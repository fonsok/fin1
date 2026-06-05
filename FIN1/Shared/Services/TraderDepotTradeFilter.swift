import Foundation

/// Filters trades for trader **Depot / Bestand** display.
///
/// Paired buys (`executePairedBuy`) create two backend trades (TRADER + MIRROR_POOL legs).
/// The mirror leg is pool accounting — it must not appear as a second depot position.
enum TraderDepotTradeFilter {
    /// Trades that should appear as depot holdings (one row per trader leg / standalone buy).
    static func tradesForDepotDisplay(_ trades: [Trade]) -> [Trade] {
        trades.filter { !self.isPoolMirrorLeg($0) }
    }

    static func isPoolMirrorLeg(_ trade: Trade) -> Bool {
        if trade.buyOrder.isMirrorPoolOrder == true {
            return true
        }
        let leg = (trade.buyLegType ?? "").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return leg == "MIRROR_POOL"
    }
}
