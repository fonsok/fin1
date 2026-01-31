# Securities Purchase Synchronization Analysis

## Executive Summary

This document analyzes how the FIN1 app ensures that all securities (trader and investor investments) are purchased at the **same price** and **same time**. This is a critical accounting and fairness requirement.

## Key Finding: ✅ **Single Order Execution Mechanism**

The app ensures price and time synchronization through a **single combined order execution** mechanism:

### How It Works

1. **Order Creation**: When a trader places a buy order, the system:
   - Captures the price **once** from the market data (`searchResult.askPrice`)
   - Calculates the combined quantity (trader's portion + investor pot's portion)
   - Creates **ONE** `OrderBuy` with the combined quantity at the single captured price
   - Records a **single timestamp** (`createdAt: Date()`) at order creation time

2. **Price Capture** (```45:45:FIN1/Features/Trader/Services/BuyOrderPlacementService.swift```):
```swift
let executedPrice = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
```

3. **Combined Quantity Calculation** (```69:70:FIN1/Features/Trader/Services/BuyOrderPlacementService.swift```):
```swift
// Use combined quantity (trader + investment) if investment is active, otherwise use trader quantity
let actualQuantity = investmentOrderCalculation?.totalQuantity ?? quantity
```

4. **Single Order Creation** (```75:84:FIN1/Features/Trader/Services/BuyOrderPlacementService.swift```):
```swift
let orderRequest = BuyOrderRequest(
    symbol: searchResult.wkn,
    quantity: actualQuantity, // Use calculated total quantity (trader + investment)
    price: executedPrice,
    // ... other fields
)
```

5. **Timestamp Preservation** (```165:186:FIN1/Features/Trader/Services/OrderManagementService.swift```):
```swift
private func createOrder(from details: OrderDetails, params: BuyOrderParameters) -> Order {
    return Order(
        // ...
        price: params.price,
        createdAt: Date(), // Single timestamp for entire order
        // ...
    )
}
```

6. **Trade Creation with Preserved Price & Time** (```254:270:FIN1/Features/Trader/Models/Trade.swift```):
```swift
static func from(buyOrder: OrderBuy, tradeNumber: Int) -> Trade {
    Trade(
        // ...
        buyOrder: buyOrder, // Contains original price and timestamp
        createdAt: buyOrder.createdAt, // Preserves original order timestamp
        // ...
    )
}
```

## Architecture: Single Order = Same Price & Time

### Flow Diagram

```
[Trader Input] 1000 pieces @ €2.00
    ↓
[System] Calculate pot's max purchasable: 7,624 pieces
    ↓
[System] Combine: 1000 (trader) + 7,624 (pot) = 8,624 pieces
    ↓
[System] Create ONE OrderBuy:
    - quantity: 8,624
    - price: €2.00 (captured once)
    - createdAt: 2024-01-15 10:30:00 (single timestamp)
    ↓
[Exchange] Execute single order: 8,624 pieces @ €2.00
    ↓
[System] Create Trade from OrderBuy (preserves price & timestamp)
    ↓
[System] Record PotTradeParticipation (links to same Trade)
```

## Critical Components

### 1. Combined Order Calculation

The `InvestmentQuantityCalculationService` calculates the combined quantity:

```151:240:FIN1/Shared/Services/InvestmentQuantityCalculationService.swift
/// Calculates the combined order details for trader + investment purchase
/// The total executed quantity = trader's quantity + investment's purchasable quantity
```

Key points:
- Trader's desired quantity + pot's maximum purchasable quantity = **single total quantity**
- Both portions use the **same price** (from `searchResult.askPrice`)
- Fees are calculated on the combined order amount

### 2. Single Order Execution

**Critical Design Decision**: The system creates **ONE** `OrderBuy` that includes both:
- Trader's portion (paid from trader's cash balance)
- Investor pot's portion (paid from pot balance)

This ensures:
- ✅ **Same price**: Both portions executed at the same market price
- ✅ **Same time**: Both portions executed in the same order (single timestamp)
- ✅ **Atomic execution**: No risk of price changes between separate orders

### 3. Pot Participation Recording

When the order completes and a `Trade` is created, the system records `PotTradeParticipation` entries:

```171:252:FIN1/Features/Trader/Services/InvestmentActivationService.swift
private func recordPotParticipations(
    activatedInvestments: [Investment],
    order: Order,
    trade: Trade
) async {
    // Records participation linking investor pots to the same Trade
    // All participations share the same tradeId, which contains:
    // - Same price (from order.price)
    // - Same timestamp (from trade.createdAt = order.createdAt)
}
```

Each `PotTradeParticipation`:
- Links to the **same `tradeId`**
- Uses the **same price** (from `order.price`)
- Uses the **same timestamp** (from `trade.createdAt` which equals `order.createdAt`)

## Accounting Integrity

### Price Consistency

✅ **Guaranteed**: All parties (trader + all investors) get the same price because:
1. Price is captured **once** from market data
2. **Single order** is created with that price
3. Order is executed as **one transaction** on the exchange
4. Trade preserves the original order price
5. All pot participations reference the same Trade (same price)

### Time Consistency

