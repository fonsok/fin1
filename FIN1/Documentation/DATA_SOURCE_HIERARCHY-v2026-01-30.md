# Data Source Hierarchy for Collection Bill Calculations

## Overview

This document defines the **authoritative data sources** for all values used in investor collection bill calculations. This hierarchy ensures consistency, prevents errors, and provides clear guidance for developers.

**Critical Principle**: Each value has exactly **one authoritative source**. All calculations must use this source, not alternatives.

---

## Data Source Hierarchy

### 1. Investment Capital (`Investment.amount`)

**Source**: `Investment` model, field `amount`
**Type**: `Double` (EUR)
**Usage**: **Source of truth for buy amount**

**Why This Source?**
- Investment capital represents the actual money the investor invested
- This is the contractual amount agreed upon
- Invoice quantities may be incorrect (from earlier bugs)
- Investment capital is immutable once set

**Example**:
```swift
let buyAmount = investment.amount  // ✅ CORRECT
// ❌ WRONG: buyInvoice?.securitiesTotal * ownershipPercentage
// ❌ WRONG: participation.allocatedAmount
```

**Calculation**:
- Buy amount = `Investment.amount` (direct use)
- Buy quantity = `floor((Investment.amount / buyPrice) * 100) / 100`

**Validation**:
- Must be > 0
- Must match sum of trade capital shares for multi-trade investments

---

### 2. Trade Entry Price (`Trade.entryPrice`)

**Source**: `Trade` model, computed property `entryPrice` (derived from `buyOrder.price`)
**Type**: `Double` (EUR per unit)
**Usage**: **Source of truth for buy price**

**Why This Source?**
- Trade entry price is the actual execution price
- This is the price at which securities were purchased
- Invoice prices may differ due to rounding or fees

**Example**:
```swift
let buyPrice = trade.entryPrice  // ✅ CORRECT
// ❌ WRONG: buyInvoice?.securitiesItems.first?.unitPrice
```

**Calculation**:
- Buy price = `trade.entryPrice`
- Used to calculate buy quantity from capital

**Validation**:
- Must be > 0
- Should match invoice price (with small tolerance for rounding)

---

### 3. Invoice Fees (`Invoice.items` where `itemType != .securities`)

**Source**: `Invoice` model, `items` array filtered by `itemType`
**Type**: `[InvoiceItem]`
**Usage**: **Source of truth for all fees (buy and sell)**

**Why This Source?**
- Fees are accurately recorded on invoices
- Invoices represent the actual transaction costs
- Fees include: order fees, exchange fees, foreign costs, etc.

**Example**:
```swift
let buyFees = buyInvoice?.items
    .filter { $0.itemType != .securities }
    .reduce(0) { $0 + $1.totalAmount } ?? 0.0  // ✅ CORRECT
```

**Calculation**:
- Buy fees = Sum of all non-securities items from buy invoice, scaled by ownership percentage
- Sell fees = Sum of all non-securities items from sell invoices, scaled by sell share

**Validation**:
- Fees should be non-negative for buy invoices
- Fees should be non-positive for sell invoices (negative values)
- Fee items must have valid `itemType`

---

### 4. Invoice Sell Prices (`Invoice.securitiesTotal` and `Invoice.securitiesItems`)

**Source**: `Invoice` model
**Type**: `Double` (EUR) and `[InvoiceItem]`
**Usage**: **Source of truth for sell prices and quantities**

**Why This Source?**
- Sell invoices contain actual execution prices
- Multiple partial sells are aggregated from all sell invoices
- Invoice data reflects the actual transaction

**Example**:
```swift
let totalSellValue = sellInvoices.reduce(0) { $0 + $1.securitiesTotal }  // ✅ CORRECT
let totalSellQty = sellInvoices.reduce(0) { total, invoice in
    total + invoice.securitiesItems.reduce(0) { $0 + $1.quantity }
}  // ✅ CORRECT
```

