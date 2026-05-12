import Foundation

// MARK: - Investor Collection Bill Calculation Service

/// Service for calculating investor collection bill values (buy/sell amounts, quantities, fees, profit)
/// Implements the protocol defined in InvestorCollectionBillCalculationServiceProtocol.swift
@MainActor
final class InvestorCollectionBillCalculationService: InvestorCollectionBillCalculationServiceProtocol {

    // MARK: - Public Methods

    func calculateCollectionBill(input: InvestorCollectionBillInput) throws -> InvestorCollectionBillOutput {
        // Validate input first
        let validation = validateInput(input)
        if !validation.isValid {
            throw AppError.validation(validation.errorMessage ?? "Unknown validation error")
        }

        // Calculate buy leg
        let buyResult = calculateBuyLeg(input: input)

        // Calculate sell leg
        let sellResult = calculateSellLeg(input: input, buyQuantity: buyResult.quantity)

        // Calculate profit
        let grossProfit = sellResult.amount + sellResult.fees - (buyResult.amount + buyResult.fees)
        let roiGrossProfit = sellResult.amount - buyResult.roiInvestedAmount

        return InvestorCollectionBillOutput(
            buyAmount: buyResult.amount,
            buyQuantity: buyResult.quantity,
            buyPrice: input.buyPrice,
            buyFees: buyResult.fees,
            buyFeeDetails: buyResult.feeDetails,
            residualAmount: buyResult.residualAmount,
            sellAmount: sellResult.amount,
            sellQuantity: sellResult.quantity,
            sellAveragePrice: sellResult.averagePrice,
            sellFees: sellResult.fees,
            sellFeeDetails: sellResult.feeDetails,
            grossProfit: grossProfit,
            roiGrossProfit: roiGrossProfit,
            roiInvestedAmount: buyResult.roiInvestedAmount,
            usedLocalFallbackDueToBackendError: false
        )
    }

    func validateInput(_ input: InvestorCollectionBillInput) -> ValidationResult {
        // Check investment capital
        if input.investmentCapital <= 0 {
            return .error("Investment capital must be positive")
        }

        // Check buy price
        if input.buyPrice <= 0 {
            return .error("Buy price must be positive")
        }

        // Check trade total quantity
        if input.tradeTotalQuantity <= 0 {
            return .error("Trade total quantity must be positive")
        }

        // Check ownership percentage
        if input.ownershipPercentage <= 0 || input.ownershipPercentage > 1.0 {
            return .error("Ownership percentage must be between 0 (exclusive) and 1.0 (inclusive)")
        }

        // Check for invoice quantity mismatch (warning only)
        if let buyInvoice = input.buyInvoice {
            let invoiceQty = buyInvoice.securitiesItems.reduce(0.0) { $0 + $1.quantity }
            let calculatedQty = input.investmentCapital / input.buyPrice
            let scaledInvoiceQty = invoiceQty * input.ownershipPercentage
            let difference = abs(scaledInvoiceQty - calculatedQty)
            if difference > 1.0 {
                return .warning("Invoice quantity (\(scaledInvoiceQty)) differs significantly from calculated quantity (\(calculatedQty))")
            }
        }

        return .valid
    }

    // MARK: - Private Types

    private struct BuyLegResult {
        let amount: Double
        let quantity: Double
        let fees: Double
        let feeDetails: [InvestorFeeDetail]
        let roiInvestedAmount: Double
        let residualAmount: Double
    }

    private struct SellLegResult {
        let amount: Double
        let quantity: Double
        let averagePrice: Double
        let fees: Double
        let feeDetails: [InvestorFeeDetail]
    }

    // MARK: - Private Methods

