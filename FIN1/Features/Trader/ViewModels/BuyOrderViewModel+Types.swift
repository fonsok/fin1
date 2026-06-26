import Foundation

/// Inputs that affect mirror-pool binary search (excludes whole `SearchResult` identity).
struct BuyOrderPoolRecalcSecurityInputs: Equatable {
    let wkn: String
    let askPrice: String
    let denomination: Int?
    let subscriptionRatio: Double
    let minimumOrderAmount: Double?
}

/// Coarse pool snapshot — recalc only when reserved capital or count changes.
struct BuyOrderPoolInvestmentSnapshot: Equatable {
    let investmentCount: Int
    let totalCapital: Double
}

func buyOrderPoolRecalcSecurityInputs(from searchResult: SearchResult) -> BuyOrderPoolRecalcSecurityInputs {
    BuyOrderPoolRecalcSecurityInputs(
        wkn: searchResult.wkn,
        askPrice: searchResult.askPrice,
        denomination: searchResult.denomination,
        subscriptionRatio: searchResult.subscriptionRatio,
        minimumOrderAmount: searchResult.minimumOrderAmount
    )
}

enum BuyOrderStatus: Equatable {
    case idle
    case transmitting
    case orderPlaced(executedPrice: Double, finalCost: Double)
    case failed(AppError)
}
