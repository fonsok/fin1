import Foundation

extension BuyOrderPlacementService {

    static func mapPairedBuyFailure(_ error: AppError) -> AppError {
        let message = error.errorDescription ?? ""
        let normalized = message.lowercased()
        if normalized.contains("duplicate value for a field with unique values")
            || normalized.contains("duplicate key")
            || normalized.contains("e11000") {
            return .validationError(
                "Der Kauf konnte wegen eines Server-Konflikts nicht abgeschlossen werden. "
                    + "Bitte prüfen Sie zuerst Ihr Depot — der Auftrag könnte bereits eingegangen sein."
            )
        }
        if normalized.contains("paired execution aborted") {
            return .validationError(
                "Der Kauf konnte nicht abgeschlossen werden. Bitte prüfen Sie Ihr Depot, bevor Sie erneut kaufen."
            )
        }
        return error
    }

    /// Buy order payload shared by trader-only and paired flows.
    func makeBuyOrderRequest(
        searchResult: SearchResult,
        quantity: Int,
        executedPrice: Double,
        orderMode: OrderMode,
        limit: String,
        isMirrorPoolOrder: Bool
    ) -> BuyOrderRequest {
        BuyOrderRequest(
            symbol: searchResult.wkn,
            quantity: quantity,
            price: executedPrice,
            optionDirection: searchResult.direction,
            description: searchResult.underlyingAsset,
            orderInstruction: orderMode.rawValue,
            limitPrice: orderMode == .limit ? Double(limit.replacingOccurrences(of: ",", with: ".")) : nil,
            strike: Double(searchResult.strike.replacingOccurrences(of: ",", with: ".")),
            subscriptionRatio: searchResult.subscriptionRatio,
            denomination: searchResult.denomination,
            isMirrorPoolOrder: isMirrorPoolOrder
        )
    }

    func traderOnlyBlockReason(mirrorPoolQuantity: Int) async -> TraderPairedBuyPlacementGuard.BlockReason? {
        let currentUser = self.userService.currentUser
        let localPoolCapital: Double
        if let investmentService, let investmentDataProvider {
            localPoolCapital = TraderPairedBuyPlacementGuard.localReservedPoolCapital(
                investmentService: investmentService,
                investmentDataProvider: investmentDataProvider,
                currentUser: currentUser
            )
        } else {
            localPoolCapital = 0
        }

        let traderId = currentUser?.id ?? ""
        return await TraderPairedBuyPlacementGuard.blockReason(
            mirrorPoolQuantity: mirrorPoolQuantity,
            localReservedPoolCapital: localPoolCapital,
            parseAPIClient: self.parseAPIClient,
            investmentAPIService: self.investmentAPIService,
            traderId: traderId,
            traderUsername: currentUser?.username,
            traderName: currentUser.map { "\($0.firstName) \($0.lastName)".trimmingCharacters(in: .whitespaces) }
        )
    }
}

func buyOrderPlacementSafeCurrencyString(_ value: Double) -> String {
    guard value.isFinite else { return "—" }
    return value.formatted(.number.precision(.fractionLength(2)))
}
