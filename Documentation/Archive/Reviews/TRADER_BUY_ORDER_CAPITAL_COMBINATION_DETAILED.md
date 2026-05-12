# Trader Buy Orders: Detailed Capital Combination Mechanism

## Overview

This document provides a comprehensive explanation of how the system combines trader's own capital with investment pool capital when placing buy orders, including detailed calculation algorithms, fee splitting, and practical examples.

---

## Terminology: Order Amount Types

**IMPORTANT**: Throughout this document, we use specific terms for different order amounts. Here's the clarification:

### Order Amount Types

1. **`testOrderAmount`** (or **`candidateOrderAmount`**)
   - Used during binary search algorithm
   - Represents the securities value for a test quantity being evaluated
   - Formula: `testOrderAmount = testQuantity × pricePerUnit`
   - **Context**: Algorithm testing if a quantity is affordable

2. **`traderOrderAmount`** (or **`traderSecuritiesValue`**)
   - Securities value portion paid by trader's own capital
   - Formula: `traderOrderAmount = traderQuantity × pricePerSecurity`
   - **Context**: Trader's portion of the combined order

3. **`investmentOrderAmount`** (or **`investmentSecuritiesValue`** or **`poolOrderAmount`**)
   - Securities value portion paid by investment pool capital
   - Formula: `investmentOrderAmount = investmentQuantity × pricePerSecurity`
   - **Context**: Investment pool's portion of the combined order

4. **`totalOrderAmount`** (or **`totalSecuritiesValue`**)
   - Total securities value of the entire order (trader + investment combined)
   - Formula: `totalOrderAmount = totalQuantity × pricePerSecurity`
   - **Context**: Complete order value before fees

### Cost Types

- **`orderAmount`**: Securities value (quantity × price) - **does NOT include fees**
- **`totalCost`**: Securities value + fees - **includes all fees**
- **`traderTotalCost`**: Trader's securities value + trader's share of fees
- **`investmentTotalCost`**: Investment's securities value + investment's share of fees

### Key Distinction

**Securities Value vs Total Cost:**
- **Securities Value** (`orderAmount`): What you're buying (quantity × price)
- **Total Cost**: What you're paying (securities value + fees)
- Example: Securities value = €1,000, Fees = €10, Total Cost = €1,010

---

## Part 1: Investment Capital Calculation

### 1.1 Calculation Flow

**When a trader opens the buy order form:**

1. **User Authentication Check**
   - System checks if current user is logged in
   - Verifies user role is `.trader` (not investor)
   - If not trader, investment calculation is skipped

2. **Trader ID Resolution**
   - Gets `currentUser.id` as `traderId`
   - This ID is used to find investments

3. **Available Investments Query**
   ```swift
   // Get all investments for trader
   let allReservedInvestments = investmentService.getInvestments(forTrader: traderId)
       .filter { investment in
           investment.status == .active &&
           (investment.reservationStatus == .reserved ||
            investment.reservationStatus == .active ||
            investment.reservationStatus == .executing ||
            investment.reservationStatus == .closed)
       }
   ```
   - Queries all investments for this trader
   - Filters for investments with:
     - Status: `.active`
     - Reservation status: `.reserved`, `.active`, `.executing`, or `.closed`
   - Includes all available investments (not just first pool)

4. **Balance Calculation**
   ```swift
   // Calculate total available capital from all reserved investments
   let investmentBalance = allReservedInvestments.reduce(0.0) { $0 + $1.amount }
   ```
   - **Sums individual investment amounts** to calculate total available capital
   - `traderCashBalance = cashBalanceService.currentBalance`
   - Both balances are in EUR

**Key Points**:
- The system **sums all available investment amounts** (not pool-based)
- Uses `investment.amount` from each individual investment
- This approach ensures accurate capital calculation that matches actual usage
- **Why not pool-based?** Pool-level balance (`activeInvestmentPool.currentBalance`) is static and may not reflect actual available capital, leading to underutilization

---

## Part 2: Maximum Purchasable Quantity Calculation

### 2.1 Algorithm Overview

The system uses a **binary search algorithm** to find the maximum quantity that can be purchased with a given balance, accounting for:
- Trading fees (order fee, exchange fee, foreign costs)
- Denomination constraints (e.g., must buy in multiples of 10)
- Subscription ratios (e.g., 1 unit = 0.1 shares)
- Minimum order amounts

