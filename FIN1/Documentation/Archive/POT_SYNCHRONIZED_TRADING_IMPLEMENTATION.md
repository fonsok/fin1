# Pot-Synchronized Trading & Pro-Rata Profit Distribution Implementation Guide

## Overview

This document outlines the implementation strategy for enabling traders to execute buy orders that automatically trigger proportional purchases across all active investor pots, with pro-rata profit distribution upon trade completion.

## Key Requirement: Quantity Calculation

**Critical Detail**: When a trader places a buy order (e.g., 1000 pieces @ €2), the system must:
1. Check if an active pot exists (trader only sees "pot is active", not the balance)
2. Calculate the **exact maximum purchasable quantity** based on pot balance and fees
3. Execute that calculated quantity on the stock exchange (not the trader's desired quantity)

**Example:**
- Trader wants: 1000 pieces @ €2 = €2,000
- Pot balance: €15,321
- After fees calculation: **7,624 pieces** can be purchased
- System executes: **7,624 pieces** (not 1000)

See `POT_QUANTITY_CALCULATION_IMPLEMENTATION.md` for detailed quantity calculation logic.

## Architecture Decision

**Recommended Approach**: Backend-driven with frontend coordination

- **Frontend**: Initiates order, displays pot participation, shows profit distribution
- **Backend**: Handles pot calculations, order distribution, profit allocation, data persistence
- **Database**: Tracks pot-trade relationships, ownership shares, profit distributions

## Database Schema Design

### New Collections/Tables

#### 1. `PotTradeParticipation`
Links pots to trades and tracks ownership shares.

```sql
CREATE TABLE PotTradeParticipation (
    id VARCHAR PRIMARY KEY,
    potId VARCHAR NOT NULL,              -- References InvestmentPool.id
    tradeId VARCHAR NOT NULL,            -- References Trade.id
    traderId VARCHAR NOT NULL,           -- References User.id (trader)
    potBalanceAtTradeStart DECIMAL,      -- Pot balance when trade was initiated
    totalPotBalance DECIMAL,             -- Sum of all pot balances for this trader
    ownershipPercentage DECIMAL,        -- potBalanceAtTradeStart / totalPotBalance
    allocatedQuantity DECIMAL,          -- Quantity of securities allocated to this pot
    allocatedCost DECIMAL,              -- Cost basis for this pot's share
    profitShare DECIMAL DEFAULT 0,      -- Profit allocated to this pot (calculated on sell)
    createdAt TIMESTAMP,
    updatedAt TIMESTAMP,

    INDEX idx_potId (potId),
    INDEX idx_tradeId (tradeId),
    INDEX idx_traderId (traderId)
);
```

#### 2. `InvestorTradeAllocation`
Tracks individual investor shares within a pot for a specific trade.

```sql
CREATE TABLE InvestorTradeAllocation (
    id VARCHAR PRIMARY KEY,
    investorId VARCHAR NOT NULL,        -- References User.id (investor)
    potId VARCHAR NOT NULL,             -- References InvestmentPool.id
    tradeId VARCHAR NOT NULL,           -- References Trade.id
    investmentAmount DECIMAL,           -- Investor's contribution to this pot
    potOwnershipPercentage DECIMAL,    -- investmentAmount / potBalanceAtTradeStart
    tradeOwnershipPercentage DECIMAL,   -- Final ownership % in the trade
    allocatedQuantity DECIMAL,          -- Quantity of securities for this investor
    allocatedCost DECIMAL,              -- Cost basis for this investor
    profitShare DECIMAL DEFAULT 0,     -- Profit allocated to this investor
    createdAt TIMESTAMP,
    updatedAt TIMESTAMP,

    INDEX idx_investorId (investorId),
    INDEX idx_potId (potId),
    INDEX idx_tradeId (tradeId)
);
```

#### 3. `TraderTradeAllocation`
Tracks trader's own share in the trade (from trader's capital, not pots).

