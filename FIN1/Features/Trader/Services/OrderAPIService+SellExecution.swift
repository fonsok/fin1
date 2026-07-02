import Foundation

extension OrderAPIService {
    func saveSellOrder(_ order: OrderSell, tradeId: String?) async throws -> OrderSell {
        print("📡 OrderAPIService: Placing sell order via executeSellOrder (tradeId: \(tradeId ?? "nil"))")

        let payload = Self.buildExecuteSellOrderPayload(order: order, tradeId: tradeId)
        guard JSONSerialization.isValidJSONObject(payload) else {
            throw AppError.validationError("Ungültige Sell-Order-Parameter.")
        }

        if Self.isMarketOrderInstruction(order.orderInstruction) {
            try await MarketDataQuotePublisher.ensureFreshMarketDataBeforeExecution(
                symbol: order.symbol,
                indicativePrice: order.price,
                via: self.apiClient
            )
        }

        let result: ExecuteSellOrderResult = try await apiClient.callFunction(
            "executeSellOrder",
            parameters: payload
        )

        print(
            "✅ OrderAPIService: Sell order placed — id=\(result.orderId) "
                + "price=\(result.executionPrice) replay=\(result.idempotentReplay)"
        )

        return OrderSell(
            id: result.orderId,
            traderId: order.traderId,
            symbol: order.symbol,
            description: order.description,
            quantity: order.quantity,
            price: result.executionPrice,
            totalAmount: result.grossAmount,
            status: OrderSellStatus(rawValue: result.status ?? order.status.rawValue) ?? order.status,
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
            originalHoldingId: order.originalHoldingId
        )
    }

    static func isMarketOrderInstruction(_ instruction: String?) -> Bool {
        let normalized = (instruction ?? "market").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized.isEmpty || normalized == "market"
    }

    static func buildExecuteSellOrderPayload(order: OrderSell, tradeId: String?) -> [String: Any] {
        var payload: [String: Any] = [
            "symbol": order.symbol,
            "quantity": Int(order.quantity),
            "orderInstruction": order.orderInstruction ?? "market",
            "clientOrderIntentId": order.id
        ]
        if let tradeId, !tradeId.isEmpty {
            payload["tradeId"] = tradeId
        }
        if let originalHoldingId = order.originalHoldingId, !originalHoldingId.isEmpty {
            payload["originalHoldingId"] = originalHoldingId
        }
        if !order.description.isEmpty {
            payload["description"] = order.description
        }
        if let optionDirection = order.optionDirection {
            payload["optionDirection"] = optionDirection
        }
        if let underlyingAsset = order.underlyingAsset {
            payload["underlyingAsset"] = underlyingAsset
        }
        if let wkn = order.wkn {
            payload["wkn"] = wkn
        }
        if let strike = order.strike {
            payload["strike"] = strike
        }
        if let limitPrice = order.limitPrice {
            payload["limitPrice"] = limitPrice
        }
        return payload
    }
}

private struct ExecuteSellOrderResult: Decodable {
    let orderId: String
    let orderNumber: String?
    let status: String?
    let executionPrice: Double
    let priceSource: String?
    let grossAmount: Double
    let totalFees: Double
    let netAmount: Double
    let idempotentReplay: Bool
}
