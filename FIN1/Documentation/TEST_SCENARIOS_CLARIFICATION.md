# Test Scenarios Clarification for Collection Bill Calculation

## Understanding the Relationships

### Investment ↔ Trade Relationship

**Key Point**:
- **1 Investment** can participate in **1 or more Trades** (via `PotTradeParticipation`)
- **1 Trade** can have **1 or more Investments** participating in it

**Important Distinction**:
- The calculation service operates at the **Investment level**
- It calculates values for **one investment** across **one or more trades**

---

## Test Scenarios for Unit Tests

### Scenario 1: Single Trade, Single Investment
**Description**: One investment participates in exactly one trade

**Setup**:
- Investment capital: €3,000
- 1 `PotTradeParticipation` linking investment to 1 trade
- Ownership percentage: 50% (investment owns 50% of the trade)

**What to Test**:
- Full investment capital (€3,000) is used for this trade
- No capital distribution needed
- Buy amount = investment capital
- Buy quantity calculated from capital / buy price

**Code Reference**:
```swift
if participations.count == 1 {
    // Single trade: use full investment capital
    tradeCapitalShare = totalInvestmentCapital
}
```

---

### Scenario 2: Multiple Trades, Single Investment
**Description**: One investment participates in multiple trades (capital needs distribution)

**Setup**:
- Investment capital: €4,333.33
- 2 `PotTradeParticipation` records:
  - Participation 1: Trade A, ownership 50%
  - Participation 2: Trade B, ownership 50%

**What to Test**:
- Investment capital is **distributed** across trades proportionally
- Trade A gets: €4,333.33 × (0.5 / 1.0) = €2,166.67
- Trade B gets: €4,333.33 × (0.5 / 1.0) = €2,166.66
- Total distributed = original capital
- Each trade's calculation uses its allocated capital share

**Code Reference**:
```swift
if participations.count > 1 {
    // Multiple trades: distribute capital proportionally
    let totalOwnership = participations.reduce(0.0) { $0 + $1.ownershipPercentage }
    tradeCapitalShare = totalOwnership > 0
        ? (totalInvestmentCapital * participation.ownershipPercentage / totalOwnership)
        : (totalInvestmentCapital / Double(participations.count))
}
```

**Test Cases**:
- Equal ownership percentages (50% / 50%)
- Unequal ownership percentages (30% / 70%)
- Three or more trades
- Ownership percentages that don't sum to 1.0

---

### Scenario 3: Partial Sells
**Description**: A trade where securities are sold in multiple transactions (multiple sell invoices)

**Setup**:
- Investment capital: €3,000
- Buy: 1,500 Stk @ €2.00 = €3,000
- Sell invoices:
  - Invoice 1: 500 Stk @ €4.00 = €2,000
  - Invoice 2: 1,000 Stk @ €4.20 = €4,200

**What to Test**:
- Total sell quantity: 1,500 Stk (sum of all sell invoices)
- Total sell value: €6,200 (sum of all sell invoice securitiesTotal)
- Average sell price: €6,200 / 1,500 = €4.133...
- Investor sell quantity: 1,500 Stk × sell percentage
- Investor sell amount: investor sell qty × average sell price
- Fees from all sell invoices aggregated and scaled

**Code Reference**:
```swift
let totalSellQtyFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
    total + invoice.securitiesItems.reduce(0.0) { $0 + $1.quantity }
}
let totalSellValueFromInvoices = sellInvoices.reduce(0.0) { total, invoice in
    total + invoice.securitiesTotal
}
let sellAvgPrice = totalSellQtyFromInvoices > 0
    ? totalSellValueFromInvoices / totalSellQtyFromInvoices
    : 0.0
```

**Test Cases**:
- Two partial sells
- Three or more partial sells
- Partial sells with different prices
- Partial sells with different fee structures

---

### Scenario 4: Single Trade, Multiple Investments
**Description**: Multiple investments participate in the same trade (different ownership percentages)

**Note**: This scenario is **NOT directly tested** by the calculation service because:
- The service calculates for **one investment at a time**
- Each investment's calculation is independent
- The service receives the investment's capital share as input

**However**, we should test:
- Different ownership percentages (10%, 50%, 90%)
- That calculations scale correctly by ownership
- That fees are allocated proportionally

---

## Test Structure

### Unit Test Organization

```swift
class InvestorCollectionBillCalculationServiceTests: XCTestCase {

    // MARK: - Scenario 1: Single Trade
    func testSingleTradeFullCapital() { }
    func testSingleTradeWithFees() { }
    func testSingleTradeCompleteSell() { }

    // MARK: - Scenario 2: Multiple Trades
    func testMultipleTradesEqualOwnership() { }
    func testMultipleTradesUnequalOwnership() { }
    func testMultipleTradesThreeTrades() { }
    func testMultipleTradesCapitalDistribution() { }

    // MARK: - Scenario 3: Partial Sells
    func testPartialSellTwoInvoices() { }
    func testPartialSellThreeInvoices() { }
    func testPartialSellDifferentPrices() { }
    func testPartialSellFeeAllocation() { }

    // MARK: - Edge Cases
    func testZeroFees() { }
    func testZeroSellQuantity() { }
    func testBoundaryOwnershipPercentages() { }
    func testValidationErrors() { }
}
```

---

## Key Test Assertions

### For Single Trade:
- ✅ Buy amount = investment capital
- ✅ Buy quantity = floor((capital / buyPrice) * 100) / 100
- ✅ Buy fees = total buy fees × ownership percentage
- ✅ Sell quantity = buy quantity × sell percentage
- ✅ Sell amount = sell quantity × average sell price
- ✅ Gross profit = sell amount - sell fees - (buy amount + buy fees)

### For Multiple Trades:
- ✅ Capital distribution sums to original investment capital
- ✅ Each trade gets proportional capital share
- ✅ Calculations use allocated capital share, not full capital
- ✅ Total of all trade calculations = investment capital

### For Partial Sells:
- ✅ Total sell quantity = sum of all sell invoice quantities
- ✅ Average sell price = total sell value / total sell quantity
- ✅ Sell fees aggregated from all sell invoices
- ✅ Sell share calculated correctly for fee allocation

---

## Important Notes

1. **The calculation service operates per trade participation**
   - Each call to `calculateCollectionBill()` handles ONE trade
   - The ViewModel/Aggregator handles multiple trades by calling the service multiple times

2. **Capital distribution happens BEFORE the service**
   - The service receives `investmentCapital` as input
   - This is already the trade's share of capital (if multiple trades)
   - The service doesn't need to know about other trades

3. **Multiple investments in one trade**
   - Each investment is calculated independently
   - Each has its own ownership percentage
   - The service doesn't need to know about other investments

---

## Summary

**Test Scenarios**:
1. ✅ **Single Trade**: Investment participates in 1 trade (full capital used)
2. ✅ **Multiple Trades**: Investment participates in 2+ trades (capital distributed)
3. ✅ **Partial Sells**: Trade has multiple sell invoices (aggregated)
4. ℹ️ **Multiple Investments**: Not directly tested (service is per-investment)

**Focus Areas**:
- Capital distribution logic (multiple trades scenario)
- Partial sell aggregation (multiple sell invoices)
- Fee allocation and scaling
- Edge cases and validation

