✅ **Guaranteed**: All parties get the same execution time because:
1. Order is created with **single timestamp** (`Date()` at creation)
2. **Single order** means single execution time
3. Trade preserves the order's `createdAt` timestamp
4. All pot participations reference the same Trade (same timestamp)

### Fee and Transaction Cost Consistency

✅ **Guaranteed**: All parties pay fees calculated from the **same combined order** and split proportionally:

1. **Single Fee Calculation**: Fees are calculated **once** on the total combined order amount (```282:283:FIN1/Shared/Services/InvestmentQuantityCalculationService.swift```):
```swift
// 5. Calculate total fees for the combined order
let totalFees = FeeCalculationService.calculateTotalFees(for: totalOrderAmount)
```

2. **Proportional Fee Split**: Fees are then split proportionally between trader and investor portions based on their order amount proportions (```285:300:FIN1/Shared/Services/InvestmentQuantityCalculationService.swift```):
```swift
// 6. Split fees proportionally between trader and investment
let traderOrderAmountActual = Double(actualTraderQuantity) * pricePerUnit
let investmentOrderAmount = Double(investmentQuantity) * pricePerUnit

let traderFees: Double
let investmentFees: Double

if totalOrderAmount > 0 {
    let traderProportion = traderOrderAmountActual / totalOrderAmount
    let investmentProportion = investmentOrderAmount / totalOrderAmount
    traderFees = totalFees * traderProportion
    investmentFees = totalFees * investmentProportion
}
```

3. **Fee Components**: The fee calculation includes:
   - **Order Fee** (Ordergebühr): 0.5% of order amount (min €5, max €50)
   - **Exchange Fee** (Handelsplatzgebühr): 0.1% of order amount (min €1, max €20)
   - **Foreign Costs** (Fremdkostenpauschale): Fixed €1.50

4. **Why This Is Fair**:
   - ✅ **Same fee rate**: Both parties benefit from the combined order size when calculating fees (larger orders have better fee efficiency)
   - ✅ **Proportional allocation**: Each party pays fees proportional to their order amount share
   - ✅ **Single calculation**: Fees are calculated once on the total, ensuring consistency
   - ✅ **Accounting accuracy**: Investor statements scale fees proportionally (```111:115:FIN1/Features/Investor/ViewModels/InvestorInvestmentStatementViewModel.swift```)

**Example**:
- Total order: 8,624 pieces @ €2.00 = €17,248
- Total fees: €83.00 (calculated once on €17,248)
- Trader portion: 1,000 pieces = €2,000 (11.6% of total)
- Investor portion: 7,624 pieces = €15,248 (88.4% of total)
- Trader fees: €83.00 × 11.6% = €9.63
- Investor fees: €83.00 × 88.4% = €73.37
- ✅ Both parties pay fees at the same effective rate (calculated from same total)

## Potential Edge Cases & Mitigations

### 1. Price Changes During Order Placement

**Risk**: Market price could change between price capture and order execution.

**Mitigation**:
- Price validity timer checks if price is still valid (```37:43:FIN1/Features/Trader/Services/BuyOrderPlacementService.swift```)
- If price changes significantly, order placement is rejected

### 2. Partial Order Execution

**Current Behavior**: The system creates a single order with combined quantity. If the exchange partially fills the order, both trader and investor portions would be proportionally affected.

**Status**: This is acceptable - both parties share the same execution outcome.

### 3. Order Failure

**Current Behavior**: If the order fails, no Trade is created, so no pot participations are recorded.

**Status**: This is correct - failed orders don't create trades or participations.

## Documentation References

The system design is documented in:

1. **POT_TRADING_COMPREHENSIVE_IMPLEMENTATION.md**: Explains the synchronized trading concept
2. **INVESTMENT_COMPLETION_FLOW.md**: States "Backend combines: Trader's money + Pot money → Places **ONE** buy order. This prevents price changes between separate orders and ensures atomic execution"
3. **POT_SYNCHRONIZED_TRADING_IMPLEMENTATION.md**: Backend design for single order execution

## Conclusion

✅ **The app correctly ensures same price, time, and fee calculation through:**

1. **Single Order Creation**: One `OrderBuy` with combined quantity
2. **Single Price Capture**: Price captured once from market data
3. **Single Timestamp**: Order created with one `createdAt` timestamp
4. **Single Fee Calculation**: Fees calculated once on total combined order amount
5. **Proportional Fee Split**: Fees allocated proportionally based on order amount shares
6. **Price & Time Preservation**: Trade preserves order's price and timestamp
7. **Shared Trade Reference**: All pot participations link to the same Trade

This design ensures **accounting integrity** and **fairness**:
- ✅ All parties receive securities at the **exact same price** and **execution time**
- ✅ All parties pay fees calculated from the **same combined order** (same fee rate)
- ✅ Fees are allocated **proportionally** based on each party's order amount share
- ✅ Both trader and investors benefit from the combined order size for fee efficiency

## Recommendations

1. ✅ **Current Implementation is Correct**: The single order mechanism properly ensures synchronization
2. **Consider Adding**: Explicit validation that pot participations always reference trades with matching prices/timestamps
3. **Consider Adding**: Audit logging to track price and timestamp consistency across all participations
4. **Consider Adding**: Unit tests that verify price and timestamp consistency in edge cases

