import Foundation

/// Service for syncing orders with Parse Server backend
final class OrderAPIService: OrderAPIServiceProtocol {
    let apiClient: ParseAPIClientProtocol
    let className = "Order"

    init(apiClient: ParseAPIClientProtocol) {
        self.apiClient = apiClient
    }

    func saveBuyOrder(_ order: OrderBuy) async throws -> OrderBuy {
        print("📡 OrderAPIService: Saving buy order to Parse Server")

        let input = ParseOrderInput.from(buyOrder: order)
        let response = try await apiClient.createObject(
            className: self.className,
            object: input
        )

        print("✅ OrderAPIService: Buy order saved with objectId: \(response.objectId)")

        return OrderBuy(
            id: response.objectId,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: order.price,
            totalAmount: order.totalAmount,
            status: order.status,
            createdAt: order.createdAt,
            executedAt: order.executedAt,
            confirmedAt: order.confirmedAt,
            updatedAt: order.updatedAt,
            optionDirection: order.optionDirection,
            underlyingAsset: order.underlyingAsset,
            wkn: order.wkn,
            category: order.category,
            strike: order.strike,
            orderInstruction: order.orderInstruction,
            limitPrice: order.limitPrice,
            subscriptionRatio: order.subscriptionRatio,
            denomination: order.denomination
        )
    }

    func updateOrder(_ order: Order, tradeId: String?) async throws -> Order {
        print("📡 OrderAPIService: Updating order on Parse Server (status: \(order.status))")

        let input = ParseOrderInput.from(order: order, tradeId: tradeId)
        let response = try await apiClient.updateObject(
            className: self.className,
            objectId: order.id,
            object: input
        )

        print("✅ OrderAPIService: Order updated: \(response.objectId)")
        return order
    }

    func fetchOrders(for traderId: String) async throws -> [Order] {
        print("📡 OrderAPIService: Fetching orders for trader: \(traderId)")

        let responses: [ParseOrderResponse] = try await apiClient.fetchObjects(
            className: self.className,
            query: ["traderId": traderId],
            include: nil,
            orderBy: "-createdAt",
            limit: 100
        )

        print("✅ OrderAPIService: Fetched \(responses.count) orders")
        return responses.map { $0.toOrder() }
    }

    func fetchActiveOrders(for traderId: String) async throws -> [Order] {
        let allOrders = try await fetchOrders(for: traderId)

        return allOrders.filter { order in
            let status = order.status.lowercased()
            guard status != "completed" && status != "cancelled" else { return false }
            return order.isMirrorPoolOrder != true
        }
    }

    func cancelOrder(_ orderId: String) async throws {
        print("📡 OrderAPIService: Cancelling order via cloud function: \(orderId)")

        struct CancelOrderResponse: Decodable {
            let orderId: String?
            let pairExecutionId: String?
            let cancelledOrderIds: [String]?
            let cancelledLegCount: Int?
        }

        _ = try await self.apiClient.callFunction(
            "cancelOrder",
            parameters: ["orderId": orderId]
        ) as CancelOrderResponse

        print("✅ OrderAPIService: Order cancelled on server")
    }
}