```sql
CREATE TABLE TraderTradeAllocation (
    id VARCHAR PRIMARY KEY,
    traderId VARCHAR NOT NULL,          -- References User.id (trader)
    tradeId VARCHAR NOT NULL,           -- References Trade.id
    traderCapital DECIMAL,              -- Trader's own capital in this trade
    totalTradeValue DECIMAL,            -- Total value of the trade
    ownershipPercentage DECIMAL,       -- traderCapital / totalTradeValue
    allocatedQuantity DECIMAL,          -- Quantity of securities for trader
    allocatedCost DECIMAL,              -- Cost basis for trader
    profitShare DECIMAL DEFAULT 0,      -- Profit allocated to trader
    createdAt TIMESTAMP,
    updatedAt TIMESTAMP,

    INDEX idx_traderId (traderId),
    INDEX idx_tradeId (tradeId)
);
```

### Updated Collections

#### `InvestmentPool` (Add fields)
```sql
ALTER TABLE InvestmentPool ADD COLUMN activeTradeId VARCHAR;  -- Current active trade
ALTER TABLE InvestmentPool ADD COLUMN totalProfit DECIMAL DEFAULT 0;
ALTER TABLE InvestmentPool ADD COLUMN totalLoss DECIMAL DEFAULT 0;
```

#### `Trade` (Add fields)
```sql
ALTER TABLE Trade ADD COLUMN totalPotBalance DECIMAL;  -- Sum of all pot balances
ALTER TABLE Trade ADD COLUMN traderCapital DECIMAL;    -- Trader's own capital
ALTER TABLE Trade ADD COLUMN totalTradeValue DECIMAL;  -- totalPotBalance + traderCapital
ALTER TABLE Trade ADD COLUMN isPotSynchronized BOOLEAN DEFAULT FALSE;
```

## Backend Implementation

### 1. Parse Server Cloud Functions

#### `placeBuyOrderWithPotSync`
Main entry point for synchronized pot trading.

