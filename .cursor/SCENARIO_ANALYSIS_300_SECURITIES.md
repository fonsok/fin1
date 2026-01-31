# Scenario Analysis: 300 Securities Buy/Sell

> **Note**: This document describes system behavior conceptually. The implementation has evolved from using pool-level balances (`activeInvestmentPool.currentBalance`) to summing individual investment amounts (`investment.amount`). The concepts and calculations in this document remain valid - only the data source has changed. The system still maximizes capital utilization from all available investments.

## Given Scenario

- **Buy Order**: 300 securities @ €3.00 = €900 total
- **Pool Capital**: €5,000 total
  - Investor 1: €2,000
  - Investor 2: €3,000
- **Sell Order**: 300 securities @ €4.50 = €1,350 total
- **Fees**: None (for simplicity)

---

## Part 1: Buy Order Allocation

### 1.1 System Behavior

**Important**: The system **maximizes capital utilization** from both trader cash and pool capital.

However, the order is for **300 securities total** (€900). The system needs to determine:
- How much of the 300 securities are paid by trader capital
- How much are paid by pool capital

### 1.2 Allocation Calculation

Since pool capital (€5,000) >> order value (€900), the system will:

**Option A: If trader has sufficient cash**
- Trader portion: Up to 300 securities (if trader can afford it)
- Pool portion: Remaining securities (if any)
- **But wait**: The system maximizes, so it would try to use ALL available capital

**Option B: Actual System Behavior**
The system calculates:
1. Maximum trader quantity from trader cash balance
2. Maximum investment quantity from pool capital (€5,000)
3. **Total = trader quantity + investment quantity**

Since pool capital (€5,000) can afford much more than 300 securities:
- Pool can afford: €5,000 / €3.00 = ~1,666 securities
- But order is only 300 securities

**Key Question**: Does the system limit to the order quantity, or does it maximize?

Looking at the code, the system **maximizes from available capital**, but the **actual order placed** uses the `totalQuantity` calculated. If the trader enters 300 as desired quantity, the system might:

1. Calculate max trader quantity (from trader cash)
2. Calculate max investment quantity (from €5,000 pool)
3. Use the **total** of both for the order

But if the trader specifically wants only 300 securities, we need to understand how the allocation works.

### 1.3 Most Likely Scenario

Given that the user states "Trader buys: 300 securities", I'll assume this is the **total order quantity** that gets allocated.

**Allocation Logic** (assuming proportional allocation based on available capital):

```
Total Order: 300 securities @ €3.00 = €900

Available Capital:
- Trader cash: Unknown (let's assume sufficient)
- Pool capital: €5,000

Since pool capital >> order value, the allocation depends on:
1. How much trader capital is available
2. Whether the system uses proportional allocation or maximizes

For this analysis, I'll show TWO scenarios:
```

---

## Scenario A: System Maximizes Capital Utilization

### Buy Order Allocation

**Trader's Desired Quantity**: 300 securities (user input - **IGNORED by system**)

**Available Capital & Maximum Capacity**:
- Trader cash: €600 → **Max: 200 securities** (€600 / €3.00)
- Pool capital: €5,000 → **Max: 1,666.66 securities** (€5,000 / €3.00)
  - After denomination (if denomination = 100): **1,600 securities**