### 2.2 Core Calculation Formula

For any given test quantity `q` being evaluated:

```
testOrderAmount = q × pricePerUnit          // Securities value for this quantity
fees = calculateTotalFees(testOrderAmount)  // Fees calculated on securities value
totalCost = testOrderAmount + fees          // Total cost (securities + fees)

If totalCost <= availableBalance:
    ✅ Can afford quantity q
Else:
    ❌ Cannot afford quantity q
```

**Note**: `testOrderAmount` is the securities value for testing purposes. The actual order amounts (trader/investment/total) are calculated later in the combined order flow.

### 2.3 Fee Calculation Details

**Fee Structure:**
- **Order Fee**: 0.5% of securities value (min €5, max €50)
- **Exchange Fee**: 0.1% of securities value (min €1, max €20)
- **Foreign Costs**: Fixed €1.50

**Total Fees Formula:**
```
totalFees = orderFee + exchangeFee + foreignCosts
```

**Example:**
- Securities value (test order amount): €1,000
- Order fee: €5.00 (0.5% = €5, but min is €5)
- Exchange fee: €1.00 (0.1% = €1, but min is €1)
- Foreign costs: €1.50
- **Total fees: €7.50**

### 2.4 Binary Search Algorithm

**Algorithm Steps:**

1. **Calculate Upper Bound**
   - `maxPossibleQuantity = floor(balance / pricePerUnit)`
   - This is the theoretical maximum if fees were zero

2. **Apply Denomination Constraint** (if specified)
   - Round down to nearest valid denomination
   - Example: If denomination = 10, and maxPossibleQuantity = 97, then upperBound = 90

3. **Binary Search Loop**
   ```
   low = minimumRequiredQuantity (or denomination if specified)
   high = upperBound

   while low <= high:
       mid = (low + high) / 2
       testOrderAmount = mid × pricePerUnit        // Securities value for test quantity
       fees = calculateTotalFees(testOrderAmount)   // Fees on test securities value
       totalCost = testOrderAmount + fees           // Total cost for this test quantity

       if totalCost <= balance:
           bestQuantity = mid                       // Can afford this quantity
           low = mid + 1  // Try more
       else:
           high = mid - 1  // Try less
   ```

4. **Return Result**
   - Returns `bestQuantity` (maximum quantity that can be afforded)

**Why Binary Search?**
- Efficient: O(log n) time complexity
- Handles large quantities efficiently
- Accounts for non-linear fee structure (min/max caps)

### 2.5 Denomination Constraints

**What is Denomination?**
- Some securities must be purchased in specific multiples
- Example: Must buy in multiples of 10 (denomination = 10)
- Example: Must buy in multiples of 100 (denomination = 100)

**How It Works:**
- If denomination is specified, quantity must be a multiple of denomination
- Algorithm searches in denomination increments
- Example: If denomination = 10, searches: 10, 20, 30, 40, ...

**Code:**
```swift
if let denomination = denomination {
    // Start from denomination
    var testQuantity = denomination
    while testQuantity <= upperBound {
        // Test if we can afford testQuantity
        // If yes, try next denomination multiple
        testQuantity += denomination
    }
}
```

### 2.6 Subscription Ratio

**What is Subscription Ratio?**
- Converts between "units" (what you buy) and "shares" (what you own)
- Example: subscriptionRatio = 0.1 means 10 units = 1 share
- Example: subscriptionRatio = 10.0 means 1 unit = 10 shares

**Price Per Unit Calculation:**
```
pricePerUnit = pricePerSecurity / subscriptionRatio
```

**Example:**
- Security price: €10.00 per share
- Subscription ratio: 0.1 (10 units = 1 share)
- Price per unit: €10.00 / 0.1 = €1.00 per unit

**Quantity Calculation:**
- System calculates quantity in **units**
- Converts to shares when needed: `shares = units / subscriptionRatio`

### 2.7 Minimum Order Amount

**What is Minimum Order Amount?**
- Some securities require a minimum order value
- Example: Minimum order = €100
- If order value < minimum, order is rejected

**Validation:**
- Applied to **total order** (trader + investment combined)
- Individual portions may be below minimum, but total must meet it

---

## Part 3: Combined Order Calculation

### 3.1 Calculation Flow

**The `calculateCombinedOrderDetails` function:**

