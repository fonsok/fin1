# Investment Quantity Calculation: Data Flow and Timing

## Overview

This document explains **exactly when and how** `investmentQuantity` is calculated in the buy order flow, tracing the complete data flow from user interaction to final calculation.

---

## Part 1: Calculation Triggers

### 1.1 Initial Calculation (View Initialization)

**When**: `BuyOrderViewModel` is initialized

**Code Location**: `BuyOrderViewModel.init()`

```swift
init(...) {
    // ... setup code ...

    setupBindings()
    reloadPrice()

    // Calculate investment order when quantity or price changes
    Task {
        await calculateInvestmentOrder()  // ← INITIAL CALCULATION
    }
}
```

**What Happens**:
- ViewModel is created when user opens buy order form
- Immediately triggers first calculation
- Uses current `quantity` and `searchResult` values

---

### 1.2 Reactive Calculation (User Input Changes)

**When**: User changes quantity OR price changes

**Code Location**: `BuyOrderViewModel.setupBindings()`

```swift
// Recalculate investment order when quantity or price changes
Publishers.CombineLatest($quantity, $searchResult)
    .debounce(for: .milliseconds(300), scheduler: RunLoop.main)  // ← 300ms debounce
    .sink { [weak self] _, _ in
        Task { @MainActor [weak self] in
            await self?.calculateInvestmentOrder()  // ← REACTIVE CALCULATION
        }
    }
    .store(in: &cancellables)
```

**What Happens**:
- Combine publisher watches `$quantity` and `$searchResult`
- When either changes, waits 300ms (debounce)
- Then triggers `calculateInvestmentOrder()`

**Why Debounce?**
- Prevents excessive calculations during rapid typing
- Waits for user to finish input before calculating

---

### 1.3 Pre-Order Calculation (Before Order Placement)

**When**: User clicks "Place Order" button

**Code Location**: `BuyOrderViewModel.placeOrder()`

```swift
@MainActor
func placeOrder() async {
    orderStatus = .transmitting

    // Calculate investment order if not already calculated
    if investmentOrderCalculation == nil {  // ← Safety check
        await calculateInvestmentOrder()
    }

    // ... proceed with order placement ...
}
```

**What Happens**:
- Safety check: ensures calculation exists before placing order
- If calculation is missing, calculates it now
- Then proceeds with order placement

---

## Part 2: Calculation Flow

### 2.1 Entry Point: `BuyOrderViewModel.calculateInvestmentOrder()`

**Location**: `BuyOrderViewModel.swift:173`

**Flow**:
```swift
@MainActor
func calculateInvestmentOrder() async {
    // Step 1: Extract price from SearchResult
    let price = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
    let desiredQuantity = Int(quantity)

    // Step 2: Validate user is trader
    guard let currentUser = userService.currentUser,
          currentUser.role == .trader else {
        // Skip if not trader
        return
    }

    // Step 3: Call investment calculator
    guard let result = await investmentCalculator.calculateInvestmentOrder(
        quantity: desiredQuantity,
        price: price,
        searchResult: searchResult,
        userService: userService,
        investmentService: investmentService,
        cashBalanceService: cashBalanceService,
        investmentQuantityCalculationService: investmentQuantityCalculationService,
        traderDataService: traderDataService
    ) else {
        // No active investment pool - return nil
        return
    }

    // Step 4: Update ViewModel state
    investmentOrderCalculation = result.calculation
    isInvestmentLimited = result.isInvestmentLimited
    showInvestmentCalculation = result.showInvestmentCalculation
}
```

**Key Points**:
- Runs on `@MainActor` (main thread)
- Extracts price from German format ("2,98" → 2.98)
- Validates user is trader
- Delegates to `BuyOrderInvestmentCalculator`

---

### 2.2 Investment Capital Calculation: `BuyOrderInvestmentCalculator.calculateInvestmentOrder()`

**Location**: `BuyOrderInvestmentCalculator.swift:29`