```javascript
Parse.Cloud.define("placeBuyOrderWithPotSync", async (request) => {
  const { traderId, symbol, quantity, price, description, optionDirection, strike, orderInstruction, limitPrice } = request.params;

  // 1. Get all active pots for this trader
  const activePots = await getActivePotsForTrader(traderId);

  // 2. Calculate total pot balance
  const totalPotBalance = activePots.reduce((sum, pot) => sum + pot.currentBalance, 0);

  // 3. Get trader's own capital (from trader's account balance)
  const traderCapital = await getTraderCapital(traderId);

  // 4. Calculate total trade value
  const totalTradeValue = totalPotBalance + traderCapital;

  // 5. Create main buy order
  const buyOrder = await createBuyOrder({
    traderId,
    symbol,
    quantity,
    price,
    description,
    optionDirection,
    strike,
    orderInstruction,
    limitPrice,
    totalTradeValue,
    totalPotBalance,
    traderCapital
  });

  // 6. Create pot trade participations
  const potParticipations = await createPotTradeParticipations(
    activePots,
    buyOrder.id,
    traderId,
    totalPotBalance,
    quantity,
    price
  );

  // 7. Create trader trade allocation
  if (traderCapital > 0) {
    await createTraderTradeAllocation(
      traderId,
      buyOrder.id,
      traderCapital,
      totalTradeValue,
      quantity,
      price
    );
  }

  // 8. Create investor trade allocations
  await createInvestorTradeAllocations(
    activePots,
    buyOrder.id,
    potParticipations
  );

  return {
    success: true,
    buyOrderId: buyOrder.id,
    potCount: activePots.length,
    totalPotBalance,
    traderCapital,
    totalTradeValue
  };
});

async function getActivePotsForTrader(traderId) {
  const Pot = Parse.Object.extend("InvestmentPool");
  const query = new Parse.Query(Pot);
  query.equalTo("traderId", traderId);
  query.equalTo("status", "active");
  query.greaterThan("currentBalance", 0);
  return await query.find();
}

async function createPotTradeParticipations(pots, tradeId, traderId, totalPotBalance, totalQuantity, price) {
  const participations = [];

  for (const pot of pots) {
    const ownershipPercentage = pot.currentBalance / totalPotBalance;
    const allocatedQuantity = totalQuantity * ownershipPercentage;
    const allocatedCost = allocatedQuantity * price;

    const participation = new Parse.Object("PotTradeParticipation");
    participation.set("potId", pot.id);
    participation.set("tradeId", tradeId);
    participation.set("traderId", traderId);
    participation.set("potBalanceAtTradeStart", pot.currentBalance);
    participation.set("totalPotBalance", totalPotBalance);
    participation.set("ownershipPercentage", ownershipPercentage);
    participation.set("allocatedQuantity", allocatedQuantity);
    participation.set("allocatedCost", allocatedCost);
    participation.set("profitShare", 0);
    participation.set("createdAt", new Date());
    participation.set("updatedAt", new Date());

    await participation.save();
    participations.push(participation);

    // Update pot with active trade
    pot.set("activeTradeId", tradeId);
    await pot.save();
  }

  return participations;
}

async function createInvestorTradeAllocations(pots, tradeId, potParticipations) {
  const allocations = [];

  for (let i = 0; i < pots.length; i++) {
    const pot = pots[i];
    const participation = potParticipations[i];

    // Get all investments in this pot
    const investments = await getInvestmentsForPot(pot.id);

    for (const investment of investments) {
      const potOwnershipPercentage = investment.amount / pot.currentBalance;
      const tradeOwnershipPercentage = potOwnershipPercentage * participation.get("ownershipPercentage");
      const allocatedQuantity = participation.get("allocatedQuantity") * potOwnershipPercentage;
      const allocatedCost = participation.get("allocatedCost") * potOwnershipPercentage;

      const allocation = new Parse.Object("InvestorTradeAllocation");
      allocation.set("investorId", investment.investorId);
      allocation.set("potId", pot.id);
      allocation.set("tradeId", tradeId);
      allocation.set("investmentAmount", investment.amount);
      allocation.set("potOwnershipPercentage", potOwnershipPercentage);
      allocation.set("tradeOwnershipPercentage", tradeOwnershipPercentage);
      allocation.set("allocatedQuantity", allocatedQuantity);
      allocation.set("allocatedCost", allocatedCost);
      allocation.set("profitShare", 0);
      allocation.set("createdAt", new Date());
      allocation.set("updatedAt", new Date());

      await allocation.save();
      allocations.push(allocation);
    }
  }

  return allocations;
}
```

#### `distributeTradeProfit`
Distributes profit when trade completes (sell order executed).

```javascript
Parse.Cloud.define("distributeTradeProfit", async (request) => {
  const { tradeId } = request.params;

  // 1. Get trade and calculate total profit
  const trade = await getTrade(tradeId);
  const totalProfit = calculateTradeProfit(trade);

  // 2. Get all pot participations
  const potParticipations = await getPotTradeParticipations(tradeId);

  // 3. Distribute profit to pots (pro-rata)
  for (const participation of potParticipations) {
    const potProfit = totalProfit * participation.get("ownershipPercentage");
    participation.set("profitShare", potProfit);
    participation.set("updatedAt", new Date());
    await participation.save();

    // Update pot balance
    await updatePotBalance(participation.get("potId"), potProfit);
  }

  // 4. Distribute profit to trader
  const traderAllocation = await getTraderTradeAllocation(tradeId);
  if (traderAllocation) {
    const traderProfit = totalProfit * traderAllocation.get("ownershipPercentage");
    traderAllocation.set("profitShare", traderProfit);
    traderAllocation.set("updatedAt", new Date());
    await traderAllocation.save();

    // Update trader's account balance
    await updateTraderBalance(traderAllocation.get("traderId"), traderProfit);
  }

  // 5. Distribute profit to individual investors
  const investorAllocations = await getInvestorTradeAllocations(tradeId);
  for (const allocation of investorAllocations) {
    const potParticipation = potParticipations.find(
      p => p.get("potId") === allocation.get("potId")
    );
    const potProfit = totalProfit * potParticipation.get("ownershipPercentage");
    const investorProfit = potProfit * allocation.get("potOwnershipPercentage");

    allocation.set("profitShare", investorProfit);
    allocation.set("updatedAt", new Date());
    await allocation.save();

    // Update investor's account balance
    await updateInvestorBalance(allocation.get("investorId"), investorProfit);
  }

  return {
    success: true,
    totalProfit,
    potCount: potParticipations.length,
    investorCount: investorAllocations.length
  };
});

function calculateTradeProfit(trade) {
  const buyCost = trade.buyOrder.price * trade.buyOrder.quantity;
  const sellProceeds = trade.sellOrders.reduce(
    (sum, order) => sum + (order.price * order.quantity),
    0
  );
  const fees = calculateTotalFees(trade);
  return sellProceeds - buyCost - fees;
}
```