1. **Calculate Trader Maximum Quantity**
   ```swift
   let actualTraderQuantity = calculateMaxPurchasableQuantity(
       investmentBalance: traderCashBalance,  // Uses trader's cash as "investment balance"
       pricePerSecurity: pricePerSecurity,
       denomination: denomination,
       subscriptionRatio: subscriptionRatio,
       minimumOrderAmount: nil  // Don't apply minimum to trader portion individually
   )
   ```
   - **IMPORTANT**: The trader's desired quantity is **IGNORED**
   - System **maximizes** trader quantity from available cash balance
   - This ensures all available trader capital is utilized

2. **Calculate Investment Maximum Quantity**
   ```swift
   let investmentQuantity = calculateMaxPurchasableQuantity(
       investmentBalance: investmentBalance,  // Uses pool capital
       pricePerSecurity: pricePerSecurity,
       denomination: denomination,
       subscriptionRatio: subscriptionRatio,
       minimumOrderAmount: nil  // Don't apply minimum to investment portion individually
   )
   ```
   - Calculates maximum quantity from investment pool balance
   - Uses same algorithm as trader calculation

3. **Calculate Total Quantity**
   ```swift
   let totalQuantity = actualTraderQuantity + investmentQuantity
   ```

4. **Validate Minimum Order Amount**
   ```swift
   let totalOrderAmount = Double(totalQuantity) * pricePerSecurity
   if let minimum = minimumOrderAmount, minimum > 0 {
       guard totalOrderAmount >= minimum else {
           // Reject order - return zero quantities
       }
   }
   ```

5. **Calculate Total Fees**
   ```swift
   let totalFees = FeeCalculationService.calculateTotalFees(for: totalOrderAmount)
   ```
   - Fees calculated on **total securities value** (`totalOrderAmount`)
   - This is the combined securities value (trader + investment)

6. **Split Fees Proportionally**
   ```swift
   // Calculate securities value for each portion
   let traderOrderAmount = Double(actualTraderQuantity) * pricePerSecurity
   let investmentOrderAmount = Double(investmentQuantity) * pricePerSecurity

   // Calculate proportion of total securities value
   let traderProportion = traderOrderAmount / totalOrderAmount
   let investmentProportion = investmentOrderAmount / totalOrderAmount

   // Split fees proportionally based on securities value
   let traderFees = totalFees * traderProportion
   let investmentFees = totalFees * investmentProportion
   ```
   - Fees split based on **securities value** proportion (not capital contribution)
   - `traderOrderAmount`: Trader's securities value portion
   - `investmentOrderAmount`: Investment pool's securities value portion
   - `totalOrderAmount`: Combined securities value

7. **Calculate Total Costs**
   ```swift
   let traderTotalCost = traderOrderAmount + traderFees
   let investmentTotalCost = investmentOrderAmount + investmentFees
   let totalCost = traderTotalCost + investmentTotalCost
   ```

8. **Calculate Remaining Balances**
   ```swift
   let traderRemainingBalance = traderCashBalance - traderTotalCost
   let investmentRemainingBalance = investmentBalance - investmentTotalCost
   ```

### 3.2 Key Design Decisions

**Why Maximize Both Quantities?**
- The system is designed to **maximize capital utilization**
- Similar to a "mirror trade" - uses all available capital
- Ensures no capital is left idle

**Why Ignore Trader's Desired Quantity?**
- Trader's input quantity is treated as a "suggestion"
- System calculates optimal quantity from available capital
- Prevents underutilization of capital

**Why Split Fees Proportionally?**
- Fees are calculated on total order (single transaction)
- Split proportionally ensures fair cost allocation
- Based on securities value, not capital contribution

---

## Part 4: Detailed Examples

### Example 1: Simple Case (No Constraints)

**Setup:**
- Security price: €10.00 per share
- Subscription ratio: 1.0 (1 unit = 1 share)
- No denomination constraint
- No minimum order amount
- Trader cash balance: €1,000
- Investment pool balance: €500

**Step 1: Calculate Trader Maximum Quantity**

