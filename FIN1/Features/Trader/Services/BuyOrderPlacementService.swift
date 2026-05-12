import Foundation

// MARK: - Buy Order Placement Service Protocol
protocol BuyOrderPlacementServiceProtocol: Sendable {
    func placeOrder(
        searchResult: SearchResult,
        quantity: Int,
        orderMode: OrderMode,
        limit: String,
        priceValidityProgress: Double,
        investmentOrderCalculation: CombinedOrderCalculationResult?,
        traderService: any TraderServiceProtocol
    ) async throws -> BuyOrderPlacementResult
}

// MARK: - Buy Order Placement Result
struct BuyOrderPlacementResult {
    let success: Bool
    let error: AppError?
}

// MARK: - Buy Order Placement Service
/// Handles order placement logic for buy orders
final class BuyOrderPlacementService: BuyOrderPlacementServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let auditLoggingService: any AuditLoggingServiceProtocol
    private let userService: any UserServiceProtocol
    private let transactionLimitService: (any TransactionLimitServiceProtocol)?
    private let parseAPIClient: (any ParseAPIClientProtocol)?
    
    // MARK: - Initialization
    init(
        auditLoggingService: any AuditLoggingServiceProtocol,
        userService: any UserServiceProtocol,
        transactionLimitService: (any TransactionLimitServiceProtocol)? = nil,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil
    ) {
        self.auditLoggingService = auditLoggingService
        self.userService = userService
        self.transactionLimitService = transactionLimitService
        self.parseAPIClient = parseAPIClient
    }

    func placeOrder(
        searchResult: SearchResult,
        quantity: Int,
        orderMode: OrderMode,
        limit: String,
        priceValidityProgress: Double,
        investmentOrderCalculation: CombinedOrderCalculationResult?,
        traderService: any TraderServiceProtocol
    ) async throws -> BuyOrderPlacementResult {
        // Validate price is still valid
        guard priceValidityProgress > 0 else {
            return BuyOrderPlacementResult(
                success: false,
                error: AppError.validationError("Preis hat sich geändert. Bitte versuchen Sie es erneut.")
            )
        }

        let executedPrice = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0

        // Validate data flow before proceeding
        let validationResult = searchResult.validate(context: "BuyOrderPlacementService.placeOrder")
        switch validationResult {
        case .valid:
            break
        case .warning(let message):
            print("⚠️ WARNING: \(message)")
        case .error(let message):
            print("❌ ERROR: \(message)")
            return BuyOrderPlacementResult(
                success: false,
                error: AppError.validationError("Data validation failed: \(message)")
            )
        }

        DataFlowValidator.logDataFlow(
            step: "Creating buy order",
            searchResult: searchResult,
            optionDirection: searchResult.direction,
            underlyingAsset: searchResult.underlyingAsset
        )

        // Split into two independent orders/trades when pool capital participates:
        // 1) trader order (user-driven)
        // 2) mirror-pool order (investor capital)
        //
        // If there is no mirror pool quantity (no reserved investor capital / no calculation),
        // fall back to a single trader-side buy via TraderService on the Main Actor (TraderServiceProtocol is @MainActor).
        let traderQuantity = investmentOrderCalculation?.traderQuantity ?? quantity
        let mirrorPoolQuantity = investmentOrderCalculation?.investmentQuantity ?? 0

        // Transaction limits and trader balance checks apply to trader leg only.
        let estimatedCost = Double(traderQuantity) * executedPrice

        guard traderQuantity > 0 else {
            return BuyOrderPlacementResult(
                success: false,
                error: AppError.validationError("Ungültige Stückzahl für die Trader-Order.")
            )
        }

        do {
            // ✅ Pre-Trade Compliance: Check transaction limits (applies before any placement path)
            if let limitService = transactionLimitService,
               let userId = userService.currentUser?.id {
                let limitCheck = try await limitService.checkAllLimits(userId: userId, amount: estimatedCost)
                if !limitCheck.isAllowed {
                    return BuyOrderPlacementResult(
                        success: false,
                        error: AppError.validationError(limitCheck.errorMessage ?? "Transaktionslimit überschritten")
                    )
                }
            }

            // No pool mirror leg: trader-only order (must run on MainActor for TraderService)
            if mirrorPoolQuantity <= 0 {
                let orderRequest = makeBuyOrderRequest(
                    searchResult: searchResult,
                    quantity: traderQuantity,
                    executedPrice: executedPrice,
                    orderMode: orderMode,
                    limit: limit,
                    isMirrorPoolOrder: false
                )
                _ = try await Task { @MainActor in
                    try await traderService.placeBuyOrder(orderRequest)
                }.value

                await recordTransactionIfNeeded(amount: estimatedCost)
                logOrderPlacedCompliance(
                    description: "Trader buy placed (no mirror pool leg): qty=\(traderQuantity) for \(searchResult.underlyingAsset ?? searchResult.wkn) @ €\(safeCurrencyString(executedPrice))",
                    notes: "Mode: \(orderMode.rawValue), Symbol: \(searchResult.wkn)"
                )

                return BuyOrderPlacementResult(success: true, error: nil)
            }

            guard let parseAPIClient = parseAPIClient else {
                return BuyOrderPlacementResult(
                    success: false,
                    error: AppError.validationError("Backend-Verbindung nicht verfügbar: Paired-Kauf mit Pool erfordert ParseAPIClient.")
                )
            }

            var payload: [String: Any] = [
                "symbol": searchResult.wkn,
                "price": executedPrice,
                "orderInstruction": orderMode.rawValue,
                "clientOrderIntentId": UUID().uuidString,
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
                    error: AppError.validationError("Ungültige Auftragsparameter (Numerik oder Format). Bitte Ansicht neu laden und erneut versuchen.")
                )
            }

            let executionResult: ExecutePairedBuyResult = try await parseAPIClient.callFunction(
                "executePairedBuy",
                parameters: payload
            )

            guard executionResult.status.uppercased() == "COMMITTED" else {
                return BuyOrderPlacementResult(
                    success: false,
                    error: AppError.validationError("Paired execution nicht committed (status=\(executionResult.status)).")
                )
            }

            await recordTransactionIfNeeded(amount: estimatedCost)

            let pairId = executionResult.pairExecutionId ?? "unknown"
            let underlyingAsset = searchResult.underlyingAsset ?? "N/A"
            logOrderPlacedCompliance(
                description: "Paired buy committed: trader=\(traderQuantity), mirror=\(mirrorPoolQuantity) for \(underlyingAsset) @ €\(safeCurrencyString(executedPrice))",
                notes: "PairExecutionId: \(pairId), Mode: \(orderMode.rawValue), Symbol: \(searchResult.wkn)"
            )

            // Variant A: trade, pool allocation, escrow deploy, invoices run entirely on Parse (executePairedBuy → finalize).
            await Task { @MainActor in
                try? await traderService.refreshTradingData()
            }.value

            return BuyOrderPlacementResult(success: true, error: nil)
        } catch let error as AppError {
            return BuyOrderPlacementResult(success: false, error: error)
        } catch {
            let appError = error.toAppError()
            return BuyOrderPlacementResult(
                success: false,
                error: appError
            )
        }
    }

    /// Buy order payload shared by trader-only and paired flows.
    private func makeBuyOrderRequest(
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

    /// Transaction limit bookkeeping when a limit service is configured.
    private func recordTransactionIfNeeded(amount: Double) async {
        if let limitService = transactionLimitService,
           let userId = userService.currentUser?.id {
            try? await limitService.recordTransaction(userId: userId, amount: amount)
        }
    }

    private func logOrderPlacedCompliance(description: String, notes: String) {
        guard let userId = userService.currentUser?.id else { return }

        let complianceEvent = ComplianceEvent(
            eventType: .orderPlaced,
            agentId: userId,
            customerId: userId,
            description: description,
            severity: .medium,
            requiresReview: false,
            notes: notes
        )
        Task {
            await auditLoggingService.logComplianceEvent(complianceEvent)
        }
    }
}

private struct ExecutePairedBuyResult: Decodable {
    let pairExecutionId: String?
    let idempotentReplay: Bool?
    let status: String

    enum CodingKeys: String, CodingKey {
        case pairExecutionId
        case idempotentReplay
        case status
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        pairExecutionId = try c.decodeIfPresent(String.self, forKey: .pairExecutionId)
        idempotentReplay = try c.decodeIfPresent(Bool.self, forKey: .idempotentReplay)
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
    }
}

private func safeCurrencyString(_ value: Double) -> String {
    guard value.isFinite else { return "—" }
    return value.formatted(.number.precision(.fractionLength(2)))
}
