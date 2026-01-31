# Investment Completion Flow

## Overview
This document explains how an investment transitions from "Ongoing" (active) to "Completed" and appears on the Completed Investments page.

## The Flow

### Step 1: Investor Creates Investment
- Investor creates an investment with multiple pots (e.g., 3 pots of €500 each = €1500 total)
- Investment status: **`.active`** (ongoing)
- Pot reservations created with status: **`.reserved`** (Status 1)

### Step 2: Trader Starts Trading
- Trader sees pot is available (status becomes **`.active`** - Status 2)
- Trader places buy orders using their own money
- **Backend combines**: Trader's money + Pot money → Places **ONE** buy order
- This prevents price changes between separate orders and ensures atomic execution
- From trader's perspective: They only know the pot is "active" - backend handles money combination transparently
- Investment status: Still **`.active`** (ongoing)

### Step 3: Trader Completes Trades for a Pot
- Trader completes all trades that involved that pot
- Backend distributes results: Returns pot portion to investors, trader portion to trader
- Pot reservation status changes: **`.active`** → **`.completed`** (Status 3)
- Investment status: Still **`.active`** (ongoing) - waiting for ALL pots to complete

### Step 4: Trader Completes ALL Pots
- When **ALL** pot reservations reach status **`.completed`** (Status 3)
- The system automatically detects this via `checkAndUpdateInvestmentCompletion()`
- Investment status automatically changes: **`.active`** → **`.completed`**
- `completedAt` date is set to current date

### Step 5: Investment Appears on Completed Investments Page
- The completed investment now appears in `completedInvestments` list
- It can be filtered by year using `completedInvestmentsByYear`
- It shows up on the "Completed Investments" page (accessed via "Investments" button on dashboard)

## Code Logic

### Key Method: `checkAndUpdateInvestmentCompletion()`

```swift
private func checkAndUpdateInvestmentCompletion() {
    for index in investments.indices {
        let investment = investments[index]

        // Only check active investments
        guard investment.status == .active else { continue }

        // Check if all pots are completed (status 3)
        if investment.allPotsCompleted {
            let updatedInvestment = investment.markAsCompleted()
            investments[index] = updatedInvestment
        }
    }
}
```

### Key Property: `allPotsCompleted`

```swift
var allPotsCompleted: Bool {
    guard !reservedPotSlots.isEmpty else { return false }
    return reservedPotSlots.allSatisfy { $0.status == .completed }
}
```

This checks if **ALL** pot reservations have status `.completed`.

## When This Check Happens

The `checkAndUpdateInvestmentCompletion()` method is called:
1. When `loadCompletedInvestments()` is called (page load)
2. When `reconfigure()` is called (service updates)
3. After investments are loaded from the service

## Test Coverage

The tests verify:
- ✅ Investment transitions from active → completed when all pots are done
- ✅ Investment stays active if not all pots are completed
- ✅ Only active investments are checked (completed/cancelled are ignored)
- ✅ Completed investment appears in `completedInvestments` list
- ✅ Completed investment can be filtered by year
- ✅ Year appears in `availableYears` list

## Example Scenario

1. **Day 1**: Investor creates investment with 3 pots (€500 each)
   - Status: `.active`
   - Pots: [`.reserved`, `.reserved`, `.reserved`]

2. **Day 2**: Trader sees Pot 1 is available, starts trading
   - Trader places buy orders (using their own money)
   - Backend combines: Trader money + Pot 1 money (€500) → Places ONE buy order
   - Pot 1 status: **`.reserved`** → **`.active`** (Status 2)
   - Investment status: Still **`.active`** (ongoing)
   - Pots: [`.active`, `.reserved`, `.reserved`]

3. **Day 5**: Trader completes all trades involving Pot 1
   - Backend distributes: Pot 1 portion goes to investors, trader portion to trader
   - Pot 1 status: **`.active`** → **`.completed`** (Status 3)
   - Investment status: Still **`.active`** (waiting for other pots)
   - Pots: [`.completed`, `.reserved`, `.reserved`]

4. **Day 10**: Trader completes Pot 2 and Pot 3 trades
   - Backend distributes results for both pots
   - Pot 2 & 3 status: **`.active`** → **`.completed`** (Status 3)
   - Investment status: **`.active`** → **`.completed`** (automatic transition!)
   - Pots: [`.completed`, `.completed`, `.completed`]
   - `completedAt`: Set to current date

5. **Day 11**: Investor opens "Completed Investments" page
   - Investment appears in the list
   - Can filter by year (e.g., 2024)
   - Shows all details (amount, profit, return, etc.)

## Important Notes

### Trading Mechanism
- **Trader perspective**: Trader only sees pot is "active" - they don't see pot money being combined
- **Backend reality**: When trader places buy order, backend combines trader money + pot money → places ONE buy order
- **Why one order**: Prevents price changes between separate orders and ensures atomic execution
- **Result distribution**: When trades complete, backend distributes pot portion to investors, trader portion to trader

### Completion Logic
- The transition from active → completed is **automatic** - no manual action needed
- The check happens whenever investments are loaded/refreshed
- An investment can only be completed when **ALL** pots are completed
- If even one pot is still `.active` or `.reserved`, the investment stays `.active`