```
pricePerUnit = €10.00 / 1.0 = €10.00
maxPossibleQuantity = floor(€1,000 / €10.00) = 100 units

Binary search (testing different quantities):
- Test 100 units:
  testOrderAmount = 100 × €10.00 = €1,000 (securities value)
  fees = €7.50
  totalCost = €1,000 + €7.50 = €1,007.50
  → €1,007.50 > €1,000 ❌ Cannot afford

- Test 99 units:
  testOrderAmount = 99 × €10.00 = €990 (securities value)
  fees = €7.50
  totalCost = €990 + €7.50 = €997.50
  → €997.50 <= €1,000 ✅ Can afford

- Result: actualTraderQuantity = 99 units
```

**Step 2: Calculate Investment Maximum Quantity**

```
maxPossibleQuantity = floor(€500 / €10.00) = 50 units

Binary search (testing different quantities):
- Test 50 units:
  testOrderAmount = 50 × €10.00 = €500 (securities value)
  fees = €7.50
  totalCost = €500 + €7.50 = €507.50
  → €507.50 > €500 ❌ Cannot afford

- Test 49 units:
  testOrderAmount = 49 × €10.00 = €490 (securities value)
  fees = €7.50
  totalCost = €490 + €7.50 = €497.50
  → €497.50 <= €500 ✅ Can afford

- Result: investmentQuantity = 49 units
```

**Step 3: Calculate Total Securities Value**

```
totalQuantity = 99 + 49 = 148 units
totalOrderAmount = 148 × €10.00 = €1,480.00  // Total securities value
```

**Step 4: Calculate Total Fees (on Total Securities Value)**

```
totalFees = FeeCalculationService.calculateTotalFees(for: €1,480.00)
- Order fee: €7.40 (0.5% of €1,480, but max is €50)
- Exchange fee: €1.48 (0.1% of €1,480, but max is €20)
- Foreign costs: €1.50
- Total fees: €10.38
```

**Step 5: Split Fees Proportionally (Based on Securities Value)**

```
// Calculate securities value for each portion
traderOrderAmount = 99 × €10.00 = €990.00        // Trader's securities value
investmentOrderAmount = 49 × €10.00 = €490.00     // Investment pool's securities value
totalOrderAmount = €1,480.00                      // Total securities value

// Calculate proportion of total securities value
traderProportion = €990.00 / €1,480.00 = 0.6689 (66.89%)
investmentProportion = €490.00 / €1,480.00 = 0.3311 (33.11%)

// Split fees proportionally
traderFees = €10.38 × 0.6689 = €6.94
investmentFees = €10.38 × 0.3311 = €3.44
```

**Step 6: Calculate Costs**

```
traderTotalCost = €990.00 + €6.94 = €996.94
investmentTotalCost = €490.00 + €3.44 = €493.44
totalCost = €996.94 + €493.44 = €1,490.38
```

**Step 7: Remaining Balances**

```
traderRemainingBalance = €1,000.00 - €996.94 = €3.06
investmentRemainingBalance = €500.00 - €493.44 = €6.56
```

**Result:**
- Trader buys: 99 units (€990.00 securities value)
- Investment buys: 49 units (€490.00 securities value)
- Total order: 148 units (€1,480.00 securities value)
- Total fees: €10.38 (split proportionally)

---

### Example 2: With Denomination Constraint

**Setup:**
- Security price: €10.00 per share
- Subscription ratio: 1.0
- Denomination: 10 (must buy in multiples of 10)
- Trader cash balance: €1,000
- Investment pool balance: €500

**Step 1: Calculate Trader Maximum Quantity**

```
pricePerUnit = €10.00
maxPossibleQuantity = floor(€1,000 / €10.00) = 100 units
upperBound = roundDownToDenomination(100, denomination=10) = 100 units

Search in denomination increments (testing multiples of 10):
- Test 10 units: testOrderAmount = €100, fees = €7.50, totalCost = €107.50 <= €1,000 ✅
- Test 20 units: testOrderAmount = €200, fees = €7.50, totalCost = €207.50 <= €1,000 ✅
- ...
- Test 100 units: testOrderAmount = €1,000, fees = €7.50, totalCost = €1,007.50 > €1,000 ❌
- Test 90 units: testOrderAmount = €900, fees = €7.50, totalCost = €907.50 <= €1,000 ✅
- Result: actualTraderQuantity = 90 units
```

**Step 2: Calculate Investment Maximum Quantity**

