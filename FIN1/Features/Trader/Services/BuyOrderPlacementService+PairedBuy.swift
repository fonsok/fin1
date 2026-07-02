import Foundation

extension BuyOrderPlacementService {

    func placePairedBuyOrder(
        parseAPIClient: any ParseAPIClientProtocol,
        searchResult: SearchResult,
        executedPrice: Double,
        orderMode: OrderMode,
        limit: String,
        clientOrderIntentId: String,
        traderQuantity: Int,
        mirrorPoolQuantity: Int,
        estimatedCost: Double,
        traderId: String,
        traderService: any TraderServiceProtocol
    ) async throws -> BuyOrderPlacementResult {
        var payload: [String: Any] = [
            "symbol": searchResult.wkn,
            "orderInstruction": orderMode.rawValue,
            "clientOrderIntentId": clientOrderIntentId,
            "traderQuantity": traderQuantity,
            "mirrorPoolQuantity": mirrorPoolQuantity
        ]
        if orderMode == .limit, let parsedLimit = Double(limit.replacingOccurrences(of: ",", with: ".")), parsedLimit > 0 {
            payload["limitPrice"] = parsedLimit
        }
        if let optionDirection = searchResult.direction {
            payload["optionDirection"] = optionDirection
        }
        if let underlyingAsset = searchResult.underlyingAsset {
            payload["description"] = underlyingAsset
        }
        if let parsedStrike = Double(searchResult.strike.replacingOccurrences(of: ",", with: ".")) {
            payload["strike"] = parsedStrike
        }
        payload["subscriptionRatio"] = searchResult.subscriptionRatio
        if let denomination = searchResult.denomination {
            payload["denomination"] = denomination
        }

        guard JSONSerialization.isValidJSONObject(payload) else {
            return BuyOrderPlacementResult(
                success: false,
                error: AppError.validationError(
                    "Ungültige Auftragsparameter (Numerik oder Format). Bitte Ansicht neu laden und erneut versuchen."
                )
            )
        }

        if orderMode == .market {
            try await MarketDataQuotePublisher.publishBeforeMarketExecution(
                symbol: searchResult.wkn,
                indicativePrice: executedPrice,
                via: parseAPIClient
            )
        }

        let executionResult: ExecutePairedBuyResult = try await parseAPIClient.callFunction(
            "executePairedBuy",
            parameters: payload
        )

        BuyOrderPlacementTelemetry.pairedBuyServerResponse(
            intentId: clientOrderIntentId,
            status: executionResult.status,
            idempotentReplay: executionResult.idempotentReplay ?? false,
            pairExecutionId: executionResult.pairExecutionId
        )

        let normalizedStatus = executionResult.status.uppercased()
        if normalizedStatus == "ABORTED" {
            return BuyOrderPlacementResult(
                success: false,
                error: AppError.validationError(
                    "Der Kauf konnte nicht abgeschlossen werden. Bitte prüfen Sie Ihr Depot. "
                        + "Tippen Sie auf „Erneut versuchen“, um mit einer neuen Auftragsreferenz fortzufahren."
                )
            )
        }

        guard normalizedStatus == "COMMITTED" else {
            return BuyOrderPlacementResult(
                success: false,
                error: AppError.validationError("Paired execution nicht committed (status=\(executionResult.status)).")
            )
        }

        await self.recordTransactionIfNeeded(amount: estimatedCost)

        let pairId = executionResult.pairExecutionId ?? "unknown"
        let underlyingAsset = searchResult.underlyingAsset ?? "N/A"
        let serverPrice = executionResult.traderLegPrice(fallback: executedPrice)
        self.logOrderPlacedCompliance(
            description: "Paired buy committed: trader=\(traderQuantity), mirror=\(mirrorPoolQuantity) for \(underlyingAsset) @ €\(Self.formattedPrice(serverPrice))",
            notes: "PairExecutionId: \(pairId), Mode: \(orderMode.rawValue), Symbol: \(searchResult.wkn)"
        )

        if let pairExecutionId = executionResult.pairExecutionId,
           let traderLeg = executionResult.traderLegOrder(
               traderId: traderId,
               searchResult: searchResult,
               quantity: traderQuantity,
               executedPrice: serverPrice,
               orderMode: orderMode,
               limit: limit
           ) {
            await Task { @MainActor in
                await traderService.registerPairedBuyTraderOrder(traderLeg, pairExecutionId: pairExecutionId)
            }.value
        }

        return BuyOrderPlacementResult(success: true, error: nil)
    }

    static func formattedPrice(_ value: Double) -> String {
        guard value.isFinite else { return "—" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }

    static func iso8601Now() -> String {
        PairedBuyPayloadTime.iso8601.string(from: Date())
    }
}

private struct ExecutePairedBuyResult: Decodable {
    let pairExecutionId: String?
    let idempotentReplay: Bool?
    let status: String
    let orders: [ExecutePairedBuyOrderLeg]?

    enum CodingKeys: String, CodingKey {
        case pairExecutionId
        case idempotentReplay
        case status
        case orders
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.pairExecutionId = try c.decodeIfPresent(String.self, forKey: .pairExecutionId)
        self.idempotentReplay = try c.decodeIfPresent(Bool.self, forKey: .idempotentReplay)
        self.status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        self.orders = try c.decodeIfPresent([ExecutePairedBuyOrderLeg].self, forKey: .orders)
    }

    func traderLegPrice(fallback: Double) -> Double {
        guard let leg = orders?.first(where: {
            ($0.legType ?? "").uppercased() == "TRADER"
        }), let price = leg.price, price > 0 else {
            return fallback
        }
        return price
    }

    func traderLegOrder(
        traderId: String,
        searchResult: SearchResult,
        quantity: Int,
        executedPrice: Double,
        orderMode: OrderMode,
        limit: String
    ) -> Order? {
        guard let leg = orders?.first(where: {
            ($0.legType ?? "").uppercased() == "TRADER"
        }), let orderId = leg.orderId else {
            return nil
        }

        let totalAmount = OrderCashAmount.grossAmount(
            quantity: quantity,
            briefPricePerPiece: executedPrice
        )
        let limitPrice = orderMode == .limit
            ? Double(limit.replacingOccurrences(of: ",", with: "."))
            : nil

        return Order(
            id: orderId,
            traderId: traderId,
            symbol: searchResult.wkn,
            description: searchResult.underlyingAsset ?? searchResult.wkn,
            type: .buy,
            quantity: Double(quantity),
            price: executedPrice,
            totalAmount: totalAmount,
            createdAt: Date(),
            executedAt: nil,
            confirmedAt: nil,
            updatedAt: Date(),
            optionDirection: searchResult.direction,
            underlyingAsset: searchResult.underlyingAsset,
            wkn: searchResult.wkn,
            category: "Optionsschein",
            strike: Double(searchResult.strike.replacingOccurrences(of: ",", with: ".")),
            orderInstruction: orderMode.rawValue,
            limitPrice: limitPrice,
            subscriptionRatio: searchResult.subscriptionRatio,
            denomination: searchResult.denomination,
            isMirrorPoolOrder: false,
            originalHoldingId: nil,
            pairExecutionId: self.pairExecutionId,
            status: "submitted"
        )
    }
}

private struct ExecutePairedBuyOrderLeg: Decodable {
    let orderId: String?
    let legType: String?
    let quantity: Int?
    let price: Double?
    let status: String?
}

private enum PairedBuyPayloadTime {
    nonisolated(unsafe) static let iso8601: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