**Flow**:
```swift
func calculateInvestmentOrder(...) async -> InvestmentCalculationResult? {
    // Step 1: Get trader ID
    guard let currentUser = userService.currentUser else {
        return nil  // No user logged in
    }
    let traderId = currentUser.id

    // Step 2: Get all available investments for trader
    // CRITICAL: Calculate investment balance from sum of all available investments
    // This ensures the order quantity calculation uses the same capital that will actually be used
    // in recordPotParticipations, which sums activated investments' capital amounts.
    // Using activeInvestmentPool.currentBalance was incorrect because:
    // 1. It's a static value that doesn't reflect actual available capital
    // 2. It may not match the sum of individual investment amounts
    // 3. It can lead to underutilization of pool capital
    // Include investments that are reserved OR active (executing/closed are also participating)
    let allReservedInvestments = investmentService.getInvestments(forTrader: traderId)
        .filter { investment in
            investment.status == .active &&
            (investment.reservationStatus == .reserved ||
             investment.reservationStatus == .active ||
             investment.reservationStatus == .executing ||
             investment.reservationStatus == .closed)
        }

    // Step 3: Calculate total available capital from all reserved investments
    let investmentBalance = allReservedInvestments.reduce(0.0) { $0 + $1.amount }

    guard investmentBalance > 0 else {
        return nil  // No available investments with capital
    }

    // Step 4: Extract trader cash balance
    let traderCashBalance = cashBalanceService.currentBalance

    // Step 5: Get security metadata
    let denomination = searchResult.denomination
    let subscriptionRatio = searchResult.subscriptionRatio
    let minimumOrderAmount = searchResult.minimumOrderAmount

    // Step 6: Calculate combined order details
    let calculation = investmentQuantityCalculationService.calculateCombinedOrderDetails(
        traderQuantity: quantity,
        traderCashBalance: traderCashBalance,
        investmentBalance: investmentBalance,  // ← Sum of individual investment amounts
        pricePerSecurity: price,
        denomination: denomination,
        subscriptionRatio: subscriptionRatio,
        minimumOrderAmount: minimumOrderAmount
    )

    return InvestmentCalculationResult(calculation: calculation, ...)
}
```

**Key Points**:
- **Gets all available investments** for trader (not just first pool)
- **Sums individual investment amounts** to calculate total available capital
- Filters investments by status (`.active`) and reservation status (`.reserved`, `.active`, `.executing`, `.closed`)
- Uses `investment.amount` from each investment, not pool-level balance
- This approach ensures accurate capital calculation that matches actual usage

---

### 2.3 Combined Order Calculation: `InvestmentQuantityCalculationService.calculateCombinedOrderDetails()`

**Location**: `InvestmentQuantityCalculationService.swift:174`

**Flow**:
```swift
func calculateCombinedOrderDetails(
    traderQuantity: Int,
    traderCashBalance: Double,
    investmentBalance: Double,  // ← Investment pool capital
    pricePerSecurity: Double,
    denomination: Int?,
    subscriptionRatio: Double,
    minimumOrderAmount: Double?
) -> CombinedOrderCalculationResult {

    // Step 1: Calculate trader maximum quantity
    let actualTraderQuantity = calculateMaxPurchasableQuantity(
        investmentBalance: traderCashBalance,  // Uses trader cash
        pricePerSecurity: pricePerSecurity,
        denomination: denomination,
        subscriptionRatio: subscriptionRatio,
        minimumOrderAmount: nil
    )

    // Step 2: Calculate investment maximum quantity ← THIS IS WHERE investmentQuantity IS CALCULATED
    let investmentQuantity = calculateMaxPurchasableQuantity(
        investmentBalance: investmentBalance,  // ← Uses investment pool capital
        pricePerSecurity: pricePerSecurity,
        denomination: denomination,
        subscriptionRatio: subscriptionRatio,
        minimumOrderAmount: nil
    )

    // Step 3: Calculate total
    let totalQuantity = actualTraderQuantity + investmentQuantity

    // Step 4: Calculate securities values
    let traderOrderAmount = Double(actualTraderQuantity) * pricePerSecurity
    let investmentOrderAmount = Double(investmentQuantity) * pricePerSecurity
    let totalOrderAmount = Double(totalQuantity) * pricePerSecurity

    // Step 5: Calculate fees and split them
    // ... (fee calculation and splitting)

    return CombinedOrderCalculationResult(
        traderQuantity: actualTraderQuantity,
        investmentQuantity: investmentQuantity,  // ← Returned here
        totalQuantity: totalQuantity,
        // ... other fields
    )
}
```

**Key Points**:
- **Line 230**: `investmentQuantity` is calculated here
- Uses `calculateMaxPurchasableQuantity()` with `investmentBalance`
- This is the **actual calculation** of investment quantity

---

### 2.4 Maximum Quantity Algorithm: `calculateMaxPurchasableQuantity()`

**Location**: `InvestmentQuantityCalculationService.swift:20`

**This is where the actual binary search happens:**