```
maxPossibleQuantity = floor(€500 / €10.00) = 50 units
upperBound = roundDownToDenomination(50, denomination=10) = 50 units

Search in denomination increments:
- Test 10 units: testOrderAmount = €100, totalCost = €107.50 <= €500 ✅
- Test 20 units: testOrderAmount = €200, totalCost = €207.50 <= €500 ✅
- ...
- Test 50 units: testOrderAmount = €500, totalCost = €507.50 > €500 ❌
- Test 40 units: testOrderAmount = €400, totalCost = €407.50 <= €500 ✅
- Result: investmentQuantity = 40 units
```

**Result:**
- Trader buys: 90 units
- Investment buys: 40 units
- Total: 130 units (both quantities are multiples of 10)

---

### Example 3: With Subscription Ratio

**Setup:**
- Security price: €10.00 per share
- Subscription ratio: 0.1 (10 units = 1 share)
- Trader cash balance: €1,000
- Investment pool balance: €500

**Step 1: Calculate Price Per Unit**

```
pricePerUnit = €10.00 / 0.1 = €1.00 per unit
```

**Step 2: Calculate Trader Maximum Quantity**

```
maxPossibleQuantity = floor(€1,000 / €1.00) = 1,000 units

Binary search:
- Test 1,000 units:
  testOrderAmount = €1,000 (securities value)
  fees = €7.50
  totalCost = €1,007.50
  → Cannot afford

- Test 992 units:
  testOrderAmount = €992 (securities value)
  fees = €7.50
  totalCost = €999.50
  → Can afford

- Result: actualTraderQuantity = 992 units
```

**Step 3: Calculate Investment Maximum Quantity**

```
maxPossibleQuantity = floor(€500 / €1.00) = 500 units

Binary search:
- Test 492 units:
  testOrderAmount = €492 (securities value)
  fees = €7.50
  totalCost = €499.50
  → Can afford

- Result: investmentQuantity = 492 units
```

**Step 4: Convert to Shares**

```
If subscriptionRatio = 0.1, then:
- 10 units = 1 share
- Formula: shares = units / (1 / subscriptionRatio) = units × subscriptionRatio

traderShares = Int(992 × 0.1) = Int(99.2) = 99 shares
investmentShares = Int(492 × 0.1) = Int(49.2) = 49 shares
totalShares = 99 + 49 = 148 shares
```

**Result:**
- Trader buys: 992 units = 99 shares (€990.00 securities value)
- Investment buys: 492 units = 49 shares (€490.00 securities value)
- Total: 1,484 units = 148 shares (€1,480.00 securities value)

---

### Example 4: Insufficient Capital

**Setup:**
- Security price: €10.00 per share
- Trader cash balance: €5.00
- Investment pool balance: €3.00
- Minimum order amount: €100.00

**Calculation:**

```
Trader max: floor(€5.00 / €10.00) = 0 units (cannot afford even 1 unit)
Investment max: floor(€3.00 / €10.00) = 0 units

totalQuantity = 0 + 0 = 0 units
totalOrderAmount = 0 × €10.00 = €0.00  // Total securities value = €0

Check minimum: €0.00 < €100.00 ❌
Result: Order rejected (returns zero quantities)
```

---

## Part 5: Order Placement Flow

### 5.1 UI Calculation (Before Order Placement)

**When trader enters quantity in buy order form:**

1. **Real-time Calculation**
   - `BuyOrderViewModel.calculateInvestmentOrder()` is called
   - Calculates combined order details
   - Updates UI to show:
     - Trader quantity
     - Investment quantity
     - Total quantity
     - Fee breakdown
     - Remaining balances

2. **Quantity Adjustment**
   ```swift
   if result.isTraderLimited {
       quantity = Double(result.traderQuantity)
   }
   ```
   - If trader is limited, UI quantity is adjusted to purchasable amount

3. **Display Investment Calculation**
   - Shows investment portion if `showInvestmentCalculation == true`
   - Hides if no investment pools available

### 5.2 Actual Order Placement

**When trader clicks "Place Order":**

1. **Order Creation**
   - Creates `OrderBuy` with:
     - `quantity`: Total quantity (trader + investment)
     - `price`: Security price
     - `totalAmount`: `quantity × price` (securities value)
     - Status: `.submitted`

2. **Cash Deduction** (when order completes)
   - Deducts `traderTotalCost` from trader cash balance
   - Deducts `investmentTotalCost` from individual investment amounts (not pool balance)
   - **Note**: Deductions happen when order status = `.completed`