### 2. REST API Endpoints

```javascript
// POST /api/trades/place-buy-order-with-pots
app.post('/api/trades/place-buy-order-with-pots', async (req, res) => {
  try {
    const result = await Parse.Cloud.run('placeBuyOrderWithPotSync', req.body);
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// POST /api/trades/:tradeId/distribute-profit
app.post('/api/trades/:tradeId/distribute-profit', async (req, res) => {
  try {
    const result = await Parse.Cloud.run('distributeTradeProfit', {
      tradeId: req.params.tradeId
    });
    res.json(result);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/trades/:tradeId/pot-participations
app.get('/api/trades/:tradeId/pot-participations', async (req, res) => {
  try {
    const participations = await getPotTradeParticipations(req.params.tradeId);
    res.json(participations);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GET /api/investors/:investorId/trade-allocations
app.get('/api/investors/:investorId/trade-allocations', async (req, res) => {
  try {
    const allocations = await getInvestorTradeAllocationsByInvestor(req.params.investorId);
    res.json(allocations);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});
```

## Frontend Implementation (SwiftUI)

### 1. New Models

```swift
// FIN1/Features/Trader/Models/PotTradeParticipation.swift
struct PotTradeParticipation: Identifiable, Codable {
    let id: String
    let potId: String
    let tradeId: String
    let traderId: String
    let potBalanceAtTradeStart: Double
    let totalPotBalance: Double
    let ownershipPercentage: Double
    let allocatedQuantity: Double
    let allocatedCost: Double
    let profitShare: Double
    let createdAt: Date
    let updatedAt: Date
}

// FIN1/Features/Investor/Models/InvestorTradeAllocation.swift
struct InvestorTradeAllocation: Identifiable, Codable {
    let id: String
    let investorId: String
    let potId: String
    let tradeId: String
    let investmentAmount: Double
    let potOwnershipPercentage: Double
    let tradeOwnershipPercentage: Double
    let allocatedQuantity: Double
    let allocatedCost: Double
    let profitShare: Double
    let createdAt: Date
    let updatedAt: Date
}
```

### 2. Service Layer