**Calculation**:
- Total sell value = Sum of `securitiesTotal` from all sell invoices
- Total sell quantity = Sum of `quantity` from all `securitiesItems` in sell invoices
- Average sell price = `totalSellValue / totalSellQty` (if totalSellQty > 0)

**Validation**:
- Sell quantity must be > 0 if there are sell invoices
- Average sell price should be > 0
- Sell quantity should not exceed buy quantity

---

### 5. Trade Total Quantity (`Trade.totalQuantity`)

**Source**: `Trade` model, computed property `totalQuantity` (derived from `buyOrder.quantity`)
**Type**: `Double`
**Usage**: **Reference for sell percentage calculation**

**Why This Source?**
- Trade total quantity represents the total securities purchased
- Used to calculate what percentage was sold
- Not used directly for investor calculations, but as a reference

**Example**:
```swift
let sellPercentage = trade.totalQuantity > 0
    ? (totalSellQtyFromInvoices / trade.totalQuantity)
    : 0.0  // ✅ CORRECT
```

**Calculation**:
- Sell percentage = `totalSellQtyFromInvoices / trade.totalQuantity`
- Investor sell quantity = `investorBuyQty * sellPercentage`

**Validation**:
- Must be > 0
- Should match sum of invoice quantities (with tolerance)

---

### 6. Ownership Percentage (`PotTradeParticipation.ownershipPercentage`)

**Source**: `PotTradeParticipation` model, field `ownershipPercentage`
**Type**: `Double` (0.0 to 1.0)
**Usage**: **Scaling factor for investor's share**

**Why This Source?**
- Ownership percentage defines investor's share of the trade
- Used to scale fees and quantities proportionally
- Determines how much of the trade belongs to the investor

**Example**:
```swift
let investorBuyFees = totalBuyFees * participation.ownershipPercentage  // ✅ CORRECT
```

**Calculation**:
- Buy fees = Total buy fees × ownership percentage
- Sell fees = Total sell fees × sell share (where sell share = investor sell qty / total sell qty)

**Validation**:
- Must be between 0.0 and 1.0
- Sum of ownership percentages for all participations in a trade should be ≤ 1.0

---

## Data Flow Diagram

```
Investment.amount (CAPITAL)
    ↓
    ├─→ Buy Amount (direct use)
    └─→ Buy Quantity = capital / buyPrice

Trade.entryPrice
    ↓
    └─→ Buy Price (direct use)

Trade.totalQuantity
    ↓
    └─→ Reference for sell percentage calculation

Invoice (buy)
    ↓
    ├─→ Buy Fees (from non-securities items)
    └─→ Reference only (quantities may be wrong)

Invoice (sell)
    ↓
    ├─→ Sell Prices (from securitiesTotal)
    ├─→ Sell Quantities (from securitiesItems)
    └─→ Sell Fees (from non-securities items)

PotTradeParticipation.ownershipPercentage
    ↓
    └─→ Scaling factor for all investor calculations
```

---

## Calculation Rules

### Buy Leg

1. **Buy Amount**: Use `Investment.amount` directly
2. **Buy Quantity**: Calculate from capital: `floor((Investment.amount / Trade.entryPrice) * 100) / 100`
3. **Buy Price**: Use `Trade.entryPrice` directly
4. **Buy Fees**: Sum of non-securities items from buy invoice, scaled by ownership percentage

### Sell Leg

1. **Sell Quantity**: Calculate from buy quantity and sell percentage:
   - `sellPercentage = totalSellQtyFromInvoices / trade.totalQuantity`
   - `investorSellQty = investorBuyQty * sellPercentage`
2. **Sell Price**: Calculate average from sell invoices:
   - `averageSellPrice = totalSellValueFromInvoices / totalSellQtyFromInvoices`
3. **Sell Amount**: Calculate from quantity and price:
   - `investorSellAmount = investorSellQty * averageSellPrice`
4. **Sell Fees**: Sum of non-securities items from sell invoices, scaled by sell share:
   - `sellShare = investorSellQty / totalSellQtyFromInvoices`
   - `investorSellFees = totalSellFees * sellShare`

