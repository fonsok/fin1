import Foundation

extension SellOrderViewModel {

    /// Teil-Verkaufs-Limit (Admin `maxTraderPartialSells`, 0–3).
    var effectiveMaxPartialSells: Int {
        min(3, max(0, self.maxPartialSells))
    }

    /// Letzter erlaubter Teil-Verkauf — Restposition muss vollständig verkauft werden.
    var mustSellFullRemaining: Bool {
        let maxAllowed = self.effectiveMaxPartialSells
        if maxAllowed == 0 { return true }
        let events = self.holding.traderPartialSellEventCount ?? 0
        return events >= maxAllowed - 1
    }

    var quantityInputLocked: Bool {
        self.mustSellFullRemaining
    }

    var partialSellLimitInfoMessage: String? {
        guard self.mustSellFullRemaining, self.maxQuantity > 0 else { return nil }
        let maxAllowed = self.effectiveMaxPartialSells
        if maxAllowed == 0 {
            return "Teil-Verkäufe sind deaktiviert: bitte die gesamte Restposition verkaufen."
        }
        let events = self.holding.traderPartialSellEventCount ?? 0
        if events >= maxAllowed {
            return "Teil-Verkaufs-Limit (\(maxAllowed)) erreicht: verbleibende "
                + "\(self.maxQuantity.formattedAsLocalizedInteger()) St. müssen vollständig verkauft werden — "
                + "danach ist das Depot leer."
        }
        return "Teil-Verkaufs-Limit (\(maxAllowed) erlaubt): dieser Verkauf (Nr. \(events + 1)) muss alle verbleibenden "
            + "\(self.maxQuantity.formattedAsLocalizedInteger()) Stück umfassen — das Depot wird danach geleert."
    }
}
