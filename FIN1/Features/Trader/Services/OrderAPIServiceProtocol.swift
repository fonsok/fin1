import Foundation

/// Protocol for syncing orders to Parse Server backend
protocol OrderAPIServiceProtocol {
    func saveBuyOrder(_ order: OrderBuy) async throws -> OrderBuy
    func saveSellOrder(_ order: OrderSell, tradeId: String?) async throws -> OrderSell
    func updateOrder(_ order: Order, tradeId: String?) async throws -> Order
    func fetchOrders(for traderId: String) async throws -> [Order]
    func fetchActiveOrders(for traderId: String) async throws -> [Order]
    func cancelOrder(_ orderId: String) async throws
    func finalizePairedBuyExecution(pairExecutionId: String) async throws
    func commitPairedBuyExecution(pairExecutionId: String, postDisplayStatus: String?) async throws
    func advancePairedOrderStatus(pairExecutionId: String, status: String) async throws
}
