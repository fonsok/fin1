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
        clientOrderIntentId: String,
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
    let auditLoggingService: any AuditLoggingServiceProtocol
    let userService: any UserServiceProtocol
    let transactionLimitService: (any TransactionLimitServiceProtocol)?
    let parseAPIClient: (any ParseAPIClientProtocol)?
    let investmentAPIService: (any InvestmentAPIServiceProtocol)?
    let investmentService: (any InvestmentServiceProtocol)?
    let investmentDataProvider: (any BuyOrderInvestmentDataProviderProtocol)?

    // MARK: - Initialization
    init(
        auditLoggingService: any AuditLoggingServiceProtocol,
        userService: any UserServiceProtocol,
        transactionLimitService: (any TransactionLimitServiceProtocol)? = nil,
        parseAPIClient: (any ParseAPIClientProtocol)? = nil,
        investmentAPIService: (any InvestmentAPIServiceProtocol)? = nil,
        investmentService: (any InvestmentServiceProtocol)? = nil,
        investmentDataProvider: (any BuyOrderInvestmentDataProviderProtocol)? = nil
    ) {
        self.auditLoggingService = auditLoggingService
        self.userService = userService
        self.transactionLimitService = transactionLimitService
        self.parseAPIClient = parseAPIClient
        self.investmentAPIService = investmentAPIService
        self.investmentService = investmentService
        self.investmentDataProvider = investmentDataProvider
    }

    func placeOrder(
        searchResult: SearchResult,
        quantity: Int,
        orderMode: OrderMode,
        limit: String,
        priceValidityProgress: Double,
        investmentOrderCalculation: CombinedOrderCalculationResult?,
        clientOrderIntentId: String,
        traderService: any TraderServiceProtocol
    ) async throws -> BuyOrderPlacementResult {
        #if DEBUG
        if priceValidityProgress < BuyOrderPriceStaleness.elevatedWarningThreshold {
            print(
                "ℹ️ BuyOrderPlacementService: placing with elevated price staleness "
                    + "(indicator=\(String(format: "%.2f", priceValidityProgress)))"
            )
        }
        #endif

        let executedPrice = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0

        // Validate data flow before proceeding
        let validationResult = searchResult.validate(context: "BuyOrderPlacementService.placeOrder")
        switch validationResult {
        case .valid:
            break
        case .warning(let message):
            #if DEBUG
            print("⚠️ WARNING: \(message)")
            #endif
        case .error(let message):
            #if DEBUG
            print("❌ ERROR: \(message)")
            #endif
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
        let estimatedCost = OrderCashAmount.grossAmount(
            quantity: traderQuantity,
            briefPricePerPiece: executedPrice
        )

        guard traderQuantity > 0 else {
            return BuyOrderPlacementResult(
                success: false,
                error: AppError.validationError("Ungültige Stückzahl für die Trader-Order.")
            )
        }

        do {
            if self.parseAPIClient != nil {
                let backendHealthy = await MainActor.run { BackendHealthMonitor.shared.isHealthy }
                guard backendHealthy else {
                    return BuyOrderPlacementResult(
                        success: false,
                        error: TraderPairedBuyPlacementGuard.appError(for: .backendUnreachable)
                    )
                }
            }

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
                if let blockReason = await self.traderOnlyBlockReason(
                    mirrorPoolQuantity: mirrorPoolQuantity
                ) {
                    return BuyOrderPlacementResult(
                        success: false,
                        error: TraderPairedBuyPlacementGuard.appError(for: blockReason)
                    )
                }

                let orderRequest = self.makeBuyOrderRequest(
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

                await self.recordTransactionIfNeeded(amount: estimatedCost)
                self.logOrderPlacedCompliance(
                    description: "Trader buy placed (no mirror pool leg): qty=\(traderQuantity) for \(searchResult.underlyingAsset ?? searchResult.wkn) @ €\(buyOrderPlacementSafeCurrencyString(executedPrice))",
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

            return try await self.placePairedBuyOrder(
                parseAPIClient: parseAPIClient,
                searchResult: searchResult,
                executedPrice: executedPrice,
                orderMode: orderMode,
                limit: limit,
                clientOrderIntentId: clientOrderIntentId,
                traderQuantity: traderQuantity,
                mirrorPoolQuantity: mirrorPoolQuantity,
                estimatedCost: estimatedCost,
                traderId: self.userService.currentUser?.id ?? "",
                traderService: traderService
            )
        } catch let error as AppError {
            return BuyOrderPlacementResult(success: false, error: error)
        } catch {
            let appError = Self.mapPairedBuyFailure(error.toAppError())
            return BuyOrderPlacementResult(
                success: false,
                error: appError
            )
        }
    }

    /// Transaction limit bookkeeping when a limit service is configured.
    func recordTransactionIfNeeded(amount: Double) async {
        if let limitService = transactionLimitService,
           let userId = userService.currentUser?.id {
            try? await limitService.recordTransaction(userId: userId, amount: amount)
        }
    }

    func logOrderPlacedCompliance(description: String, notes: String) {
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
            await self.auditLoggingService.logComplianceEvent(complianceEvent)
        }
    }
}
