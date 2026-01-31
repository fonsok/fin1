# Pot-Based Trading: Comprehensive Implementation Guide

## Table of Contents

1. [Overview](#overview)
2. [Core Concept: Trader + Pot Synchronized Trading](#core-concept)
3. [Quantity Calculation Implementation](#quantity-calculation)
4. [Remaining Balance Handling](#remaining-balance)
5. [Architecture & File Structure](#architecture)
6. [Implementation Details](#implementation-details)
7. [Testing & Validation](#testing)

---

## Overview

This document provides a comprehensive guide to the pot-based trading system where traders and their investors' pots simultaneously purchase securities through a single order. The system handles:

- **Synchronized Trading**: Trader's desired quantity + pot's maximum purchasable quantity = single executed order
- **Fee-Aware Calculations**: Binary search algorithm to find maximum purchasable quantity accounting for all trading fees
- **Proportional Distribution**: Profits and remaining balances distributed proportionally to investors
- **Admin Configuration**: Configurable strategies for handling small remaining balances

---

## Core Concept: Trader + Pot Synchronized Trading

### The Critical Requirement

#### What the Trader Sees
- Trader places buy order: **1000 pieces @ €2**
- Trader sees: **"Pot is active"** (no balance information shown)
- Trader does NOT see: Pot balance (€15,321)

#### What Happens Behind the Scenes

1. **System checks trader's cash balance**: Trader pays for their 1000 pieces
2. **System checks pot balance**: €15,321 available
3. **System calculates pot's maximum purchasable quantity**:
   - Must account for fees (order fee, exchange fee, foreign costs)
   - Fees depend on order amount
   - Order amount = quantity × price
   - **Circular dependency**: Need quantity to calculate fees, but need fees to calculate quantity

4. **System calculates exact quantities**:
   ```
   Trader's portion: 1000 pieces (from trader's cash balance)
   Pot Balance = (Pot Quantity × Price) + Fees(Pot Quantity × Price)

   Using binary search for pot:
   - Try different quantities
   - Calculate total cost (securities + fees)
   - Find maximum quantity where total cost ≤ pot balance
   ```

5. **Result**:
   - Trader's quantity: **1000 pieces** (from trader's cash)
   - Pot's quantity: **7,624 pieces** (from pot balance, after fees)
   - **Total executed**: **8,624 pieces** (1000 + 7,624)
   - Single order on stock exchange: **8,624 pieces @ €2**

### Example Calculation

**Input:**
- Trader Desired: 1000 pieces @ €2
- Trader Cash Balance: €50,000 (sufficient for 1000 pieces)
- Pot Balance: €15,321
- Price per Security: €2

**Calculation Process:**

#### Trader's Portion:
- Quantity: **1000 pieces**
- Order Amount: 1000 × €2 = €2,000
- Fees (for trader portion): ~€11.50
- Trader Total Cost: ~€2,011.50

#### Pot's Portion:
1. Max possible (no fees): €15,321 / €2 = 7,660 pieces
2. Try 7,660 pieces:
   - Order Amount: 7,660 × €2 = €15,320
   - Fees: €71.50 (€50 + €20 + €1.50)
   - Total Cost: €15,391.50
   - **Exceeds pot balance!**

3. Binary search finds optimal: **7,624 pieces**
   - Order Amount: 7,624 × €2 = €15,248
   - Fees: €71.50
   - Total Cost: €15,319.50
   - Remaining: €1.50 ✅

#### Combined Order:
- **Total Quantity**: 1000 (trader) + 7,624 (pot) = **8,624 pieces**
- Total Order Amount: 8,624 × €2 = €17,248
- Total Fees: ~€83 (calculated on total order)
- Fees split proportionally:
  - Trader Fees: ~€11.50 (proportional to trader's €2,000)
  - Pot Fees: ~€71.50 (proportional to pot's €15,248)

**Output:**
- Trader Quantity: **1,000 pieces** (€2,011.50 total cost)
- Pot Quantity: **7,624 pieces** (€15,319.50 total cost)
- **Total Executed**: **8,624 pieces** (€17,331 total cost)
- Single order on stock exchange: **8,624 pieces @ €2**

### Implementation Flow

```
[Trader] Enters: 1000 pieces @ €2
    ↓
[System] Checks: Pot active? Yes
    ↓
[System] Validates trader cash balance: Sufficient for 1000 pieces
    ↓
[System] Gets pot balance: €15,321 (hidden from trader)
    ↓
[System] Calculates pot's max purchasable: 7,624 pieces
    ↓
[System] Combines quantities: 1000 (trader) + 7,624 (pot) = 8,624 pieces
    ↓
[System] Calculates total fees for combined order: ~€83
    ↓
[System] Splits fees proportionally:
    - Trader: ~€11.50 (proportional to €2,000)
    - Pot: ~€71.50 (proportional to €15,248)
    ↓
[System] Executes single order: 8,624 pieces @ €2
    ↓
[System] Updates balances:
    - Trader cash: -€2,011.50
    - Pot balance: €15,321 - €15,319.50 = €1.50
```

### Key Points

1. **Trader doesn't see pot balance** - Only "pot is active" indicator
2. **Total quantity = trader + pot** - Trader's quantity PLUS pot's purchasable quantity
3. **Single order execution** - Both portions executed together on stock exchange
4. **Fees split proportionally** - Fees calculated on total order, split by proportion
5. **Fees are included** - Exact calculation accounts for all trading fees
6. **System optimizes pot** - Pot buys maximum possible quantity based on balance
7. **Backend calculation** - All logic happens server-side for security
8. **Denomination constraints** - Quantities automatically rounded to valid denominations (10, 20, 50, 100, 1000) when specified
9. **Minimum order amount** - Orders must meet minimum value requirements (e.g., minimum €100 order)
10. **Combined constraints** - Both denomination and minimum order amount can be applied simultaneously

---

## Quantity Calculation Implementation

### Problem Statement

When a trader places a buy order:
- **Trader Input**: Desired quantity (e.g., 1000 pieces @ €2)
- **Pot Balance**: €15,321 (trader only sees "pot is active", not the balance)
- **Challenge**: Calculate the **exact number of securities** that can be purchased with the pot balance after accounting for fees

### Key Insight

The fees depend on the order amount, which depends on the quantity. This creates a circular dependency:

```
Pot Balance = (Quantity × Price) + Fees(Quantity × Price)
```

Where `Fees(x)` includes:
- Order Fee: 0.5% of x (min €5, max €50)
- Exchange Fee: 0.1% of x (min €1, max €20)
- Foreign Costs: €1.50 (fixed)

### Trading Constraints

#### Denomination Constraints

**Important**: Some securities can only be traded in specific denominations:
- **Tens**: 10, 20, 30, 40, ...
- **Twenties**: 20, 40, 60, 80, ...
- **Fifties**: 50, 100, 150, 200, ...
- **Hundreds**: 100, 200, 300, 400, ...
- **Thousands**: 1000, 2000, 3000, ...

The quantity calculation automatically rounds down to the nearest valid denomination when a constraint is specified. This ensures all calculated quantities are valid for trading.

#### Minimum Order Amount Constraints

**Important**: Some securities require a minimum order value:
- Example: Minimum order amount of €100
- If price is €2 per security, minimum quantity = €100 / €2 = 50 pieces
- Orders below the minimum amount cannot be executed

The quantity calculation ensures:
1. **Individual portions** (trader or pot) may be below minimum if the **total order** meets the minimum
2. **Total order amount** (trader + pot) must meet or exceed the minimum order amount
3. If total order cannot meet minimum, calculation returns 0 quantities

### Solution: Binary Search Algorithm

Since fees have min/max caps, we need an iterative approach to find the maximum purchasable quantity.

#### Algorithm

```swift
func calculateMaxPurchasableQuantity(
    potBalance: Double,
    pricePerSecurity: Double,
    denomination: Int? = nil,
    minimumOrderAmount: Double? = nil
) -> Int {
    // Validate inputs
    guard potBalance > 0, pricePerSecurity > 0 else {
        return 0
    }

    // Check if pot balance can meet minimum order amount requirement
    if let minimum = minimumOrderAmount, minimum > 0 {
        guard potBalance >= minimum else {
            // Pot balance is insufficient to meet minimum order amount
            return 0
        }
    }

    // Calculate maximum possible quantity (if no fees)
    let maxPossibleQuantity = Int(potBalance / pricePerSecurity)
    guard maxPossibleQuantity > 0 else {
        return 0
    }

    // Calculate minimum quantity required to meet minimum order amount
    let minRequiredQuantity = CalculationConstants.SecurityDenominations.calculateMinimumQuantity(
        pricePerSecurity: pricePerSecurity,
        minimumOrderAmount: minimumOrderAmount
    )

    // If minimum quantity is required, ensure we start from at least that quantity
    guard maxPossibleQuantity >= minRequiredQuantity else {
        return 0 // Cannot meet minimum order amount
    }

    // Apply denomination constraint to upper bound if specified
    let upperBound: Int
    if let denomination = denomination {
        upperBound = CalculationConstants.SecurityDenominations.roundDownToDenomination(
            maxPossibleQuantity,
            denominations: [denomination]
        )
        guard upperBound > 0 else {
            return 0
        }
    } else {
        upperBound = maxPossibleQuantity
    }

    // Use binary search to find optimal quantity
    // If denomination is specified, search in denomination increments
    if let denomination = denomination {
        // Search in denomination increments
        var bestQuantity = 0
        var testQuantity = denomination

            while testQuantity <= upperBound {
                let orderAmount = Double(testQuantity) * pricePerSecurity

                // Check minimum order amount requirement
                guard CalculationConstants.SecurityDenominations.meetsMinimumOrderAmount(
                    orderAmount,
                    minimumOrderAmount: minimumOrderAmount
                ) else {
                    // Order amount too small, try next denomination multiple
                    testQuantity += denomination
                    continue
                }

                let fees = FeeCalculationService.calculateTotalFees(for: orderAmount)
                let totalCost = orderAmount + fees

            if totalCost <= potBalance {
                // Can afford this quantity
                bestQuantity = testQuantity
                testQuantity += denomination // Try next denomination multiple
            } else {
                // Too expensive, we've found the maximum
                break
            }
        }

        return bestQuantity
        } else {
            // No denomination constraint - use standard binary search
            // Start from minimum required quantity
            var low = minRequiredQuantity
            var high = upperBound
            var bestQuantity = 0

            while low <= high {
                let mid = (low + high) / 2
                let orderAmount = Double(mid) * pricePerSecurity

                // Check minimum order amount requirement
                guard CalculationConstants.SecurityDenominations.meetsMinimumOrderAmount(
                    orderAmount,
                    minimumOrderAmount: minimumOrderAmount
                ) else {
                    // Order amount too small, need more quantity
                    low = mid + 1
                    continue
                }

                let fees = FeeCalculationService.calculateTotalFees(for: orderAmount)
                let totalCost = orderAmount + fees

            if totalCost <= potBalance {
                // Can afford this quantity
                bestQuantity = mid
                low = mid + 1 // Try more
            } else {
                // Too expensive
                high = mid - 1 // Try less
            }
        }

        return bestQuantity
    }
}
```

#### Denomination and Minimum Order Amount Helpers

The `CalculationConstants.SecurityDenominations` provides helper functions:

```swift
// Round down to nearest valid denomination
let rounded = CalculationConstants.SecurityDenominations.roundDownToDenomination(
    1234,
    denominations: [100]  // Round to nearest 100
)
// Result: 1200

// Check if quantity is valid denomination
let isValid = CalculationConstants.SecurityDenominations.isValidDenomination(
    500,
    denominations: [10, 20, 50, 100, 1000]
)
// Result: true (500 is a multiple of 50, 100)

// Check if order amount meets minimum requirement
let meetsMinimum = CalculationConstants.SecurityDenominations.meetsMinimumOrderAmount(
    150.0,  // Order amount
    minimumOrderAmount: 100.0  // Minimum required
)
// Result: true (150 >= 100)

// Calculate minimum quantity required
let minQuantity = CalculationConstants.SecurityDenominations.calculateMinimumQuantity(
    pricePerSecurity: 2.0,
    minimumOrderAmount: 100.0
)
// Result: 50 (ceil(100 / 2) = 50 pieces)
```

### Combined Order Calculation

The service also calculates the combined order details for trader + pot, with denomination support:

```swift
func calculateCombinedOrderDetails(
    traderQuantity: Int,
    traderCashBalance: Double,
    potBalance: Double,
    pricePerSecurity: Double,
    denomination: Int? = nil,
    minimumOrderAmount: Double? = nil
) -> CombinedOrderCalculationResult {
    // Round trader quantity to valid denomination if constraint exists
    let adjustedTraderQuantity: Int
    if let denomination = denomination {
        adjustedTraderQuantity = CalculationConstants.SecurityDenominations.roundDownToDenomination(
            traderQuantity,
            denominations: [denomination]
        )
    } else {
        adjustedTraderQuantity = traderQuantity
    }
    // 1. Calculate trader's actual quantity (may be limited by cash balance)
    let traderOrderAmount = Double(traderQuantity) * pricePerSecurity
    let traderFeesForOrder = FeeCalculationService.calculateTotalFees(for: traderOrderAmount)
    let traderTotalCostForOrder = traderOrderAmount + traderFeesForOrder

    let actualTraderQuantity: Int
    let isTraderLimited: Bool

    if traderTotalCostForOrder <= traderCashBalance {
        actualTraderQuantity = traderQuantity
        isTraderLimited = false
    } else {
        actualTraderQuantity = calculateMaxPurchasableQuantity(
            potBalance: traderCashBalance,
            pricePerSecurity: pricePerSecurity
        )
        isTraderLimited = true
    }

    // 2. Calculate pot's purchasable quantity (with denomination and minimum order constraints)
    let potQuantity = calculateMaxPurchasableQuantity(
        potBalance: potBalance,
        pricePerSecurity: pricePerSecurity,
        denomination: denomination,
        minimumOrderAmount: minimumOrderAmount
    )

    // 3. Calculate total order (trader + pot)
    let totalQuantity = actualTraderQuantity + potQuantity
    let totalOrderAmount = Double(totalQuantity) * pricePerSecurity

    // 4. Validate minimum order amount for total order
    // Note: Individual portions (trader/pot) may be below minimum, but total must meet it
    if let minimum = minimumOrderAmount, minimum > 0 {
        guard totalOrderAmount >= minimum else {
            // Total order doesn't meet minimum - return zero quantities
            return CombinedOrderCalculationResult(/* zero values */)
        }
    }

    // 5. Calculate total fees for the combined order
    let totalFees = FeeCalculationService.calculateTotalFees(for: totalOrderAmount)

    // 6. Split fees proportionally between trader and pot
    let traderOrderAmountActual = Double(actualTraderQuantity) * pricePerSecurity
    let potOrderAmount = Double(potQuantity) * pricePerSecurity

    let traderFees: Double
    let potFees: Double

    if totalOrderAmount > 0 {
        let traderProportion = traderOrderAmountActual / totalOrderAmount
        let potProportion = potOrderAmount / totalOrderAmount
        traderFees = totalFees * traderProportion
        potFees = totalFees * potProportion
    } else {
        traderFees = 0
        potFees = 0
    }

    // 6. Calculate total costs
    let traderTotalCost = traderOrderAmountActual + traderFees
    let potTotalCost = potOrderAmount + potFees
    let totalCost = traderTotalCost + potTotalCost

    // 7. Calculate remaining balances
    let traderRemainingBalance = traderCashBalance - traderTotalCost
    let potRemainingBalance = potBalance - potTotalCost

    // 8. Check if pot is limited
    let isPotLimited = potQuantity == 0 && potBalance > 0

    // 9. Get fee breakdown
    let feeBreakdown = FeeCalculationService.createFeeBreakdown(for: totalOrderAmount)

    return CombinedOrderCalculationResult(
        traderQuantity: actualTraderQuantity,
        potQuantity: potQuantity,
        totalQuantity: totalQuantity,
        traderOrderAmount: traderOrderAmountActual,
        potOrderAmount: potOrderAmount,
        totalOrderAmount: totalOrderAmount,
        totalFees: totalFees,
        traderFees: traderFees,
        potFees: potFees,
        traderTotalCost: traderTotalCost,
        potTotalCost: potTotalCost,
        totalCost: totalCost,
        traderRemainingBalance: max(0, traderRemainingBalance),
        potRemainingBalance: max(0, potRemainingBalance),
        isTraderLimited: isTraderLimited,
        isPotLimited: isPotLimited,
        feeBreakdown: feeBreakdown
    )
}
```

### Example Calculation with Denomination Constraint

**Input:**
- Pot Balance: €15,321
- Price per Security: €2
- Denomination: **50** (must trade in multiples of 50)

**Calculation:**
1. Max possible (no fees): €15,321 / €2 = 7,660 pieces
2. Round to denomination: 7,660 → 7,650 (nearest multiple of 50)
3. Try 7,650 pieces:
   - Order Amount: 7,650 × €2 = €15,300
   - Fees: €71.50
   - Total Cost: €15,371.50
   - **Exceeds pot balance!**

4. Try 7,600 pieces:
   - Order Amount: 7,600 × €2 = €15,200
   - Fees: €71.50
   - Total Cost: €15,271.50
   - Remaining: €49.50 ✅

**Result:**
- Purchasable Quantity: **7,600 pieces** (valid denomination: multiple of 50)
- Order Amount: €15,200
- Fees: €71.50
- Total Cost: €15,271.50
- Remaining: €49.50

**Note**: Without denomination constraint, we could buy 7,624 pieces. With denomination of 50, we can only buy 7,600 pieces (24 pieces less due to rounding).

### Example Calculation with Minimum Order Amount

**Input:**
- Pot Balance: €15,321
- Price per Security: €2
- Minimum Order Amount: **€100** (order must be at least €100)

**Calculation:**
1. Check if pot balance can meet minimum: €15,321 >= €100 ✅
2. Calculate minimum quantity: ceil(€100 / €2) = 50 pieces
3. Max possible (no fees): €15,321 / €2 = 7,660 pieces
4. Start search from minimum: 50 pieces (not 0)
5. Binary search finds optimal: **7,624 pieces**
   - Order Amount: 7,624 × €2 = €15,248
   - Fees: €71.50
   - Total Cost: €15,319.50
   - Remaining: €1.50 ✅

**Result:**
- Purchasable Quantity: **7,624 pieces** (meets minimum order amount of €100)
- Order Amount: €15,248 (well above €100 minimum)
- Total Cost: €15,319.50

**Edge Case**: If pot balance was only €50:
- Cannot meet minimum order amount of €100
- Result: **0 pieces** (cannot execute order)

### Service Location

**Location**: `FIN1/Shared/Services/PotQuantityCalculationService.swift`

**Rationale**: This service is a cross-cutting calculation utility that:
- Serves both trader and investor features
- Is stateless and utility-like
- Similar to `FeeCalculationService` and `ProfitCalculationService` (also in `Shared/Services/`)

---

## Remaining Balance Handling

### Problem Statement

After a purchase, a pot may have a small remaining balance that's insufficient for another meaningful purchase. For example:
- Pot balance: €15,321
- Purchase cost: €15,319.50
- **Remaining balance: €1.50**

This small amount cannot purchase any securities (even 1 piece @ €2 = €2 + fees > €1.50).

### Recommended Strategy: Admin-Configurable Distribution

#### Primary Approach: Configurable Strategy with Threshold

**Admin Control**: The admin can choose between two strategies:
1. **Immediate Distribution**: Distribute remaining balance immediately if below threshold
2. **Accumulate Until Threshold**: Keep small remainders until threshold is reached, then distribute

**Rule**: If remaining balance is below a configurable threshold (default: €5), apply the selected strategy. Otherwise, keep it in the pot for future trades.

#### Rationale

1. **Prevents accumulation**: Avoids many small unusable balances
2. **Fair to investors**: Returns money that can't be used
3. **Cost-effective**: Only distributes when necessary
4. **Flexible**: Larger remainders stay for future trades

### Implementation Options

#### Option 1: Immediate Distribution (Recommended)

**When**: After each purchase, if remaining balance < threshold

**Process**:
1. Check if `potRemainingBalance < minimumThreshold` (e.g., €5)
2. If yes, distribute proportionally to all investors in the pot
3. Update pot balance to €0
4. Update investor account balances
5. Log distribution transaction

**Pros**:
- Clean pot balance
- Investors get money back quickly
- No accumulation of small amounts

**Cons**:
- More frequent distributions
- Potential for many small transactions

#### Option 2: Accumulate Until Threshold

**When**: Keep small remainders until pot balance reaches threshold, then distribute

**Process**:
1. Keep remaining balance in pot
2. On next purchase, add to pot balance
3. If accumulated balance < threshold after purchase, distribute
4. Otherwise, keep accumulating

**Pros**:
- Fewer distribution transactions
- Pot can grow from small remainders

**Cons**:
- Money tied up longer
- More complex logic

### Configuration Service Integration

The system supports admin-configurable pot balance distribution:

#### Configuration Settings

**Admin Interface**: `ConfigurationManagementView`
- **Strategy Selection**: Button-based selection to choose between:
  - Immediate Distribution
  - Accumulate Until Threshold
- **Threshold Setting**: Configurable threshold (default: €5.00, range: €1.00 - €100.00)

#### Service Implementation

```swift
// FIN1/Shared/Services/ConfigurationServiceProtocol.swift

enum PotBalanceDistributionStrategy: String, Codable, CaseIterable {
    case immediateDistribution = "immediate"
    case accumulateUntilThreshold = "accumulate"

    var displayName: String {
        switch self {
        case .immediateDistribution:
            return "Immediate Distribution"
        case .accumulateUntilThreshold:
            return "Accumulate Until Threshold"
        }
    }

    var description: String {
        switch self {
        case .immediateDistribution:
            return "Distribute remaining balance immediately if below threshold"
        case .accumulateUntilThreshold:
            return "Keep small remainders until threshold is reached, then distribute"
        }
    }
}

protocol ConfigurationServiceProtocol: ObservableObject {
    var potBalanceDistributionStrategy: PotBalanceDistributionStrategy { get }
    var potBalanceDistributionThreshold: Double { get }

    func updatePotBalanceDistributionStrategy(_ strategy: PotBalanceDistributionStrategy) async throws
    func updatePotBalanceDistributionThreshold(_ threshold: Double) async throws
    func validatePotBalanceDistributionThreshold(_ value: Double) -> Bool
}
```

### Distribution Service

```swift
// FIN1/Features/Investor/Services/PotBalanceDistributionService.swift

protocol PotBalanceDistributionServiceProtocol {
    /// Checks if pot remaining balance should be distributed
    /// - Parameters:
    ///   - remainingBalance: Remaining balance after purchase
    ///   - configuration: Configuration service to check strategy and threshold
    /// - Returns: True if balance should be distributed
    func shouldDistributeRemainingBalance(
        _ remainingBalance: Double,
        configuration: ConfigurationServiceProtocol
    ) -> Bool

    /// Distributes remaining pot balance proportionally to investors
    /// - Parameters:
    ///   - potId: The pot ID
    ///   - remainingBalance: Remaining balance to distribute
    /// - Returns: Distribution result with investor allocations
    func distributeRemainingBalance(
        potId: String,
        remainingBalance: Double
    ) async throws -> PotBalanceDistributionResult
}

struct PotBalanceDistributionResult {
    let potId: String
    let distributedAmount: Double
    let investorCount: Int
    let investorAllocations: [InvestorAllocation]
    let distributionDate: Date
}

struct InvestorAllocation {
    let investorId: String
    let originalInvestment: Double
    let potOwnershipPercentage: Double
    let distributedAmount: Double
}
```

### Integration into Purchase Flow

```swift
// After purchase completion in OrderLifecycleCoordinator

private func handleBuyOrderCompletion(orderId: String, order: Order) async {
    // ... existing code ...

    // After pot balance is updated
    if let potParticipation = potParticipation {
        let remainingBalance = potParticipation.potRemainingBalance

        // Check if should distribute based on admin configuration
        let shouldDistribute = potBalanceDistributionService.shouldDistributeRemainingBalance(
            remainingBalance,
            configuration: configurationService
        )

        if shouldDistribute {
            do {
                let distribution = try await potBalanceDistributionService.distributeRemainingBalance(
                    potId: potParticipation.potId,
                    remainingBalance: remainingBalance
                )

                // Notify investors of distribution
                await notificationService.notifyPotBalanceDistribution(distribution)
            } catch {
                print("Error distributing remaining balance: \(error)")
                // Log error but don't fail the order
            }
        }
    }
}
```

### Recommended Threshold Values

- **Minimum Distribution Threshold**: €5.00
  - Below this, distribute immediately
  - Above this, keep for next trade

- **Minimum Purchase Amount**: €10.00
  - Used to determine if remainder is "too small"
  - Helps decide distribution vs. keeping

### Edge Cases

#### 1. Multiple Small Purchases
If multiple purchases leave small remainders:
- Accumulate until threshold reached
- Then distribute all at once

#### 2. Pot Closure
When pot is closed (trader starts new pot):
- Distribute all remaining balance regardless of amount
- Ensure pot balance is €0

#### 3. Rounding Errors
When distributing, ensure:
- Sum of allocations = total distribution amount
- Handle rounding differences (add to largest investor)

#### 4. Zero Balance
If remaining balance is exactly €0:
- No action needed
- Pot balance stays at €0

---

## Architecture & File Structure

### Service Architecture

```
FIN1/
├── Shared/
│   └── Services/
│       ├── PotQuantityCalculationService.swift          ✅ (moved from Trader)
│       ├── PotQuantityCalculationServiceProtocol.swift  ✅
│       ├── FeeCalculationService.swift                   (used by pot calculation)
│       ├── ProfitCalculationService.swift               (pro-rata profit distribution)
│       └── ConfigurationService.swift                   (admin config for distribution)
│
├── Features/
│   ├── Trader/
│   │   └── Services/
│   │       ├── UnifiedOrderService.swift                (places combined orders)
│   │       └── OrderLifecycleCoordinator.swift          (handles order completion)
│   │
│   └── Investor/
│       └── Services/
│           └── PotBalanceDistributionService.swift     (distributes remaining balances)
```

### Key Services

1. **PotQuantityCalculationService** (`Shared/Services/`)
   - Calculates maximum purchasable quantity from pot balance
   - Combines trader + pot quantities
   - Splits fees proportionally

2. **UnifiedOrderService** (`Features/Trader/Services/`)
   - Places buy orders that affect trader + pot
   - Executes single order on stock exchange

3. **PotBalanceDistributionService** (`Features/Investor/Services/`)
   - Distributes small remaining balances
   - Respects admin configuration

4. **ConfigurationService** (`Shared/Services/`)
   - Manages admin-configurable settings
   - Pot balance distribution strategy
   - Distribution threshold

### Data Models

```swift
// Combined order calculation result
struct CombinedOrderCalculationResult {
    let traderQuantity: Int
    let potQuantity: Int
    let totalQuantity: Int
    let traderOrderAmount: Double
    let potOrderAmount: Double
    let totalOrderAmount: Double
    let totalFees: Double
    let traderFees: Double
    let potFees: Double
    let traderTotalCost: Double
    let potTotalCost: Double
    let totalCost: Double
    let traderRemainingBalance: Double
    let potRemainingBalance: Double
    let isTraderLimited: Bool
    let isPotLimited: Bool
    let feeBreakdown: FeeBreakdown
}

// Pot balance distribution result
struct PotBalanceDistributionResult {
    let potId: String
    let distributedAmount: Double
    let investorCount: Int
    let investorAllocations: [InvestorAllocation]
    let distributionDate: Date
}
```

---

## Implementation Details

### Frontend Integration

#### Buy Order ViewModel

```swift
// FIN1/Features/Trader/ViewModels/BuyOrderViewModel.swift

final class BuyOrderViewModel: ObservableObject {
    @Published var potOrderCalculation: CombinedOrderCalculationResult?
    @Published var showPotCalculation = false
    @Published var isPotLimited = false

    private let potQuantityCalculationService: PotQuantityCalculationServiceProtocol
    private let investmentService: InvestmentServiceProtocol

    func calculatePotOrder() async {
        // Get active pot balance (without showing it to trader)
        let activePots = investmentService.getPots(forTrader: currentTraderId)
        guard let activePot = activePots.first(where: { $0.status == .active }) else {
            // No active pot - trader can place order normally
            return
        }

        let potBalance = activePot.currentBalance
        let price = Double(searchResult.askPrice.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let desiredQuantity = Int(quantity)
        let traderCashBalance = traderService.getCashBalance()

        // Calculate combined order details
        let calculation = potQuantityCalculationService.calculateCombinedOrderDetails(
            traderQuantity: desiredQuantity,
            traderCashBalance: traderCashBalance,
            potBalance: potBalance,
            pricePerSecurity: price
        )

        potOrderCalculation = calculation
        isPotLimited = calculation.isPotLimited

        if calculation.isTraderLimited {
            // Update quantity to purchasable amount
            quantity = Double(calculation.traderQuantity)
        }
    }

    func placeOrder() async {
        // ... existing validation ...

        // Calculate pot order if pot is active
        await calculatePotOrder()

        // Use calculated quantity
        let actualQuantity = potOrderCalculation?.totalQuantity ?? Int(quantity)

        // Place order with calculated quantity
        let orderRequest = BuyOrderRequest(
            symbol: searchResult.wkn,
            quantity: actualQuantity, // Use calculated total quantity
            price: executedPrice,
            // ... other fields ...
        )

        // ... rest of order placement ...
    }
}
```

### Backend Implementation

#### Parse Server Cloud Function

```javascript
Parse.Cloud.define("calculatePotOrderQuantity", async (request) => {
  const { traderId, pricePerSecurity, desiredQuantity, traderCashBalance } = request.params;

  // 1. Get active pot for trader
  const activePot = await getActivePotForTrader(traderId);
  if (!activePot) {
    return { error: "No active pot found" };
  }

  const potBalance = activePot.get("currentBalance");

  // 2. Calculate trader's actual quantity (may be limited by cash)
  const traderOrderAmount = desiredQuantity * pricePerSecurity;
  const traderFees = calculateTotalFees(traderOrderAmount);
  const traderTotalCost = traderOrderAmount + traderFees;

  let actualTraderQuantity = desiredQuantity;
  let isTraderLimited = false;

  if (traderTotalCost > traderCashBalance) {
    actualTraderQuantity = calculateMaxPurchasableQuantity(
      traderCashBalance,
      pricePerSecurity
    );
    isTraderLimited = true;
  }

  // 3. Calculate pot's maximum purchasable quantity
  const potQuantity = calculateMaxPurchasableQuantity(
    potBalance,
    pricePerSecurity
  );

  // 4. Calculate total order
  const totalQuantity = actualTraderQuantity + potQuantity;
  const totalOrderAmount = totalQuantity * pricePerSecurity;
  const totalFees = calculateTotalFees(totalOrderAmount);

  // 5. Split fees proportionally
  const traderOrderAmountActual = actualTraderQuantity * pricePerSecurity;
  const potOrderAmount = potQuantity * pricePerSecurity;

  const traderProportion = traderOrderAmountActual / totalOrderAmount;
  const potProportion = potOrderAmount / totalOrderAmount;

  const traderFeesActual = totalFees * traderProportion;
  const potFeesActual = totalFees * potProportion;

  // 6. Calculate remaining balances
  const traderRemainingBalance = traderCashBalance - (traderOrderAmountActual + traderFeesActual);
  const potRemainingBalance = potBalance - (potOrderAmount + potFeesActual);

  return {
    traderQuantity: actualTraderQuantity,
    potQuantity: potQuantity,
    totalQuantity: totalQuantity,
    traderOrderAmount: traderOrderAmountActual,
    potOrderAmount: potOrderAmount,
    totalOrderAmount: totalOrderAmount,
    totalFees: totalFees,
    traderFees: traderFeesActual,
    potFees: potFeesActual,
    traderTotalCost: traderOrderAmountActual + traderFeesActual,
    potTotalCost: potOrderAmount + potFeesActual,
    traderRemainingBalance: Math.max(0, traderRemainingBalance),
    potRemainingBalance: Math.max(0, potRemainingBalance),
    isTraderLimited: isTraderLimited,
    isPotLimited: potQuantity === 0 && potBalance > 0
  };
});

function calculateMaxPurchasableQuantity(potBalance, pricePerSecurity) {
  let low = 0;
  let high = Math.floor(potBalance / pricePerSecurity);
  let bestQuantity = 0;

  while (low <= high) {
    const mid = Math.floor((low + high) / 2);
    const orderAmount = mid * pricePerSecurity;
    const fees = calculateTotalFees(orderAmount);
    const totalCost = orderAmount + fees;

    if (totalCost <= potBalance) {
      bestQuantity = mid;
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }

  return bestQuantity;
}

function calculateTotalFees(orderAmount) {
  const orderFee = Math.max(5, Math.min(50, orderAmount * 0.005));
  const exchangeFee = Math.max(1, Math.min(20, orderAmount * 0.001));
  const foreignCosts = 1.50;
  return orderFee + exchangeFee + foreignCosts;
}
```

---

## Testing & Validation

### Unit Tests

```swift
func testCalculateMaxPurchasableQuantity() {
    let service = PotQuantityCalculationService()

    // Test case 1: Small pot
    let quantity1 = service.calculateMaxPurchasableQuantity(
        potBalance: 1000,
        pricePerSecurity: 10
    )
    XCTAssertEqual(quantity1, 98) // Accounts for fees

    // Test case 2: Large pot
    let quantity2 = service.calculateMaxPurchasableQuantity(
        potBalance: 15321,
        pricePerSecurity: 2
    )
    XCTAssertEqual(quantity2, 7624)

    // Test case 3: Edge case - insufficient balance
    let quantity3 = service.calculateMaxPurchasableQuantity(
        potBalance: 5,
        pricePerSecurity: 10
    )
    XCTAssertEqual(quantity3, 0)
}

func testCalculateCombinedOrderDetails() {
    let service = PotQuantityCalculationService()

    let result = service.calculateCombinedOrderDetails(
        traderQuantity: 1000,
        traderCashBalance: 50000,
        potBalance: 15321,
        pricePerSecurity: 2
    )

    XCTAssertEqual(result.traderQuantity, 1000)
    XCTAssertEqual(result.potQuantity, 7624)
    XCTAssertEqual(result.totalQuantity, 8624)
    XCTAssertFalse(result.isTraderLimited)
    XCTAssertFalse(result.isPotLimited)
    XCTAssertGreaterThan(result.potRemainingBalance, 0)
    XCTAssertLessThan(result.potRemainingBalance, 5) // Should be small remainder
}
```

### Integration Tests

```swift
func testPotOrderPlacementFlow() async throws {
    // 1. Setup: Create trader with active pot
    let trader = createTestTrader()
    let pot = createActivePot(traderId: trader.id, balance: 15321)

    // 2. Place buy order
    let orderRequest = BuyOrderRequest(
        symbol: "TEST",
        quantity: 1000,
        price: 2.0
    )

    let order = try await traderService.placeBuyOrder(orderRequest)

    // 3. Verify order quantity includes pot
    XCTAssertEqual(order.quantity, 8624) // 1000 + 7624

    // 4. Verify pot balance updated
    let updatedPot = try await getPot(pot.id)
    XCTAssertLessThan(updatedPot.balance, 5) // Small remainder

    // 5. Verify remaining balance distribution (if configured)
    if shouldDistribute(updatedPot.balance) {
        let distribution = try await potBalanceDistributionService
            .distributeRemainingBalance(
                potId: pot.id,
                remainingBalance: updatedPot.balance
            )
        XCTAssertEqual(distribution.distributedAmount, updatedPot.balance)
    }
}
```

### Security Considerations

1. **Pot Balance Validation**: Verify pot exists and has sufficient balance
2. **Price Validation**: Ensure price is positive and reasonable
3. **Quantity Limits**: Enforce maximum order size limits
4. **Atomic Operations**: Use database transactions for order placement
5. **Audit Logging**: Log all quantity calculations and distributions

---

## Summary

This comprehensive implementation covers:

✅ **Synchronized Trading**: Trader + pot quantities combined into single order
✅ **Fee-Aware Calculation**: Binary search algorithm for maximum purchasable quantity
✅ **Proportional Fee Splitting**: Fees calculated on total order, split proportionally
✅ **Admin Configuration**: Configurable strategies for remaining balance handling
✅ **Proportional Distribution**: Small remainders distributed to investors proportionally
✅ **Service Architecture**: Proper separation of concerns with shared utilities
✅ **Testing Strategy**: Unit and integration tests for validation

The system ensures accurate quantity calculation, fair fee distribution, and flexible handling of small remaining balances while maintaining transparency for traders and investors.