    private func calculateBuyLeg(input: InvestorCollectionBillInput) -> BuyLegResult {
        let investmentCapital = input.investmentCapital

        print("📊 InvestorCollectionBillCalculationService.calculateBuyLeg")
        print("   💰 Investment Capital: €\(String(format: "%.2f", investmentCapital))")
        print("   💵 Buy Price: €\(String(format: "%.2f", input.buyPrice))")

        // Solve for buyAmount where: buyAmount + fees(buyAmount) = investmentCapital
        // This ensures Total Buy Cost ≤ Investment Amount (accounting principle)
        let finalBuyAmount = solveForBuyAmount(investmentCapital: investmentCapital, tolerance: 0.01)

        // Calculate quantity from the final buyAmount: buyAmount / buy price, rounded down to whole number
        // CRITICAL: Only whole pieces/units can be traded, not decimals (e.g., 22.78 → 22.00)
        let calculatedQty = finalBuyAmount / input.buyPrice
        let buyQuantity = floor(calculatedQty) // Round down to whole number (integer)

        // Recalculate actual buyAmount based on rounded quantity (ensures whole units only)
        // This may differ from the binary search result due to rounding
        let actualBuyAmount = buyQuantity * input.buyPrice

        // Recalculate fees based on actual buyAmount (fees depend on order amount)
        let actualBuyFeeBreakdown = FeeCalculationService.createFeeBreakdown(for: actualBuyAmount)
        let actualBuyFeeDetails = actualBuyFeeBreakdown.map { feeDetail in
            InvestorFeeDetail(
                label: feeDetail.name,
                amount: feeDetail.amount
            )
        }
        let actualBuyFees = actualBuyFeeDetails.reduce(0) { $0 + $1.amount }

        // Calculate actual total buy cost and residual
        var currentQuantity = buyQuantity
        var currentBuyAmount = actualBuyAmount
        var currentBuyFees = actualBuyFees
        var currentBuyFeeDetails = actualBuyFeeDetails
        var currentTotalBuyCost = actualBuyAmount + actualBuyFees
        var residualAmount = investmentCapital - currentTotalBuyCost

        // CRITICAL: Loop to maximize capital utilization
        // Keep buying more units as long as we can afford them
        // This ensures residual is ALWAYS less than the cost to buy one more unit
        var iterations = 0
        let maxIterations = 100 // Safety limit

        while iterations < maxIterations {
            iterations += 1

            // Calculate the ACTUAL cost to buy one more unit (with proper fee scaling)
            let nextQuantity = currentQuantity + 1
            let nextBuyAmount = nextQuantity * input.buyPrice
            let nextFees = FeeCalculationService.calculateTotalFees(for: nextBuyAmount)
            let nextTotalCost = nextBuyAmount + nextFees

            // Can we afford one more unit?
            if nextTotalCost <= investmentCapital {
                // Yes! Buy one more unit
                print("   🔧 Buying one more unit: Quantity \(currentQuantity) → \(nextQuantity)")

                let nextBuyFeeBreakdown = FeeCalculationService.createFeeBreakdown(for: nextBuyAmount)
                let nextBuyFeeDetails = nextBuyFeeBreakdown.map { feeDetail in
                    InvestorFeeDetail(
                        label: feeDetail.name,
                        amount: feeDetail.amount
                    )
                }

                currentQuantity = nextQuantity
                currentBuyAmount = nextBuyAmount
                currentBuyFees = nextFees
                currentBuyFeeDetails = nextBuyFeeDetails
                currentTotalBuyCost = nextTotalCost
                residualAmount = investmentCapital - currentTotalBuyCost
            } else {
                // No, can't afford one more unit - we're done
                print("   ✅ Cannot afford one more unit (need €\(String(format: "%.2f", nextTotalCost)), have €\(String(format: "%.2f", investmentCapital)))")
                break
            }
        }

        print("   💵 Final buy amount (securities value): €\(String(format: "%.2f", currentBuyAmount))")
        print("   💵 Final buy fees: €\(String(format: "%.2f", currentBuyFees))")
        print("   💵 Final Total Buy Cost: €\(String(format: "%.2f", currentTotalBuyCost))")
        print("   💵 Final residual amount: €\(String(format: "%.2f", residualAmount))")
        print("   📊 Final quantity: \(currentQuantity)")

        // Verify Total Buy Cost ≤ Investment Capital (accounting principle)
        if currentTotalBuyCost > investmentCapital {
            print("⚠️ WARNING: Total Buy Cost (\(String(format: "%.2f", currentTotalBuyCost))) exceeds Investment Capital (\(String(format: "%.2f", investmentCapital)))")
        }

        // CRITICAL VALIDATION: Residual must be less than buy price
        // If residual >= buy price, something is wrong (we could have bought more)
        if residualAmount >= input.buyPrice {
            print("⚠️ CRITICAL WARNING: Residual (\(String(format: "%.2f", residualAmount))) >= buy price (\(String(format: "%.2f", input.buyPrice))) - calculation error!")
        }

        // ROI invested amount uses pure securities value (quantity × price)
        let roiInvestedAmount = currentQuantity * input.buyPrice

        return BuyLegResult(
            amount: currentBuyAmount,
            quantity: currentQuantity,
            fees: currentBuyFees,
            feeDetails: currentBuyFeeDetails,
            roiInvestedAmount: roiInvestedAmount,
            residualAmount: residualAmount
        )
    }

