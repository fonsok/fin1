import Foundation

// MARK: - Buy Order Placement Service Protocol
protocol BuyOrderPlacementServiceProtocol {
    func placeOrder(
        searchResult: SearchResult,
        quantity: Int,
        orderMode: OrderMode,
        limit: String,
        priceValidityProgress: Double,
        investmentOrderCalculation: CombinedOrderCalculationResult?,
        traderService: any TraderServiceProtocol,
        investmentCalculator: any BuyOrderInvestmentCalculatorProtocol
    ) async throws -> BuyOrderPlacementResult
}

// MARK: - Buy Order Placement Result
struct BuyOrderPlacementResult {
    let success: Bool
    let error: AppError?
}

// MARK: - Buy Order Placement Service
/// Handles order placement logic for buy orders
final class BuyOrderPlacementService: BuyOrderPlacementServiceProtocol {
    
    // MARK: - Dependencies
    private let auditLoggingService: any AuditLoggingServiceProtocol
    private let userService: any UserServiceProtocol
    private let transactionLimitService: (any TransactionLimitServiceProtocol)?
    
    // MARK: - Initialization
    init(
        auditLoggingService: any AuditLoggingServiceProtocol,
        userService: any UserServiceProtocol,
        transactionLimitService: (any TransactionLimitServiceProtocol)? = nil
    ) {
        self.auditLoggingService = auditLoggingService
        self.userService = userService
        self.transactionLimitService = transactionLimitService
    }

    func placeOrder(
        searchResult: SearchResult,
        quantity: Int,
        orderMode: OrderMode,
        limit: String,
        priceValidityProgress: Double,
        investmentOrderCalculation: CombinedOrderCalculationResult?,
        traderService: any TraderServiceProtocol,
        investmentCalculator: any BuyOrderInvestmentCalculatorProtocol
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

        // Use combined quantity (trader + investment) if investment is active, otherwise use trader quantity
        let actualQuantity = investmentOrderCalculation?.totalQuantity ?? quantity
        
        // Calculate estimated cost for limit checking
        let estimatedCost = Double(actualQuantity) * executedPrice

        // Create the buy order through TraderService
        // Note: This creates an Order, not a Trade. Trade is created later when order completes.
        // The order quantity includes both trader's portion and investment's portion
        let orderRequest = BuyOrderRequest(
            symbol: searchResult.wkn,
            quantity: actualQuantity, // Use calculated total quantity (trader + investment)
            price: executedPrice,
            optionDirection: searchResult.direction,
            description: searchResult.underlyingAsset,
            orderInstruction: orderMode.rawValue,
            limitPrice: orderMode == .limit ? Double(limit.replacingOccurrences(of: ",", with: ".")) : nil,
            strike: Double(searchResult.strike.replacingOccurrences(of: ",", with: ".")),
            subscriptionRatio: searchResult.subscriptionRatio,
            denomination: searchResult.denomination
        )

        do {
            // ✅ Pre-Trade Compliance: Check transaction limits
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
            
            let order = try await traderService.placeBuyOrder(orderRequest)
            
            // ✅ Record transaction for limit tracking
            if let limitService = transactionLimitService,
               let userId = userService.currentUser?.id {
                try? await limitService.recordTransaction(userId: userId, amount: estimatedCost)
            }
            
            // ✅ MiFID II Compliance: Log order placement
            if let userId = userService.currentUser?.id {
                let underlyingAsset = searchResult.underlyingAsset ?? "N/A"
                let complianceEvent = ComplianceEvent(
                    eventType: .orderPlaced,
                    agentId: userId, // User placing the order
                    customerId: userId,
                    description: "Buy order placed: \(underlyingAsset) - \(actualQuantity) @ €\(executedPrice.formatted(.number.precision(.fractionLength(2)))))",
                    severity: .medium,
                    requiresReview: false,
                    notes: "Order ID: \(order.id), Mode: \(orderMode.rawValue), Symbol: \(searchResult.wkn)"
                )
                
                // Log asynchronously - don't block order placement if logging fails
                Task {
                    await auditLoggingService.logComplianceEvent(complianceEvent)
                }
            }
            
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
}