3. **Investment Activation** (when order completes)
   - Activates investments using round-robin
   - Records `PotTradeParticipation` with:
     - `allocatedAmount`: Investment's securities value portion
     - `totalTradeValue`: Total securities value
     - `ownershipPercentage`: Calculated proportion

---

## Part 6: Edge Cases and Limitations

### 6.1 Multiple Investments

**Current Behavior:**
- System **sums all available investments** for the trader
- Includes investments with status `.active` and reservation status:
  - `.reserved`
  - `.active`
  - `.executing`
  - `.closed`
- All available investments are automatically combined

**Implementation:**
- Uses `investmentService.getInvestments(forTrader:)` to get all investments
- Filters by status and reservation status
- Sums individual `investment.amount` values
- This ensures all available capital is utilized

### 6.2 Residual Amounts

**What is Residual Amount?**
- Leftover funds that cannot purchase a full denomination unit
- Example: €5.00 remaining, but need €10.00 + fees for next unit

**Calculation:**
```swift
if investmentRemainingBalance >= costForNextUnit {
    investmentResidualAmount = 0  // Can still buy more
} else {
    investmentResidualAmount = investmentRemainingBalance  // Leftover
}
```

**Impact:**
- Residual amounts remain in pool balance
- Cannot be used until more capital is added
- Tracked for accounting purposes

### 6.3 Fee Splitting Edge Cases

**Case 1: One Portion is Zero**
- If trader quantity = 0, traderFees = 0
- All fees go to investment portion
- Vice versa if investment quantity = 0

**Case 2: Very Small Quantities**
- If quantities are very small, fees may exceed order amount
- System prevents this by binary search (only affordable quantities)

### 6.4 Minimum Order Amount Validation

**Behavior:**
- Applied to **total order** only
- Individual portions may be below minimum
- If total < minimum, entire order is rejected

**Example:**
- Minimum: €100
- Trader portion: €30
- Investment portion: €50
- Total: €80 < €100 ❌ Order rejected

---

## Part 7: Accounting Principles

### 7.1 Capital Separation

- **Trader Capital**: Separate account, tracked independently
- **Investment Capital**: Pooled in InvestmentPools, tracked separately
- **Combined Usage**: System combines for calculation, but maintains separate accounting

### 7.2 Fee Allocation

- Fees calculated on **total securities value** (`totalOrderAmount`) - single transaction
- Split proportionally based on **securities value proportion**
  - `traderFees = totalFees × (traderOrderAmount / totalOrderAmount)`
  - `investmentFees = totalFees × (investmentOrderAmount / totalOrderAmount)`
- Not based on capital contribution (ensures fair allocation)

### 7.3 Securities Value vs Capital vs Total Cost

**Important Distinctions:**

1. **Securities Value** (`orderAmount` types):
   - `traderOrderAmount`: Trader's securities value = `traderQuantity × pricePerSecurity`
   - `investmentOrderAmount`: Investment's securities value = `investmentQuantity × pricePerSecurity`
   - `totalOrderAmount`: Total securities value = `totalQuantity × pricePerSecurity`
   - **What you're buying** (the securities themselves)

2. **Capital** (Available Funds):
   - `traderCashBalance`: Trader's available cash
   - `investmentBalance`: Investment pool's available capital
   - **What you can spend** (your available funds)

3. **Total Cost** (What You Actually Pay):
   - `traderTotalCost = traderOrderAmount + traderFees`
   - `investmentTotalCost = investmentOrderAmount + investmentFees`
   - `totalCost = totalOrderAmount + totalFees`
   - **What you're paying** (securities value + fees)

**Example:**
- Securities value (`totalOrderAmount`): €1,000
- Fees: €10
- Capital needed (`totalCost`): €1,010

### 7.4 Ownership Calculation

**When trade completes:**
- `allocatedAmount` = Securities value portion (not capital)
- `ownershipPercentage` = `allocatedAmount / totalTradeValue`
- Ensures profit distribution uses consistent denominators

---

## Conclusion

The system implements a sophisticated capital combination mechanism that:

1. **Maximizes capital utilization** by using all available trader and investment capital
2. **Uses binary search** for efficient quantity calculation
3. **Accounts for fees, denominations, and subscription ratios** accurately
4. **Splits costs fairly** based on securities value proportion
5. **Maintains separate accounting** for trader and investment capital

The algorithm ensures optimal capital utilization while maintaining proper accounting separation and fair cost allocation.