```swift
// FIN1/Features/Trader/Services/PotSynchronizedTradingService.swift
protocol PotSynchronizedTradingServiceProtocol {
    func placeBuyOrderWithPotSync(
        symbol: String,
        quantity: Int,
        price: Double,
        optionDirection: String?,
        description: String?,
        orderInstruction: String?,
        limitPrice: Double?,
        strike: Double?
    ) async throws -> PotSynchronizedOrderResult

    func getPotParticipations(for tradeId: String) async throws -> [PotTradeParticipation]
    func distributeTradeProfit(for tradeId: String) async throws -> ProfitDistributionResult
}

struct PotSynchronizedOrderResult: Codable {
    let buyOrderId: String
    let potCount: Int
    let totalPotBalance: Double
    let traderCapital: Double
    let totalTradeValue: Double
}

struct ProfitDistributionResult: Codable {
    let totalProfit: Double
    let potCount: Int
    let investorCount: Int
}

final class PotSynchronizedTradingService: PotSynchronizedTradingServiceProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func placeBuyOrderWithPotSync(
        symbol: String,
        quantity: Int,
        price: Double,
        optionDirection: String?,
        description: String?,
        orderInstruction: String?,
        limitPrice: Double?,
        strike: Double?
    ) async throws -> PotSynchronizedOrderResult {
        let request = PotSynchronizedBuyOrderRequest(
            symbol: symbol,
            quantity: quantity,
            price: price,
            optionDirection: optionDirection,
            description: description,
            orderInstruction: orderInstruction,
            limitPrice: limitPrice,
            strike: strike
        )

        return try await apiClient.post(
            "/api/trades/place-buy-order-with-pots",
            body: request,
            responseType: PotSynchronizedOrderResult.self
        )
    }

    func getPotParticipations(for tradeId: String) async throws -> [PotTradeParticipation] {
        return try await apiClient.get(
            "/api/trades/\(tradeId)/pot-participations",
            responseType: [PotTradeParticipation].self
        )
    }

    func distributeTradeProfit(for tradeId: String) async throws -> ProfitDistributionResult {
        return try await apiClient.post(
            "/api/trades/\(tradeId)/distribute-profit",
            body: EmptyBody(),
            responseType: ProfitDistributionResult.self
        )
    }
}
```

### 3. ViewModel Updates

```swift
// Update FIN1/Features/Trader/ViewModels/BuyOrderViewModel.swift
final class BuyOrderViewModel: ObservableObject {
    @Published var potParticipationInfo: PotParticipationInfo?
    @Published var showPotParticipation = false

    private let potSynchronizedTradingService: PotSynchronizedTradingServiceProtocol

    func placeOrder() async {
        orderStatus = .transmitting

        do {
            // ... existing validation ...

            // Place order with pot synchronization
            let result = try await potSynchronizedTradingService.placeBuyOrderWithPotSync(
                symbol: searchResult.wkn,
                quantity: Int(quantity),
                price: executedPrice,
                optionDirection: searchResult.direction,
                description: searchResult.underlyingAsset,
                orderInstruction: orderMode.rawValue,
                limitPrice: orderMode == .limit ? Double(limit.replacingOccurrences(of: ",", with: ".")) : nil,
                strike: Double(searchResult.strike.replacingOccurrences(of: ",", with: "."))
            )

            // Update UI with pot participation info
            potParticipationInfo = PotParticipationInfo(
                potCount: result.potCount,
                totalPotBalance: result.totalPotBalance,
                traderCapital: result.traderCapital,
                totalTradeValue: result.totalTradeValue
            )
            showPotParticipation = true

            orderStatus = .success
        } catch {
            orderStatus = .failed(error)
        }
    }
}

struct PotParticipationInfo {
    let potCount: Int
    let totalPotBalance: Double
    let traderCapital: Double
    let totalTradeValue: Double
}
```

### 4. UI Components

```swift
// FIN1/Features/Trader/Views/Components/PotParticipationView.swift
struct PotParticipationView: View {
    let participationInfo: PotParticipationInfo

    var body: some View {
        VStack(alignment: .leading, spacing: ResponsiveDesign.spacing(2)) {
            Text("Pot Participation")
                .font(ResponsiveDesign.headlineFont())

            HStack {
                Text("Active Pots:")
                Spacer()
                Text("\(participationInfo.potCount)")
            }

            HStack {
                Text("Total Pot Balance:")
                Spacer()
                Text(participationInfo.totalPotBalance.formattedAsCurrency)
            }

            HStack {
                Text("Trader Capital:")
                Spacer()
                Text(participationInfo.traderCapital.formattedAsCurrency)
            }

            HStack {
                Text("Total Trade Value:")
                Spacer()
                Text(participationInfo.totalTradeValue.formattedAsCurrency)
                    .font(ResponsiveDesign.headlineFont())
            }
        }
        .responsivePadding()
    }
}
```

### 5. Trade Completion Handler

