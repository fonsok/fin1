import Foundation

enum BuyOrderStatus: Equatable {
    case idle
    case transmitting
    case orderPlaced(executedPrice: Double, finalCost: Double)
    case failed(AppError)
}
