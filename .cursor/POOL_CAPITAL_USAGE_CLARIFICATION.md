# Pool Capital Usage: Correct Understanding

> **Note**: This document clarifies capital maximization behavior. The implementation now sums individual investment amounts rather than using pool-level balances, but the core principle (maximizing capital utilization) remains unchanged.

## ❌ Incorrect Statements

The following statements are **NOT correct**:

1. ❌ "If order value ≥ pool capital: 100% of pool capital is used"
2. ❌ "If order value < pool capital: Only the order value amount is used"

## ✅ Correct Behavior

The system **always maximizes capital utilization** from the investment pool, regardless of "order value". Here's what actually happens:

### How It Really Works

**The system does NOT compare "order value" to "pool capital".**

Instead, it:

1. **Calculates maximum affordable quantity** from pool capital
2. **Uses as much pool capital as possible** (up to what can be afforded with fees)
3. **Does NOT limit usage based on trader's desired order value**

### Code Evidence

**Location**: `BuyOrderInvestmentCalculator.swift:46-64` and `InvestmentQuantityCalculationService.swift:230`

```swift
// Calculate investment balance from sum of all available investments
let allReservedInvestments = investmentService.getInvestments(forTrader: traderId)
    .filter { investment in
        investment.status == .active &&
        (investment.reservationStatus == .reserved ||
         investment.reservationStatus == .active ||
         investment.reservationStatus == .executing ||
         investment.reservationStatus == .closed)
    }

// Calculate total available capital from all reserved investments
let investmentBalance = allReservedInvestments.reduce(0.0) { $0 + $1.amount }

// Then calculate maximum investment quantity
let investmentQuantity = calculateMaxPurchasableQuantity(
    investmentBalance: investmentBalance,  // ← Sum of individual investment amounts
    pricePerSecurity: pricePerSecurity,
    denomination: denomination,
    subscriptionRatio: subscriptionRatio,
    minimumOrderAmount: nil
)
```

**Key Points**:
- `calculateMaxPurchasableQuantity()` finds the **maximum quantity** that can be afforded
- It uses **ALL available `investmentBalance`** (sum of individual investment amounts)
- It accounts for fees: `(quantity × pricePerUnit + fees) <= investmentBalance`
- It does **NOT** compare to trader's desired order value
- **Implementation Note**: Investment balance is calculated by summing individual `investment.amount` values, not from pool-level balance

### What "Order Value" Actually Means

The term "order value" is ambiguous. The system works with:

1. **Trader's desired quantity** (input from user) - **IGNORED** for investment calculation
2. **Pool capital** (`investmentBalance`) - **MAXIMIZED** for investment calculation
3. **Maximum affordable quantity** - Calculated from pool capital

### Example Scenarios

#### Scenario 1: Pool Capital = €1,000, Trader wants 50 units @ €10 = €500

**Incorrect Understanding**:
- Order value (€500) < Pool capital (€1,000)
- Therefore: Only €500 is used ❌

**Correct Behavior**:
- System calculates: Maximum affordable from €1,000 pool capital
- Result: Uses ~€990 (accounting for fees) ✅
- **Uses nearly ALL pool capital, not just €500**

#### Scenario 2: Pool Capital = €500, Trader wants 100 units @ €10 = €1,000

**Incorrect Understanding**:
- Order value (€1,000) ≥ Pool capital (€500)
- Therefore: 100% of pool capital (€500) is used ❌

**Correct Behavior**:
- System calculates: Maximum affordable from €500 pool capital
- Result: Uses ~€490 (accounting for fees) ✅
- **Uses nearly ALL pool capital, but limited by available capital**

### The Actual Algorithm

```swift
func calculateMaxPurchasableQuantity(
    investmentBalance: Double,  // Pool capital
    pricePerSecurity: Double,
    ...
) -> Int {
    // 1. Calculate price per unit
    let pricePerUnit = pricePerSecurity / subscriptionRatio

    // 2. Calculate theoretical maximum (without fees)
    let maxPossibleQuantity = Int(investmentBalance / pricePerUnit)

    // 3. Binary search to find maximum where:
    //    (quantity × pricePerUnit + fees) <= investmentBalance
    // Returns maximum affordable quantity

    return bestQuantity
}
```

**This algorithm**:
- ✅ Always maximizes from available balance
- ✅ Accounts for fees
- ✅ Does NOT compare to "order value"
- ✅ Does NOT limit based on trader's desired quantity

### Why This Design?

**Capital Maximization Strategy**:
- The system is designed to **maximize capital utilization**
- Similar to a "mirror trade" - uses all available capital
- Ensures no capital is left idle
- Trader's desired quantity is treated as a "suggestion", not a limit

### Correct Statement

✅ **"The system always uses the maximum amount of pool capital that can be afforded, accounting for fees, regardless of the trader's desired order value."**

### Summary

| Aspect | Incorrect Understanding | Correct Behavior |
|--------|------------------------|------------------|
| **Comparison** | Compares "order value" to "pool capital" | No such comparison exists |
| **Usage Logic** | Uses order value if < pool, uses 100% if ≥ pool | Always maximizes from pool capital |
| **Trader Input** | Limits investment usage to order value | Trader's desired quantity is ignored for investment |
| **Result** | Variable usage based on order value | Always maximum affordable from pool |

---

## Conclusion

Both statements are **incorrect**. The system:

1. **Always maximizes** capital utilization from the pool
2. **Does NOT** compare "order value" to pool capital
3. **Does NOT** limit usage based on trader's desired quantity
4. **Uses** as much pool capital as possible (up to what can be afforded with fees)

The investment quantity is calculated independently from the trader's desired quantity, using a binary search algorithm to find the maximum affordable quantity from the available pool capital.