    /// Solves for buyAmount where: buyAmount + fees(buyAmount) = investmentCapital
    /// Uses binary search since fees are a function of buyAmount
    private func solveForBuyAmount(investmentCapital: Double, tolerance: Double) -> Double {
        var low = 0.0
        var high = investmentCapital
        var result = 0.0

        // Binary search to find buyAmount where buyAmount + fees(buyAmount) ≈ investmentCapital
        // We want the largest buyAmount such that totalCost ≤ investmentCapital
        for _ in 0..<100 { // Max 100 iterations
            let mid = (low + high) / 2
            let fees = FeeCalculationService.calculateTotalFees(for: mid)
            let totalCost = mid + fees

            if abs(totalCost - investmentCapital) < tolerance {
                result = mid
                break
            }

            if totalCost < investmentCapital {
                result = mid // This is a valid solution, but we might find a better one
                low = mid
            } else {
                high = mid
            }
        }

        // Final validation: ensure we don't exceed investment capital
        let finalFees = FeeCalculationService.calculateTotalFees(for: result)
        let finalTotalCost = result + finalFees

        if finalTotalCost > investmentCapital {
            // Back off slightly if we exceeded
            result = result * 0.99
        }

        return result
    }

    private func calculateSellLeg(input: InvestorCollectionBillInput, buyQuantity: Double) -> SellLegResult {
        let sellInvoices = input.sellInvoices

        guard !sellInvoices.isEmpty else {
            return SellLegResult(
                amount: 0,
                quantity: 0,
                averagePrice: 0,
                fees: 0,
                feeDetails: []
            )
        }

        // Calculate total sell quantity and value from invoices
        let totalSellQtyFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
            total + invoice.securitiesItems.reduce(0.0) { $0 + $1.quantity }
        }
        let totalSellValueFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
            total + invoice.securitiesTotal
        }

        // Calculate sell percentage (what portion of the trade was sold)
        let sellPercentage = input.tradeTotalQuantity > 0 ? (totalSellQtyFromInvoices / input.tradeTotalQuantity) : 0.0

        // Investor sells proportionally to trader sell percentage
        // CRITICAL: Round down to whole number - only whole pieces/units can be traded
        let calculatedSellQty = buyQuantity * sellPercentage
        let investorSellQuantity = floor(calculatedSellQty)

        // Calculate average sell price from invoices
        let sellAvgPrice = totalSellQtyFromInvoices > 0 ? totalSellValueFromInvoices / totalSellQtyFromInvoices : 0.0

        // CRITICAL FIX: Calculate sell amount from actual quantity and price
        // This ensures sell amount matches displayed quantity (accounting principle)
        // Previous incorrect approach: totalSellValueFromInvoices * ownershipPercentage
        let investorSellValue = investorSellQuantity * sellAvgPrice

        // Fees from invoices (scaled by sell share based on quantity ratio)
        let sellShare = totalSellQtyFromInvoices > 0 ? (investorSellQuantity / totalSellQtyFromInvoices) : input.ownershipPercentage
        let sellFeeDetails = buildFeeDetails(from: sellInvoices, scale: sellShare)
        let investorSellFees = sellFeeDetails.reduce(0) { $0 + $1.amount }

        return SellLegResult(
            amount: investorSellValue,
            quantity: investorSellQuantity,
            averagePrice: sellAvgPrice,
            fees: investorSellFees,
            feeDetails: sellFeeDetails
        )
    }

    private func buildFeeDetails(from invoices: [Invoice], scale: Double) -> [InvestorFeeDetail] {
        guard scale > 0 else { return [] }

        return invoices.flatMap { invoice -> [InvestorFeeDetail] in
            invoice.items
                .filter { $0.itemType != .securities }
                .map { item in
                    InvestorFeeDetail(
                        label: item.description,
                        amount: item.totalAmount * scale
                    )
                }
        }
        .filter { abs($0.amount) > 0.0001 }
    }

    // MARK: - Backend Integration

    func calculateCollectionBillWithBackend(
        input: InvestorCollectionBillInput,
        settlementAPIService: (any SettlementAPIServiceProtocol)?,
        tradeId: String?,
        investmentId: String?
    ) async throws -> InvestorCollectionBillOutput {
        var usedLocalFallbackDueToBackendError = false
        if let api = settlementAPIService, let tradeId, let investmentId {
            do {
                let response = try await api.fetchInvestorCollectionBills(
                    limit: 1, skip: 0, investmentId: investmentId, tradeId: tradeId
                )
                print("🔍 InvestorCollectionBillCalculationService: backend returned \(response.collectionBills.count) bill(s) for trade=\(tradeId) investment=\(investmentId)")
                if let bill = response.collectionBills.first {
                    let hasMeta = bill.metadata != nil
                    let hasBuyLeg = bill.metadata?.buyLeg != nil
                    print("   • bill.id=\(bill.objectId) hasMetadata=\(hasMeta) hasBuyLeg=\(hasBuyLeg)")
                    if let meta = bill.metadata {
                        if let output = mapBackendToOutput(metadata: meta, input: input) {
                            print("✅ InvestorCollectionBillCalculationService: Using backend data for trade \(tradeId)")
                            return output
                        } else {
                            print("⚠️ InvestorCollectionBillCalculationService: metadata present but mapping failed (buyLeg missing) — falling back to local")
                        }
                    }
                } else {
                    print("⚠️ InvestorCollectionBillCalculationService: backend returned no bills — falling back to local for trade=\(tradeId)")
                }
            } catch {
                print("⚠️ InvestorCollectionBillCalculationService: Backend fetch failed, falling back to local: \(error.localizedDescription)")
                usedLocalFallbackDueToBackendError = true
            }
        } else {
            print("⚠️ InvestorCollectionBillCalculationService: backend disabled (api=\(settlementAPIService != nil) tradeId=\(tradeId ?? "nil") investmentId=\(investmentId ?? "nil"))")
        }
        var output = try calculateCollectionBill(input: input)
        if usedLocalFallbackDueToBackendError {
            output = InvestorCollectionBillOutput(
                buyAmount: output.buyAmount,
                buyQuantity: output.buyQuantity,
                buyPrice: output.buyPrice,
                buyFees: output.buyFees,
                buyFeeDetails: output.buyFeeDetails,
                residualAmount: output.residualAmount,
                sellAmount: output.sellAmount,
                sellQuantity: output.sellQuantity,
                sellAveragePrice: output.sellAveragePrice,
                sellFees: output.sellFees,
                sellFeeDetails: output.sellFeeDetails,
                grossProfit: output.grossProfit,
                roiGrossProfit: output.roiGrossProfit,
                roiInvestedAmount: output.roiInvestedAmount,
                usedLocalFallbackDueToBackendError: true
            )
        }
        return output
    }

    /// Maps backend collection bill metadata to local output model.
    private func mapBackendToOutput(metadata meta: BackendCollectionBillMetadata, input: InvestorCollectionBillInput) -> InvestorCollectionBillOutput? {
        guard let buyLeg = meta.buyLeg else { return nil }

        let buyQty = buyLeg.quantity ?? 0
        let buyPrice = buyLeg.price ?? input.buyPrice
        let buyAmt = buyLeg.amount ?? (buyQty * buyPrice)
        let buyFeesTotal = buyLeg.fees?.totalFees ?? 0
        let residual = buyLeg.residualAmount ?? 0

        let buyFeeDetails = buildFeeDetailsFromBreakdown(buyLeg.fees)

        let sellQty = meta.sellLeg?.quantity ?? 0
        let sellPrice = meta.sellLeg?.price ?? 0
        let sellAmt = meta.sellLeg?.amount ?? (sellQty * sellPrice)
        let sellFeesTotal = meta.sellLeg?.fees?.totalFees ?? 0
        let sellFeeDetails = buildFeeDetailsFromBreakdown(meta.sellLeg?.fees)

        let grossProfit = meta.grossProfit ?? (sellAmt - sellFeesTotal - buyAmt - buyFeesTotal)
        let roiInvestedAmount = buyQty * buyPrice
        let roiGrossProfit = sellAmt - roiInvestedAmount

        return InvestorCollectionBillOutput(
            buyAmount: buyAmt,
            buyQuantity: buyQty,
            buyPrice: buyPrice,
            buyFees: buyFeesTotal,
            buyFeeDetails: buyFeeDetails,
            residualAmount: residual,
            sellAmount: sellAmt,
            sellQuantity: sellQty,
            sellAveragePrice: sellPrice,
            sellFees: sellFeesTotal,
            sellFeeDetails: sellFeeDetails,
            grossProfit: grossProfit,
            roiGrossProfit: roiGrossProfit,
            roiInvestedAmount: roiInvestedAmount,
            usedLocalFallbackDueToBackendError: false
        )
    }

    private func buildFeeDetailsFromBreakdown(_ fees: BackendFeeBreakdown?) -> [InvestorFeeDetail] {
        guard let fees else { return [] }
        var details: [InvestorFeeDetail] = []
        if let v = fees.orderFee, abs(v) > 0.0001 {
            details.append(InvestorFeeDetail(label: "Ordergebühr", amount: v))
        }
        if let v = fees.exchangeFee, abs(v) > 0.0001 {
            details.append(InvestorFeeDetail(label: "Börsenplatzgebühr", amount: v))
        }
        if let v = fees.foreignCosts, abs(v) > 0.0001 {
            details.append(InvestorFeeDetail(label: "Fremdkostenpauschale", amount: v))
        }
        return details
    }
}