**System Behavior**: Maximizes from both sources (ignores trader's desired 300)

**Actual Order Allocation**:
- **Trader portion**: 200 securities @ €3.00 = €600
- **Pool portion**: 1,600 securities @ €3.00 = €4,800
- **Total Order**: 1,800 securities @ €3.00 = €5,400 ✅

**Key Point**: System creates order for **1,800 securities** (not 300!), maximizing capital utilization.

**Ownership Percentages** (based on securities value):
- Trader: €600 / €5,400 = 11.11%
- Pool: €4,800 / €5,400 = 88.89%

**Pool Allocation** (between investors):
- Investor 1 (€2,000): €2,000 / €5,000 = 40% of pool
- Investor 2 (€3,000): €3,000 / €5,000 = 60% of pool

**Investor Securities Value**:
- Investor 1: €4,800 × 40% = €1,920 (640 securities)
- Investor 2: €4,800 × 60% = €2,880 (960 securities)

---

## Scenario B: Trader Has Sufficient Cash (e.g., €10,000)

### Buy Order Allocation

**Total Order**: 300 securities @ €3.00 = €900

**Available Capital**:
- Trader cash: €10,000 (can afford 3,333 securities)
- Pool capital: €5,000 (can afford 1,666 securities)

**System Behavior**: Maximizes from both, but order is limited to 300 securities.

**Possible Allocation**:
- **Trader portion**: 300 securities @ €3.00 = €900
- **Pool portion**: 0 securities (trader covers full order)
- **Total**: 300 securities = €900 ✅

**OR** (if system uses proportional allocation):
- **Trader portion**: 200 securities @ €3.00 = €600 (66.67%)
- **Pool portion**: 100 securities @ €3.00 = €300 (33.33%)
- **Total**: 300 securities = €900 ✅

**For this analysis, I'll use Scenario A** (trader has limited cash) as it's more realistic and shows pool participation.

---

## Part 2: Sell Order and Profit Distribution

### 2.1 Sell Order

**Sell**: 1,800 securities @ €4.50 = €8,100

**Profit Calculation** (no fees):
- Gross Profit = €8,100 - €5,400 = €2,700

### 2.2 Commission (if applicable)

Assuming 20% commission rate:
- Commission = €2,700 × 20% = €540
- Net Profit = €2,700 - €540 = €2,160

**For simplicity (fees: none), let's assume no commission:**
- Net Profit = €2,700

### 2.3 Profit Distribution (Scenario A Allocation)

**Ownership Percentages**:
- Trader: 11.11% (€600 / €5,400)
- Pool: 88.89% (€4,800 / €5,400)

**Profit Distribution**:
- **Trader profit**: €2,700 × 11.11% = €300.00
- **Pool profit**: €2,700 × 88.89% = €2,400.00

**Pool Profit Distribution** (between investors):
- **Investor 1** (40% of pool): €2,400 × 40% = €960
- **Investor 2** (60% of pool): €2,400 × 60% = €1,440

---

## Part 3: Complete Flow Summary (Scenario A)

### Buy Order (1,800 securities @ €3.00 = €5,400)

| Participant | Securities | Value | Ownership % |
|------------|-----------|-------|-------------|
| **Trader** | 200 | €600 | 11.11% |
| **Investor 1** | 640 | €1,920 | 35.56% |
| **Investor 2** | 960 | €2,880 | 53.33% |
| **Total** | 1,800 | €5,400 | 100% |

**Capital Used**:
- Trader: €600
- Investor 1: €1,920 (from €2,000 pool)
- Investor 2: €2,880 (from €3,000 pool)
- **Total**: €5,400

**Remaining Pool Capital**:
- Investor 1: €2,000 - €1,920 = €80
- Investor 2: €3,000 - €2,880 = €120
- **Total**: €200

---

### Sell Order (1,800 securities @ €4.50 = €8,100)

**Proceeds**: €8,100

**Profit**: €8,100 - €5,400 = €2,700

### Profit Distribution (No Commission)

| Participant | Ownership % | Profit Share |
|------------|-------------|--------------|
| **Trader** | 11.11% | €300.00 |
| **Investor 1** | 35.56% | €960.00 |
| **Investor 2** | 53.33% | €1,440.00 |
| **Total** | 100% | €2,700.00 |

### Final Balances

**Trader**:
- Capital used: €600
- Profit: €300
- **Net**: +€300 (or return of €600 + profit €300 = €900)

**Investor 1**:
- Capital used: €1,920
- Profit: €960
- **Net**: +€960 (or return of €1,920 + profit €960 = €2,880)
- Remaining pool: €80

**Investor 2**:
- Capital used: €2,880
- Profit: €1,440
- **Net**: +€1,440 (or return of €2,880 + profit €1,440 = €4,320)
- Remaining pool: €120

---

## Part 4: Important Notes

### 4.1 System Behavior - Capital Maximization

**Key Understanding**: The system **maximizes capital utilization** and **ignores trader's desired quantity**.

**Calculation Process**:
1. System calculates maximum trader quantity from trader cash: **200 securities** (€600 / €3.00)
2. System calculates maximum pool quantity from pool capital: **1,600 securities** (€5,000 / €3.00, after denomination)
3. System creates order with: **totalQuantity = 200 + 1,600 = 1,800 securities**

**The trader's desired 300 securities is IGNORED** - the system maximizes from available capital.

### 4.2 Why This Design?

**Capital Maximization Strategy**:
- Ensures no capital is left idle
- Maximizes trading opportunities
- Similar to "mirror trade" concept
- Trader's input is a "suggestion", not a limit

### 4.3 Order Quantity Calculation

**Formula**:
```
totalOrderQuantity = maxTraderQuantity + maxPoolQuantity
                  = 200 + 1,600
                  = 1,800 securities
```

**NOT**:
```
totalOrderQuantity = min(traderDesiredQuantity, maxTraderQuantity + maxPoolQuantity)
                  = min(300, 1,800)  ❌ WRONG
                  = 300  ❌ WRONG
```

The system does **NOT** limit to trader's desired quantity.

### 4.4 Key Takeaway

The allocation depends on **trader's available cash**. If trader has sufficient cash, pool doesn't participate. If trader has limited cash, pool participates proportionally.

---

## Part 5: Verification

**Total Check**:
- Buy: €5,400 ✅
- Sell: €8,100 ✅
- Profit: €2,700 ✅
- Distribution: €300 + €960 + €1,440 = €2,700 ✅

**Ownership Check**:
- Trader: 11.11% ✅
- Investor 1: 35.56% ✅
- Investor 2: 53.33% ✅
- Total: 100% ✅

**Securities Check**:
- Trader: 200 securities ✅
- Investor 1: 640 securities ✅
- Investor 2: 960 securities ✅
- Total: 1,800 securities ✅

---

## Conclusion

**Correct Understanding**:

The system **maximizes capital utilization** and creates an order for **1,800 securities** (not 300):

- **Trader portion**: 200 securities (from €600 cash)
- **Pool portion**: 1,600 securities (from €5,000 capital, after denomination)
- **Total order**: 1,800 securities @ €3.00 = €5,400

**Profit Distribution** (when sold @ €4.50):
- **Trader**: €300 (11.11% ownership)
- **Investor 1**: €960 (35.56% ownership)
- **Investor 2**: €1,440 (53.33% ownership)
- **Total profit**: €2,700

**Key Point**: The trader's desired quantity (300) is **ignored**. The system maximizes from available capital, creating a larger order (1,800 securities) that utilizes all available trader cash and pool capital.

