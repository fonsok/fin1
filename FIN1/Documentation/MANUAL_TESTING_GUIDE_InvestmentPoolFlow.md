# Manual Testing Guide: Investment Pool Completion Flow

> **Updated**: December 2024 - Terminology changed from "pool" to "pool" for consistency

## Overview
This guide walks you through manually testing the complete investment pool completion flow in the app.

## Prerequisites
- App is running and showing the landing page
- You have test accounts for both Investor and Trader roles

---

## Step-by-Step Testing Process

### Phase 1: Setup - Sign In as Investor

1. **From Landing Page:**
   - Tap "Login" or "Get Started"
   - Sign in as an **Investor** user
   - You should see the Dashboard

2. **Navigate to Trader Discovery:**
   - From Dashboard, navigate to "Discovery" or "Traders" tab
   - Browse available traders
   - Select a trader you want to invest in

---

### Phase 2: Create Investment with Multiple Pools

3. **Open Investment Sheet:**
   - On the trader detail page, tap "Invest" button
   - Investment sheet should appear

4. **Configure Investment:**
   - **Amount per pool**: Enter €500
   - **Number of pools**: Select 3 pools
   - **Total investment**: Should show €1,500 (3 × €500)
   - **Pool selection**: Choose "Multiple Pools" strategy

5. **Create Investment:**
   - Tap "Create Investment" or "Confirm"
   - Wait for success message
   - Investment should be created with status: **Active**

6. **Verify Investment Created:**
   - Navigate to "Portfolio" or "Investments" tab
   - Find your new investment in "Ongoing Investments"
   - Verify:
     - ✅ Investment status: **Active**
     - ✅ Number of pools: **3**
     - ✅ Total amount: **€1,500**
     - ✅ All pool reservations show status: **Reserved** (Status 1)

---

### Phase 3: Switch to Trader View and Start Trading

7. **Sign Out and Sign In as Trader:**
   - Sign out from investor account
   - Sign in as the **Trader** you invested in
   - Navigate to Trader Depool/Trading view

8. **Verify Pool is Available:**
   - Trader should see that a pool is available
   - Pool status should show as **Active** (Status 2) when trader starts using it
   - Note: The pool status changes from `.reserved` → `.active` when trader begins trading

9. **Place Buy Order:**
   - Navigate to trading interface
   - Place a buy order (e.g., buy 100 shares of AAPL at €50)
   - The system should combine:
     - Trader's own money
     - Pool money (€500 from your investment)
   - Execute the buy order

10. **Place Sell Order:**
    - After buy order executes, place a corresponding sell order
    - Complete the trade cycle
    - Trade should show as completed

---

### Phase 4: Verify Pool Status Updates

11. **Check Pool Status After Trade Completion:**
    - **IMPORTANT**: This step requires implementation
    - When a trade involving a pool is completed, the pool reservation status should update:
      - From `.active` → `.completed` (Status 3)
    - **Current Status**: This may need to be implemented (see TODO in `OrderLifecycleCoordinator.swift`)

12. **Verify Investment Status:**
    - Sign back in as Investor
    - Navigate to Portfolio/Investments
    - Check your investment:
      - ✅ Pool 1 should show status: **Completed** (Status 3)
      - ✅ Investment status: Still **Active** (waiting for other pools)

---

### Phase 5: Complete All Pools

13. **Repeat Trading for Remaining Pools:**
    - Sign in as Trader again
    - Complete trades for Pool 2:
      - Place buy order
      - Place sell order
      - Complete trade
    - Pool 2 status should become: **Completed** (Status 3)

    - Complete trades for Pool 3:
      - Place buy order
      - Place sell order
      - Complete trade
    - Pool 3 status should become: **Completed** (Status 3)

14. **Verify All Pools Completed:**
    - Sign in as Investor
    - Navigate to Portfolio/Investments
    - Check investment:
      - ✅ All 3 pools show status: **Completed** (Status 3)
      - ✅ Investment status: Should automatically transition to **Completed**
      - ✅ `completedAt` date should be set