```swift
// Update FIN1/Features/Trader/Services/OrderLifecycleCoordinator.swift
private func handleSellOrderCompletion(orderId: String, order: Order) async {
    // ... existing code ...

    // When trade completes, distribute profit
    if let trade = matchingTrade, trade.isCompleted {
        do {
            let distributionResult = try await potSynchronizedTradingService.distributeTradeProfit(
                for: trade.id
            )

            // Notify investors of profit distribution
            await tradingNotificationService.notifyProfitDistribution(
                tradeId: trade.id,
                totalProfit: distributionResult.totalProfit,
                investorCount: distributionResult.investorCount
            )
        } catch {
            print("Error distributing profit: \(error)")
        }
    }
}
```

## Pro-Rata Calculation Logic

### Formula

```
For each pot:
  potOwnershipPercentage = potBalance / totalPotBalance

For each investor in a pot:
  investorPotOwnershipPercentage = investorAmount / potBalance
  investorTradeOwnershipPercentage = investorPotOwnershipPercentage * potOwnershipPercentage

For trader:
  traderOwnershipPercentage = traderCapital / (totalPotBalance + traderCapital)

On profit distribution:
  potProfit = totalProfit * potOwnershipPercentage
  investorProfit = potProfit * investorPotOwnershipPercentage
  traderProfit = totalProfit * traderOwnershipPercentage
```

### Example Calculation

**Scenario:**
- Trader places buy order: 100 shares @ €10 = €1,000
- Pot 1: €500 (Investor A: €300, Investor B: €200)
- Pot 2: €300 (Investor C: €300)
- Trader Capital: €200
- Total: €1,000

**Ownership:**
- Pot 1: 50% (€500 / €1,000)
- Pot 2: 30% (€300 / €1,000)
- Trader: 20% (€200 / €1,000)

**Allocation:**
- Pot 1: 50 shares (Investor A: 30, Investor B: 20)
- Pot 2: 30 shares (Investor C: 30)
- Trader: 20 shares

**Profit Distribution (if trade sells at €12, profit = €200):**
- Pot 1: €100 (Investor A: €60, Investor B: €40)
- Pot 2: €60 (Investor C: €60)
- Trader: €40

## Testing Strategy

### Unit Tests
1. Pro-rata calculation accuracy
2. Pot participation creation
3. Investor allocation calculation
4. Profit distribution logic

### Integration Tests
1. End-to-end order placement with pot sync
2. Trade completion and profit distribution
3. Multiple pots with varying balances
4. Edge cases (empty pots, zero trader capital)

### UI Tests
1. Pot participation display
2. Profit distribution notifications
3. Investor profit view updates

## Migration Strategy

1. **Phase 1**: Add database schema (non-breaking)
2. **Phase 2**: Implement backend services (parallel to existing)
3. **Phase 3**: Update frontend to use new services (feature flag)
4. **Phase 4**: Migrate existing trades (if needed)
5. **Phase 5**: Enable for all traders (remove feature flag)

## Security Considerations

1. **Authorization**: Verify trader owns pots before linking
2. **Validation**: Ensure pot balances are sufficient
3. **Atomicity**: Use database transactions for order placement
4. **Audit Trail**: Log all pot-trade linkages and profit distributions
5. **Rate Limiting**: Prevent excessive order placement

## Performance Optimization

1. **Caching**: Cache active pots for trader
2. **Batch Operations**: Batch database writes for participations
3. **Async Processing**: Process profit distribution asynchronously
4. **Indexing**: Ensure proper database indexes on foreign keys

## Error Handling

1. **Insufficient Pot Balance**: Reject order or allow partial participation
2. **Pot Closure During Order**: Handle gracefully with rollback
3. **Network Failures**: Implement retry logic with idempotency
4. **Calculation Errors**: Validate all percentages sum to 100%

## Future Enhancements

1. **Partial Pot Participation**: Allow traders to exclude specific pots
2. **Pot Selection UI**: Let traders choose which pots participate
3. **Real-time Updates**: WebSocket updates for profit distribution
4. **Historical Analytics**: Track pot performance over time
5. **Tax Reporting**: Generate tax documents for investors

