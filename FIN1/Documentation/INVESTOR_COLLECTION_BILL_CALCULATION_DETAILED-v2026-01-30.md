# Investor Collection Bill Calculation - Detailed Summary

## Overview

This document provides a comprehensive explanation of how the investor collection bill calculates all values, including buy/sell amounts, quantities, fees, and profit. The calculation ensures that displayed values match the actual investment capital and quantities, even when invoice data may be incorrect.

---

## Table of Contents

1. [Data Sources](#data-sources)
2. [Buy Leg Calculation](#buy-leg-calculation)
3. [Sell Leg Calculation](#sell-leg-calculation)
4. [Fee Allocation](#fee-allocation)
5. [Profit Calculation](#profit-calculation)
6. [Complete Calculation Flow](#complete-calculation-flow)
7. [Example Scenario](#example-scenario)
8. [Key Principles](#key-principles)

---

## Data Sources

### Primary Data Sources

1. **Investment Capital (`Investment.amount`)**
   - **What it is**: The actual capital amount the investor invested
   - **Source**: `Investment` model, field `amount`
   - **Type**: `Double` (EUR)
   - **Example**: €4,333.33
   - **Usage**: Primary source of truth for buy amount calculation

2. **Trade Data (`Trade`)**
   - **Entry Price**: `trade.entryPrice` - The price at which securities were bought
   - **Total Quantity**: `trade.totalQuantity` - Total quantity bought in the trade (trader + investor combined)
   - **Source**: `Trade` model from `TradeLifecycleService`

3. **Invoice Data (`Invoice`)**
   - **Buy Invoice**: Contains buy transaction details (may have incorrect quantities)
   - **Sell Invoices**: Array of sell transaction invoices
   - **Usage**:
     - For fee calculation (fees are accurate on invoices)
     - For sell price calculation (average sell price from invoices)
     - **NOT used** for buy amount/quantity (uses investment capital instead)

4. **Participation Data (`PotTradeParticipation`)**
   - **Ownership Percentage**: Investor's share of the trade (0.0 to 1.0)
   - **Allocated Amount**: Securities value allocated to this investment (for ROI calculation)
   - **Source**: `PotTradeParticipationService`

---

## Buy Leg Calculation

### Step 1: Determine Investment Capital

**Location**: `InvestorInvestmentStatementAggregator.summarizeInvestment()`

```swift
// Get the actual investment to access the capital amount (source of truth)
let allInvestments = investmentService.investments
guard let investment = allInvestments.first(where: { $0.id == investmentId }) else {
    return nil
}
let totalInvestmentCapital = investment.amount
```

**Result**: Total capital invested (e.g., €4,333.33)

### Step 2: Calculate Trade's Share of Capital

**For Single Trade**:
- If the investment participated in only one trade, use the full investment capital
- `tradeCapitalShare = totalInvestmentCapital`

**For Multiple Trades**:
- Distribute capital proportionally based on ownership percentage
- Formula:
  ```swift
  let totalOwnership = participations.reduce(0.0) { $0 + $1.ownershipPercentage }
  tradeCapitalShare = totalOwnership > 0
      ? (totalInvestmentCapital * participation.ownershipPercentage / totalOwnership)
      : (totalInvestmentCapital / Double(participations.count))
  ```

**Example**:
- Investment capital: €4,333.33
- Trade 1 ownership: 50% → Capital share: €2,166.67
- Trade 2 ownership: 50% → Capital share: €2,166.66

### Step 3: Calculate Buy Amount and Quantity

**Location**: `InvestorInvestmentStatementItem.build()`

```swift
if let investmentCapital = investmentCapitalAmount, investmentCapital > 0 {
    // Use actual investment capital as buy amount (what investor actually invested)
    buyTotal = investmentCapital

    // Calculate quantity from capital: capital / buy price, rounded down
    let calculatedQty = investmentCapital / buyPrice
    buyQty = floor(calculatedQty * 100) / 100 // Round down to 2 decimal places
}
```

**Formula**:
- **Buy Amount**: `buyTotal = investmentCapital` (direct use of capital)
- **Buy Quantity**: `buyQty = floor((investmentCapital / buyPrice) * 100) / 100`

**Example**:
- Investment capital: €3,000.00
- Buy price: €2.00
- Buy quantity: `floor((3000.00 / 2.00) * 100) / 100 = floor(1500.00) = 1,500.00 Stk`
- Buy amount: €3,000.00

**Why This Approach?**
- Investment capital is the **source of truth** - it's what the investor actually invested
- Invoice data may have incorrect quantities (from earlier bug)
- This ensures the displayed buy amount matches the investment amount shown in "Completed Investments"

### Step 4: Calculate Buy Fees

**Location**: `InvestorInvestmentStatementItem.buildFeeDetails()`

```swift
let buyFeeDetails = buildFeeDetails(
    from: buyInvoice,
    scale: ownershipPercentage
)
let buyFeesInvestor = buyFeeDetails.reduce(0) { $0 + $1.amount }
```

**Process**:
1. Extract fee items from buy invoice
2. Scale each fee by `ownershipPercentage`
3. Sum all scaled fees

**Example**:
- Total buy fees (from invoice): €20.24
- Ownership percentage: 50%
- Investor buy fees: €20.24 × 0.5 = €10.12

---

## Sell Leg Calculation

### Step 1: Calculate Total Sell Quantity and Value from Invoices

**Location**: `InvestorInvestmentStatementItem.build()`

```swift
let totalSellQtyFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
    total + invoice.securitiesItems.reduce(0.0) { $0 + $1.quantity }
}
let totalSellValueFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
    total + invoice.securitiesTotal
}
```

**Purpose**: Get the total quantity and value sold across all sell invoices (trader + investor combined)

**Example**:
- Sell Invoice 1: 1,000 Stk @ €4.20 = €4,200
- Sell Invoice 2: 500 Stk @ €4.20 = €2,100
- Total sell quantity: 1,500 Stk
- Total sell value: €6,300

### Step 2: Calculate Sell Percentage

**Formula**:
```swift
let sellPercentage = trade.totalQuantity > 0
    ? (totalSellQtyFromInvoices / trade.totalQuantity)
    : 0.0
```

**Purpose**: Determines what percentage of the total buy quantity was sold

**Example**:
- Total buy quantity (trade): 3,000 Stk
- Total sell quantity (invoices): 1,500 Stk
- Sell percentage: 1,500 / 3,000 = 0.5 (50%)

### Step 3: Calculate Investor's Sell Quantity

**Formula**:
```swift
let investorSellQty = investorBuyQty * sellPercentage
```

**Purpose**: Calculates how much the investor sold, proportional to what they bought

**Example**:
- Investor buy quantity: 1,500 Stk
- Sell percentage: 50%
- Investor sell quantity: 1,500 × 0.5 = 750 Stk

**Note**: If trader sold all (100%), investor also sells all their quantity (100%)

### Step 4: Calculate Average Sell Price

**Formula**:
```swift
let sellAvgPrice = totalSellQtyFromInvoices > 0
    ? totalSellValueFromInvoices / totalSellQtyFromInvoices
    : 0.0
```

**Purpose**: Calculates the average price per unit across all sell transactions

**Example**:
- Total sell value: €6,300
- Total sell quantity: 1,500 Stk
- Average sell price: €6,300 / 1,500 = €4.20

### Step 5: Calculate Investor's Sell Amount

**✅ CRITICAL FIX**: Calculate from actual quantity and price, not from scaled invoice value

**Formula**:
```swift
let investorSellValue = investorSellQty * sellAvgPrice
```

**Why This Approach?**
- Ensures sell amount matches displayed quantity
- Example: 1,500 Stk @ €4.20 = €6,300 (not €3,150)
- Previous incorrect approach: `totalSellValueFromInvoices * ownershipPercentage` gave wrong result

**Example**:
- Investor sell quantity: 1,500 Stk
- Average sell price: €4.20
- Investor sell amount: 1,500 × 4.20 = €6,300.00

---

## Fee Allocation

### Buy Fees

**Calculation**:
```swift
let buyFeeDetails = buildFeeDetails(
    from: buyInvoice,
    scale: ownershipPercentage
)
```

**Process**:
1. Extract all fee items from buy invoice
2. Scale each fee by `ownershipPercentage`
3. Sum to get total buy fees

**Example**:
- Ordergebühr: €20.24 → Investor: €20.24 × 0.5 = €10.12
- Börsenplatzgebühr: €15.00 → Investor: €15.00 × 0.5 = €7.50
- Fremdkostenpauschale: €3.00 → Investor: €3.00 × 0.5 = €1.50
- Total buy fees: €19.12

### Sell Fees

**Calculation**:
```swift
let sellShare = totalSellQtyFromInvoices > 0
    ? (investorSellQty / totalSellQtyFromInvoices)
    : ownershipPercentage

let sellFeeDetails = buildFeeDetails(
    from: sellInvoices,
    scale: sellShare
)
```

**Process**:
1. Calculate `sellShare` = investor's sell quantity / total sell quantity
2. Extract all fee items from sell invoices
3. Scale each fee by `sellShare`
4. Sum to get total sell fees (negative values)

**Why Quantity-Based?**
- Ensures fees are allocated based on actual quantities sold
- More accurate than value-based allocation when prices vary

**Example**:
- Investor sell quantity: 1,500 Stk
- Total sell quantity: 3,000 Stk
- Sell share: 1,500 / 3,000 = 0.5 (50%)
- Ordergebühr: -€40.04 → Investor: -€40.04 × 0.5 = -€20.02
- Börsenplatzgebühr: -€31.50 → Investor: -€31.50 × 0.5 = -€15.75
- Total sell fees: -€35.77

---

## Profit Calculation

### Gross Profit (Before Commission & Taxes)

**Formula**:
```swift
let grossProfit = investorSellValue + investorSellFees - (buyTotal + buyFeesInvestor)
```

**Components**:
- **investorSellValue**: Sell amount (quantity × price)
- **investorSellFees**: Sell fees (negative, so adding them subtracts them)
- **buyTotal**: Buy amount (investment capital)
- **buyFeesInvestor**: Buy fees

**Note**: Sell fees are negative (deductions), so we add them (which subtracts them from the sell amount).

**Example**:
- Sell value: €6,300.00
- Sell fees: -€35.77
- Buy amount: €3,000.00
- Buy fees: €19.12
- Gross profit: €6,300.00 + (-€35.77) - (€3,000.00 + €19.12)
- Gross profit: €6,300.00 - €35.77 - €3,019.12 = €3,245.11

**Note**: This matches the collection bill display "Gross Profit (before commission & taxes)"

### ROI Gross Profit

**Formula**:
```swift
let roiGrossProfit = investorSellValue - roiInvestedAmount
```

**Where**:
- `roiInvestedAmount = investorBuyQty * buyPrice`

**Purpose**: Pure securities value difference (for ROI calculation, excludes fees)

**Example**:
- Sell value: €6,300.00
- ROI invested amount: 1,500 × €2.00 = €3,000.00
- ROI gross profit: €6,300.00 - €3,000.00 = €3,300.00

---

## Complete Calculation Flow

### Data Flow Diagram

```
Investment (€4,333.33)
    ↓
[Calculate Trade Capital Share]
    ↓
Trade Capital Share (€3,000.00 for this trade)
    ↓
[Calculate Buy Amount & Quantity]
    ├─→ Buy Amount: €3,000.00 (direct use of capital)
    └─→ Buy Quantity: 1,500.00 Stk (capital / buy price)
         ↓
    [Calculate Buy Fees]
         └─→ Buy Fees: €19.12 (scaled by ownership %)

Trade Data + Sell Invoices
    ↓
[Calculate Sell Data]
    ├─→ Total Sell Qty: 1,500 Stk (from invoices)
    ├─→ Total Sell Value: €6,300 (from invoices)
    ├─→ Average Sell Price: €4.20 (value / quantity)
    ├─→ Sell Percentage: 50% (sell qty / buy qty)
    ├─→ Investor Sell Qty: 750 Stk (buy qty × sell %)
    └─→ Investor Sell Value: €3,150 (sell qty × price)
         ↓
    [Calculate Sell Fees]
         └─→ Sell Fees: -€17.89 (scaled by sell share)

[Calculate Profit]
    ├─→ Gross Profit: €3,316.65
    └─→ ROI Gross Profit: €3,300.00
```

### Step-by-Step Process

1. **Initialization**
   - Get investment from `InvestmentService`
   - Get participations from `PotTradeParticipationService`
   - Get trades from `TradeLifecycleService`
   - Get invoices from `InvoiceService`

2. **For Each Trade Participation**:
   - Calculate trade's share of investment capital
   - Calculate buy amount (from capital)
   - Calculate buy quantity (capital / buy price)
   - Calculate buy fees (from invoice, scaled)
   - Calculate sell percentage (from invoices)
   - Calculate investor sell quantity (buy qty × sell %)
   - Calculate average sell price (from invoices)
   - Calculate investor sell value (sell qty × price)
   - Calculate sell fees (from invoices, scaled by sell share)
   - Calculate gross profit
   - Calculate ROI gross profit

3. **Aggregation**:
   - Sum all statement items
   - Calculate totals for display

---

## Example Scenario

### Input Data

**Investment**:
- Investment ID: `INV-001`
- Investment Capital: €3,000.00
- Trader: "Thomas Trader"

**Trade**:
- Trade #001
- Buy: 3,000 Stk @ €2.00 = €6,000
- Sell: 1,500 Stk @ €4.20 = €6,300
- Entry Price: €2.00

**Participation**:
- Ownership Percentage: 50% (0.5)
- Allocated Amount: €3,000 (securities value)

**Invoices**:
- Buy Invoice:
  - Quantity: 3,000 Stk
  - Price: €2.00
  - Securities Total: €6,000
  - Fees: €40.24 (Ordergebühr: €20.24, Börsenplatz: €15.00, Fremdkosten: €5.00)

- Sell Invoice:
  - Quantity: 1,500 Stk
  - Price: €4.20
  - Securities Total: €6,300
  - Fees: -€40.04 (Ordergebühr: -€20.02, Börsenplatz: -€15.75, Fremdkosten: -€4.27)

### Calculation Steps

#### Buy Leg

1. **Trade Capital Share**:
   - Single trade → Use full capital: €3,000.00

2. **Buy Amount**:
   - `buyTotal = €3,000.00` (investment capital)

3. **Buy Quantity**:
   - `buyQty = floor((€3,000.00 / €2.00) * 100) / 100`
   - `buyQty = floor(1,500.00) = 1,500.00 Stk`

4. **Buy Fees**:
   - Ordergebühr: €20.24 × 0.5 = €10.12
   - Börsenplatz: €15.00 × 0.5 = €7.50
   - Fremdkosten: €5.00 × 0.5 = €2.50
   - **Total Buy Fees**: €20.12

#### Sell Leg

1. **Total Sell Data from Invoices**:
   - `totalSellQtyFromInvoices = 1,500 Stk`
   - `totalSellValueFromInvoices = €6,300`

2. **Sell Percentage**:
   - `sellPercentage = 1,500 / 3,000 = 0.5` (50%)

3. **Investor Sell Quantity**:
   - `investorSellQty = 1,500 × 0.5 = 750 Stk`

4. **Average Sell Price**:
   - `sellAvgPrice = €6,300 / 1,500 = €4.20`

5. **Investor Sell Value**:
   - `investorSellValue = 750 × €4.20 = €3,150.00`

6. **Sell Fees**:
   - Sell share: 750 / 1,500 = 0.5 (50%)
   - Ordergebühr: -€20.02 × 0.5 = -€10.01
   - Börsenplatz: -€15.75 × 0.5 = -€7.88
   - Fremdkosten: -€4.27 × 0.5 = -€2.14
   - **Total Sell Fees**: -€20.03

#### Profit Calculation

1. **Gross Profit**:
   - `grossProfit = €3,150.00 - (-€20.03) - (€3,000.00 + €20.12)`
   - `grossProfit = €3,150.00 + €20.03 - €3,020.12`
   - `grossProfit = €149.91`

2. **ROI Gross Profit**:
   - `roiInvestedAmount = 1,500 × €2.00 = €3,000.00`
   - `roiGrossProfit = €3,150.00 - €3,000.00 = €150.00`

### Collection Bill Display

**Buy Section**:
- Buy: 1,500.00 Stk @ €2.00
- Buy Amount: €3,000.00
- Buy Fees: €20.12

**Sell Section**:
- Sell: 750.00 Stk @ €4.20
- Sell Amount: €3,150.00
- Sell Fees: -€20.03

**Profit Section**:
- Gross Profit: €149.91
- Return: +5.00%

---

## Key Principles

### 1. Investment Capital is Source of Truth

- **Buy amount** always comes from `Investment.amount` (capital)
- Invoice data is **not used** for buy amount/quantity calculation
- This ensures consistency with "Completed Investments" display

### 2. Quantity-Based Calculations

- **Sell quantity**: Calculated from buy quantity × sell percentage
- **Sell amount**: Calculated from sell quantity × sell price
- **Fee allocation**: Based on quantities, not values

### 3. Proportional Scaling

- **Buy fees**: Scaled by ownership percentage
- **Sell fees**: Scaled by sell share (investor sell qty / total sell qty)
- Ensures fair fee allocation

### 4. Invoice Data Usage

- **Used for**: Fee extraction, sell price calculation
- **Not used for**: Buy amount/quantity (uses investment capital)
- **Reason**: Invoice quantities may be incorrect due to earlier bugs

### 5. Rounding

- **Buy quantity**: Rounded down to 2 decimal places
- **Sell quantity**: Preserves decimal precision from calculation
- **Amounts**: Preserved to 2 decimal places (EUR)

---

## Error Handling

### Missing Data

- **No investment found**: Returns `nil` (no collection bill generated)
- **No participations**: Returns empty statement
- **No invoices**: Uses fallback calculation (may be inaccurate)
- **No sell invoices**: Sell quantity/amount = 0

### Fallback Behavior

- If `investmentCapitalAmount` is `nil` or 0:
  - Falls back to invoice-based calculation
  - Logs warning: "Using invoice data (fallback - may be incorrect)"

---

## Debugging

### Logging Points

The calculation includes extensive logging:

1. **Investment Capital**:
   ```
   💰 Investment capital (source of truth): €3,000.00
   ```

2. **Trade Capital Share**:
   ```
   💰 Trade 1 capital share: €3,000.00 (ownership: 50.00%)
   ```

3. **Buy Calculation**:
   ```
   💰 InvestorInvestmentStatementItem: Using investment capital
      💵 Investment capital: €3,000.00
      💵 Buy price: €2.00
      📊 Calculated quantity: 1,500.00
   ```

4. **Sell Calculation**:
   ```
   💰 InvestorInvestmentStatementItem: Sell calculation
      📊 Investor buy quantity: 1,500.00
      📊 Sell percentage: 50.00%
      📊 Investor sell quantity: 750.00
      💵 Sell average price: €4.20
      💵 Investor sell value (quantity × price): €3,150.00
   ```

---

## Summary

The investor collection bill calculation ensures accuracy by:

1. **Using investment capital** as the source of truth for buy amounts
2. **Calculating quantities** from capital and prices (not from potentially incorrect invoice data)
3. **Proportionally scaling** fees based on actual quantities
4. **Maintaining consistency** with the "Completed Investments" display

This approach guarantees that the collection bill accurately reflects what the investor actually invested and received, regardless of invoice data accuracy.