```swift
func calculateMaxPurchasableQuantity(
    investmentBalance: Double,  // ← For investment: pool capital
    pricePerSecurity: Double,
    denomination: Int?,
    subscriptionRatio: Double,
    minimumOrderAmount: Double?
) -> Int {

    // Step 1: Calculate price per unit
    let pricePerUnit = pricePerSecurity / Double(subscriptionRatio)

    // Step 2: Calculate theoretical maximum (without fees)
    let maxPossibleQuantity = Int(investmentBalance / pricePerUnit)

    // Step 3: Apply denomination constraint
    let upperBound = /* round down to denomination if specified */

    // Step 4: Binary search to find maximum affordable quantity
    // Tests different quantities, accounting for fees
    // Returns maximum quantity where: (quantity × pricePerUnit + fees) <= investmentBalance

    return bestQuantity
}
```

**Key Points**:
- Uses **binary search algorithm** for efficiency
- Accounts for fees, denomination, subscription ratio
- Returns maximum quantity that can be afforded with given balance

---

## Part 3: Complete Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│ USER INTERACTION                                                │
│ - User types quantity                                           │
│ - User changes price                                            │
│ - View initializes                                              │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ BuyOrderViewModel.setupBindings()                                │
│ CombineLatest($quantity, $searchResult)                         │
│   .debounce(300ms)                                              │
│   .sink { calculateInvestmentOrder() }                          │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ BuyOrderViewModel.calculateInvestmentOrder()                    │
│ - Extract price from SearchResult                                │
│ - Validate user is trader                                       │
│ - Call investmentCalculator.calculateInvestmentOrder()          │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ BuyOrderInvestmentCalculator.calculateInvestmentOrder()          │
│ - Get trader ID                                                 │
│ - Find active investment pool                                   │
│ - Extract investmentBalance = pool.currentBalance              │
│ - Extract traderCashBalance                                     │
│ - Call calculateCombinedOrderDetails()                          │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ InvestmentQuantityCalculationService.calculateCombinedOrderDetails()│
│                                                                  │
│ Step 1: Calculate trader quantity                              │
│   actualTraderQuantity = calculateMaxPurchasableQuantity(       │
│     investmentBalance: traderCashBalance                        │
│   )                                                             │
│                                                                  │
│ Step 2: Calculate investment quantity ← HERE                    │
│   investmentQuantity = calculateMaxPurchasableQuantity(         │
│     investmentBalance: investmentBalance  ← Pool capital        │
│   )                                                             │
│                                                                  │
│ Step 3: Calculate totals and fees                               │
│   totalQuantity = actualTraderQuantity + investmentQuantity    │
│   ... fee splitting ...                                         │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ InvestmentQuantityCalculationService.calculateMaxPurchasableQuantity()│
│                                                                  │
│ - Calculate pricePerUnit = pricePerSecurity / subscriptionRatio│
│ - Calculate maxPossibleQuantity = floor(balance / pricePerUnit) │
│ - Apply denomination constraint                                 │
│ - Binary search to find maximum affordable quantity             │
│   (accounting for fees)                                         │
│                                                                  │
│ Returns: Maximum quantity that can be afforded                  │
└────────────────────┬────────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│ Result flows back up the chain:                                 │
│                                                                  │
│ CombinedOrderCalculationResult                                   │
│   ├─ investmentQuantity: Int  ← Calculated value                │
│   ├─ traderQuantity: Int                                        │
│   ├─ totalQuantity: Int                                         │
│   └─ ... other fields ...                                        │
│                                                                  │
│ → BuyOrderViewModel.investmentOrderCalculation                  │
│ → UI updates to show investment portion                         │
└─────────────────────────────────────────────────────────────────┘
```

---

## Part 4: Timing and Execution Context

### 4.1 When Calculation Happens

| Trigger | When | Frequency |
|---------|------|-----------|
| **View Initialization** | When buy order form opens | Once per view creation |
| **Quantity Change** | User types in quantity field | After 300ms debounce |
| **Price Change** | Price updates (manual refresh or timer) | After 300ms debounce |
| **Pre-Order** | Before placing order (safety check) | Once per order placement |

### 4.2 Execution Context

- **Thread**: Main thread (`@MainActor`)
- **Async**: Yes (uses `async/await`)
- **Debounce**: 300ms for reactive updates
- **Caching**: Result stored in `investmentOrderCalculation` property

### 4.3 Performance Considerations

**Binary Search Efficiency**:
- Time complexity: O(log n) where n = max possible quantity
- Handles large quantities efficiently
- Accounts for non-linear fee structure

**Debounce Benefits**:
- Prevents excessive calculations during rapid typing
- Reduces CPU usage
- Improves UI responsiveness

---

## Part 5: Key Data Points

### 5.1 Inputs to `investmentQuantity` Calculation

1. **`investmentBalance`**: From sum of individual investment amounts
   - Source: Sum of `investment.amount` for all available investments
   - Calculation: `allReservedInvestments.reduce(0.0) { $0 + $1.amount }`
   - Type: `Double` (EUR)
   - **Note**: This is calculated from individual investments, not from pool-level balance

2. **`pricePerSecurity`**: From `searchResult.askPrice`
   - Source: Current market price
   - Type: `Double` (EUR per share)

3. **`denomination`**: From `searchResult.denomination`
   - Source: Security's denomination constraint
   - Type: `Int?` (optional, e.g., 10, 100)

4. **`subscriptionRatio`**: From `searchResult.subscriptionRatio`
   - Source: Security's subscription ratio
   - Type: `Double` (e.g., 1.0, 0.1, 10.0)

5. **`minimumOrderAmount`**: From `searchResult.minimumOrderAmount`
   - Source: Security's minimum order requirement
   - Type: `Double?` (optional, EUR)

### 5.2 Output: `investmentQuantity`

- **Type**: `Int` (units)
- **Meaning**: Maximum quantity of securities that can be purchased with investment pool capital
- **Calculation**: Binary search finding maximum quantity where `(quantity × pricePerUnit + fees) <= investmentBalance`

### 5.3 Where Result is Used

1. **UI Display**: Shows investment portion in buy order form
2. **Order Placement**: Used to calculate total order quantity
3. **Fee Calculation**: Used to split fees proportionally
4. **Cost Calculation**: Used to calculate investment's total cost

---

## Part 6: Example Flow

### Scenario: User Types Quantity "100"

**Timeline**:

1. **t=0ms**: User types "1" in quantity field
   - `$quantity` publisher fires
   - Debounce timer starts (300ms)

2. **t=100ms**: User types "0"
   - `$quantity` publisher fires again
   - Debounce timer resets (300ms)

3. **t=200ms**: User types "0"
   - `$quantity` publisher fires again
   - Debounce timer resets (300ms)

4. **t=500ms**: Debounce completes
   - `calculateInvestmentOrder()` is called
   - Flow proceeds through all steps above
   - `investmentQuantity` is calculated

5. **t=520ms**: Calculation completes
   - `investmentOrderCalculation` is updated
   - UI updates to show investment portion

**Total Time**: ~520ms from first keystroke to UI update

---

## Part 7: Important Notes

### 7.1 Calculation is NOT Used for Order Placement

**Important**: The `investmentQuantity` calculation is for **display purposes only** during order setup.

**Actual Order Placement**:
- Uses `investmentOrderCalculation.totalQuantity` (trader + investment combined)
- Creates a **single order** with combined quantity
- Investment activation happens **after** order completes

### 7.2 Investment Capital Calculation

**Current Behavior**:
- Gets **all available investments** for trader (not pool-based)
- **Sums individual investment amounts** to calculate total available capital
- Includes investments with status `.active` and reservation status:
  - `.reserved`
  - `.active`
  - `.executing`
  - `.closed`
- If no available investments exist, calculation returns `nil`

**Why This Approach**:
- Pool-level balance (`activeInvestmentPool.currentBalance`) is static and may not reflect actual available capital
- Summing individual investments ensures calculation matches actual capital usage
- Prevents underutilization of pool capital

### 7.3 Real-time Updates

**Calculation Updates When**:
- ✅ Quantity changes (user input)
- ✅ Price changes (manual refresh or timer)
- ✅ View initializes

**Calculation Does NOT Update When**:
- ❌ Investment pool balance changes (would require polling)
- ❌ Trader cash balance changes (would require polling)
- ❌ New investment pools are created (would require notification)

---

## Conclusion

The `investmentQuantity` is calculated:

1. **When**:
   - View initializes
   - User changes quantity (after 300ms debounce)
   - Price changes (after 300ms debounce)
   - Before order placement (safety check)

2. **Where**:
   - Entry: `BuyOrderViewModel.calculateInvestmentOrder()`
   - Detection: `BuyOrderInvestmentCalculator.calculateInvestmentOrder()`
   - Calculation: `InvestmentQuantityCalculationService.calculateCombinedOrderDetails()`
   - Algorithm: `InvestmentQuantityCalculationService.calculateMaxPurchasableQuantity()`

3. **How**:
   - Binary search algorithm
   - Accounts for fees, denomination, subscription ratio
   - Uses sum of individual investment amounts as available capital (not pool-level balance)

4. **Result**:
   - Maximum quantity affordable with investment pool capital
   - Stored in `investmentOrderCalculation.investmentQuantity`
   - Used for UI display and order calculation