---

### Phase 6: Verify Completed Investment Appears

15. **Navigate to Completed Investments:**
    - From Dashboard, tap "Investments" button
    - Or navigate to "Completed Investments" page
    - Your investment should appear in the completed list

16. **Verify Completed Investment Details:**
    - ✅ Investment appears in completed investments table
    - ✅ Shows investment number
    - ✅ Shows trader name
    - ✅ Shows invested amount (€1,500)
    - ✅ Shows profit (if calculated)
    - ✅ Shows return percentage (if calculated)
    - ✅ Can filter by year
    - ✅ Year appears in available years filter

---

## What to Check at Each Step

### Investment Creation
- [ ] Investment created successfully
- [ ] All pools start as `.reserved` (Status 1)
- [ ] Investment status is `.active`
- [ ] Investment appears in "Ongoing Investments"

### Trader Trading
- [ ] Trader can see pool is available
- [ ] Pool status changes to `.active` (Status 2) when trader starts
- [ ] Buy/sell orders execute successfully
- [ ] Trade completes successfully

### Pool Completion
- [ ] Pool status updates to `.completed` (Status 3) after trade completion
- [ ] Investment remains `.active` until all pools are done
- [ ] Each pool can be completed independently

### Investment Completion
- [ ] Investment automatically transitions to `.completed` when all pools done
- [ ] `completedAt` date is set
- [ ] Investment appears in "Completed Investments" page
- [ ] Year filtering works correctly

---

## Known Limitations / TODO Items

### ⚠️ Pool Status Update Mechanism
The automatic update of pool reservation status from `.active` → `.completed` when trades complete may need implementation.

**Location**: `FIN1/Features/Trader/Services/OrderLifecycleCoordinator.swift:226`
```swift
// TODO: Distribute profit to investors if trade involved pools
// This will be implemented when pool trade participation tracking is added
```

**What's Needed:**
1. Track which pools are involved in each trade
2. When a trade completes, update the corresponding pool reservation status
3. Call `checkAndUpdateInvestmentCompletion()` to check if investment should complete

### Testing Workaround
For now, you can manually update pool statuses in the test to verify the completion logic works correctly (as done in the unit test).

---

## Troubleshooting

### Investment Doesn't Complete
- **Check**: Are all pools showing status `.completed`?
- **Check**: Is `checkAndUpdateInvestmentCompletion()` being called?
- **Check**: Does investment have `allPoolsCompleted == true`?

### Pool Status Not Updating
- **Check**: Is trade completion triggering pool status update?
- **Check**: Is pool reservation linked to the trade?
- **Check**: Is the update happening in the investment service?

### Completed Investment Not Appearing
- **Check**: Is investment status actually `.completed`?
- **Check**: Is `completedAt` date set?
- **Check**: Is the view model loading completed investments correctly?

---

## Next Steps After Testing

1. **If pool status updates are not working:**
   - Implement pool status update mechanism in trade completion flow
   - Link trades to pool reservations
   - Update pool status when trades complete

2. **If investment completion works:**
   - Verify ROI calculations
   - Test with multiple investors in same pool
   - Test edge cases (cancelled pools, partial completion, etc.)

3. **If everything works:**
   - Test with real backend integration
   - Test with multiple concurrent investments
   - Test performance with large datasets

---

## Related Files

- **Test File**: `FIN1Tests/InvestmentPoolCompletionFlowTests.swift`
- **Investment Model**: `FIN1/Features/Investor/Models/Investment.swift`
- **Investment Service**: `FIN1/Features/Investor/Services/InvestmentServiceProtocol.swift`
- **Completion Logic**: `FIN1/Features/Investor/ViewModels/CompletedInvestmentsViewModel.swift`
- **Trade Completion**: `FIN1/Features/Trader/Services/OrderLifecycleCoordinator.swift`
- **Documentation**: `FIN1/Documentation/INVESTMENT_COMPLETION_FLOW.md`


