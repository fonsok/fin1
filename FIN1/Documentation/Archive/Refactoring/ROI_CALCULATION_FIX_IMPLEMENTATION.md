# Concrete ROI Calculation Fix Implementation

## Problem

Trader ROI (112%) and Investor Return (114.46%) show different values for the same trade due to:
1. Different calculation methods (invoice-based vs order-based)
2. Rounding differences in proportional fee calculations
3. Inconsistent denominator bases

## Solution: Standardize on Invoice-Based Calculation

**Both trader and investor should use the same invoice-based profit calculation**, scaled proportionally for investors.

## Implementation Steps

### Step 1: Create Proportional Invoice-Based Profit Calculation

Add a new method to `ProfitCalculationService` that calculates investor's proportional profit:

**File**: `FIN1/Shared/Services/ProfitCalculationService.swift`

```swift
/// Calculates investor's proportional taxable profit from invoices
/// Uses the same calculation as trader but scaled by ownership percentage
/// - Parameters:
///   - buyInvoice: The buy transaction invoice
///   - sellInvoices: Array of sell transaction invoices
///   - ownershipPercentage: Investor's ownership percentage (0.0 to 1.0)
/// - Returns: Investor's proportional taxable profit amount
static func calculateInvestorTaxableProfit(
    buyInvoice: Invoice?,
    sellInvoices: [Invoice],
    ownershipPercentage: Double
) -> Double {
    // Calculate full trade profit using invoice-based method (same as trader)
    let fullTradeProfit = calculateTaxableProfit(
        buyInvoice: buyInvoice,
        sellInvoices: sellInvoices
    )

    // Scale proportionally by ownership percentage
    return fullTradeProfit * ownershipPercentage
}
```

### Step 2: Update Investor Return Calculation

Modify `calculateInvestorTotals` in `InvestmentCompletionService` to use invoice-based calculation:

**File**: `FIN1/Features/Investor/Services/InvestmentCompletionService.swift`

**Replace** ```258:304:FIN1/Features/Investor/Services/InvestmentCompletionService.swift``` with:

```swift
private func calculateInvestorTotals(
    for participations: [PotTradeParticipation]
) -> (grossProfit: Double, investedAmount: Double)? {
    guard let invoiceService = invoiceService,
          let tradeLifecycleService = tradeLifecycleService,
          !participations.isEmpty else {
        return nil
    }

    var totalGross = 0.0
    var totalInvested = 0.0
    let trades = tradeLifecycleService.completedTrades

    for participation in participations {
        guard let trade = trades.first(where: { $0.id == participation.tradeId }) else { continue }
        let invoices = invoiceService.getInvoicesForTrade(trade.id)
        let buyInvoice = invoices.first { $0.transactionType == .buy }
        let sellInvoices = invoices.filter { $0.transactionType == .sell }

        // ✅ FIX: Use invoice-based profit calculation (same as trader)
        // This ensures both trader and investor use identical calculation method
        let investorProfit = ProfitCalculationService.calculateInvestorTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: sellInvoices,
            ownershipPercentage: participation.ownershipPercentage
        )
        totalGross += investorProfit

        // ✅ FIX: Use same denominator as trader ROI calculation
        // Trader ROI uses: buyOrder.price * totalSoldQuantity
        // Investor Return uses: (buyOrder.price * totalSoldQuantity) * ownershipPercentage
        guard trade.totalSoldQuantity > 0 else { continue }
        let traderDenominator = trade.buyOrder.price * Double(trade.totalSoldQuantity)
        let investorDenominator = traderDenominator * participation.ownershipPercentage
        totalInvested += investorDenominator
    }

    guard totalInvested > 0 else {
        return nil
    }

    return (totalGross, totalInvested)
}
```

### Step 3: Update Trader ROI to Use Same Method

Ensure trader ROI also uses invoice-based calculation consistently:

**File**: `FIN1/Features/Trader/Models/Trade.swift`

The current implementation already uses `currentPnL` which comes from `calculatedProfit` (invoice-based), so this is already correct. However, add a comment for clarity:

```swift
var roi: Double? {
    guard let pnl = currentPnL, totalSoldQuantity > 0 else { return nil }
    // ✅ Uses invoice-based profit calculation (calculateTaxableProfit)
    // This matches investor return calculation method
    let totalBuyCost = buyOrder.price * totalSoldQuantity
    return (pnl / totalBuyCost) * 100
}
```

### Step 4: Add Validation Test

Create a unit test to verify both calculations match:

**File**: `FIN1Tests/ROICalculationConsistencyTests.swift` (new file)

```swift
import XCTest
@testable import FIN1

final class ROICalculationConsistencyTests: XCTestCase {

    func testTraderAndInvestorROIMatch() {
        // Given: A completed trade with invoices
        let buyInvoice = createBuyInvoice(securitiesValue: 2000.0, fees: 83.0)
        let sellInvoice = createSellInvoice(securitiesValue: 4500.0, fees: 83.0)
        let trade = createCompletedTrade(buyInvoice: buyInvoice, sellInvoices: [sellInvoice])

        // When: Calculate trader ROI
        let traderROI = trade.roi ?? 0.0

        // And: Calculate investor return (50% ownership)
        let ownershipPercentage = 0.5
        let investorProfit = ProfitCalculationService.calculateInvestorTaxableProfit(
            buyInvoice: buyInvoice,
            sellInvoices: [sellInvoice],
            ownershipPercentage: ownershipPercentage
        )
        let investorDenominator = (trade.buyOrder.price * Double(trade.totalSoldQuantity)) * ownershipPercentage
        let investorReturn = (investorProfit / investorDenominator) * 100

        // Then: Both should match (within rounding tolerance)
        XCTAssertEqual(traderROI, investorReturn, accuracy: 0.01,
                      "Trader ROI (\(traderROI)%) and Investor Return (\(investorReturn)%) should match")
    }

    // Helper methods...
}
```

## Benefits

1. **Consistency**: Both trader and investor use the same invoice-based calculation
2. **Accuracy**: Eliminates rounding differences from proportional fee calculations
3. **Maintainability**: Single source of truth for profit calculation
4. **Testability**: Easy to verify both calculations match

## Migration Notes

- **Backward Compatibility**: Existing completed investments will recalculate on next completion check
- **Performance**: No significant impact (same number of calculations)
- **Data Integrity**: No data migration needed (calculation-only change)

## Verification

After implementation, verify:
1. ✅ Trader ROI and Investor Return match for the same trade
2. ✅ All existing completed investments recalculate correctly
3. ✅ Unit tests pass
4. ✅ No regression in profit calculations

## Rollout Plan

1. **Phase 1**: Add new `calculateInvestorTaxableProfit` method
2. **Phase 2**: Update `calculateInvestorTotals` to use new method
3. **Phase 3**: Add unit tests
4. **Phase 4**: Test with existing completed investments
5. **Phase 5**: Deploy and verify calculations match