### Profit Calculations

1. **Gross Profit**: `sellAmount + sellFees - (buyAmount + buyFees)`
   - Note: Sell fees are negative (deductions), so adding them subtracts them
   - Formula: `(sellAmount + sellFees) - (buyAmount + buyFees)`
2. **ROI Gross Profit**: `sellAmount - (buyQuantity * buyPrice)`
3. **ROI Invested Amount**: `buyQuantity * buyPrice`

---

## Common Mistakes to Avoid

### ❌ WRONG: Using Invoice for Buy Amount

```swift
// ❌ WRONG - Invoice quantities may be incorrect
let buyTotal = (buyInvoice?.securitiesTotal ?? 0.0) * ownershipPercentage
```

**Why Wrong?**
- Invoice quantities were incorrect due to earlier bugs
- Investment capital is the actual amount invested
- Invoice represents securities value, not capital

### ❌ WRONG: Using Allocated Amount for Buy Amount

```swift
// ❌ WRONG - Allocated amount is securities value, not capital
let buyTotal = participation.allocatedAmount
```

**Why Wrong?**
- `allocatedAmount` represents securities value, not investment capital
- This doesn't account for fees
- Investment capital is the source of truth

### ❌ WRONG: Using Trade Quantity for Investor Quantity

```swift
// ❌ WRONG - This is total trade quantity, not investor's share
let investorBuyQty = trade.totalQuantity * ownershipPercentage
```

**Why Wrong?**
- Trade quantity may not match actual investment capital
- Should calculate from capital: `capital / buyPrice`
- Ensures displayed quantity matches investment amount

### ❌ WRONG: Using Scaled Invoice Value for Sell Amount

```swift
// ❌ WRONG - Doesn't match displayed quantity
let investorSellValue = totalSellValueFromInvoices * ownershipPercentage
```

**Why Wrong?**
- Doesn't match the displayed sell quantity
- Should use: `investorSellQty * sellAvgPrice`
- Ensures consistency between quantity and value

---

## Validation Checklist

When implementing collection bill calculations, verify:

- [ ] Buy amount uses `Investment.amount` (not invoice or allocated amount)
- [ ] Buy price uses `Trade.entryPrice` (not invoice price)
- [ ] Buy quantity calculated from capital: `capital / buyPrice`
- [ ] Buy fees from invoice non-securities items, scaled by ownership
- [ ] Sell quantity calculated from buy quantity and sell percentage
- [ ] Sell price calculated as average from sell invoices
- [ ] Sell amount = `sellQuantity * sellPrice` (not scaled invoice value)
- [ ] Sell fees from invoice non-securities items, scaled by sell share
- [ ] All values validated (positive where expected, ranges correct)

---

## Implementation Reference

The data source hierarchy is enforced in:
- **Service**: `InvestorCollectionBillCalculationService`
- **Protocol**: `InvestorCollectionBillCalculationServiceProtocol`
- **DTOs**: `InvestorCollectionBillInput`, `InvestorCollectionBillOutput`

All calculations should go through the service to ensure consistency.

---

## Historical Context

**Previous Issues**:
- Invoice quantities were incorrect (from order placement bug)
- Previous code used invoice as "source of truth" (incorrect)
- Multiple calculation paths led to inconsistencies

**Current Solution**:
- Investment capital is the authoritative source for buy amount
- All calculations go through dedicated service
- Clear data source hierarchy documented and enforced

---

## Maintenance

**When to Update This Document**:
- If data model changes affect source of truth
- If new calculation requirements are added
- If validation rules change
- If new data sources are introduced

**Review Frequency**: Quarterly or when calculation issues arise

---

## Related Documentation

- `ARCHITECTURE_ANALYSIS_COLLECTION_BILL_COMPLEXITY.md` - Analysis of why calculations were difficult
- `INVESTOR_COLLECTION_BILL_CALCULATION_DETAILED.md` - Detailed calculation flow
- `InvestorCollectionBillCalculationService.swift` - Service implementation

