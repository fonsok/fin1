# Pot-Synchronized Trading: Architecture Summary

## Executive Summary

**Question**: How should synchronized pot-based trading be implemented (frontend vs backend)?

**Answer**: **Backend-driven architecture with frontend coordination** - The backend handles all business logic, calculations, and data persistence, while the frontend initiates actions and displays results.

## Recommended Architecture

### Backend Responsibilities (Primary)

1. **Business Logic**
   - Pro-rata calculation (ownership percentages)
   - Pot balance validation
   - Trade allocation logic
   - Profit distribution calculations

2. **Data Persistence**
   - Pot-trade participation records
   - Investor trade allocations
   - Trader trade allocations
   - Profit distribution history

3. **Transaction Management**
   - Atomic order placement with pot synchronization
   - Rollback on failures
   - Data consistency guarantees

4. **API Endpoints**
   - `POST /api/trades/place-buy-order-with-pots` - Place order with pot sync
   - `POST /api/trades/:tradeId/distribute-profit` - Distribute profits
   - `GET /api/trades/:tradeId/pot-participations` - Get pot participation details

### Frontend Responsibilities (Secondary)

1. **User Interface**
   - Order placement form
   - Pot participation display
   - Profit distribution visualization
   - Investor profit views

2. **Service Coordination**
   - Call backend APIs
   - Handle responses/errors
   - Update local state
   - Trigger UI updates

3. **Real-time Updates**
   - Display order status
   - Show pot participation in real-time
   - Update profit displays

## Why Backend-Driven?

### ✅ Advantages

1. **Single Source of Truth**: All calculations happen in one place
2. **Data Integrity**: Database transactions ensure consistency
3. **Security**: Business logic protected from client manipulation
4. **Scalability**: Can handle multiple clients simultaneously
5. **Auditability**: All operations logged server-side
6. **Testability**: Easier to test business logic in isolation

### ❌ Frontend-Only Approach Problems

1. **Data Inconsistency**: Multiple clients could create conflicting allocations
2. **Security Risk**: Business logic exposed to client manipulation
3. **Calculation Errors**: Complex pro-rata math could have bugs
4. **No Transaction Safety**: Partial failures could corrupt data
5. **Difficult Testing**: Hard to test distributed calculations

## Implementation Flow

### 1. Order Placement Flow

```
[Frontend] Trader clicks "Place Order"
    ↓
[Frontend] Validates input, calls API
    ↓
[Backend] Receives order request
    ↓
[Backend] Gets all active pots for trader
    ↓
[Backend] Calculates pro-rata ownership percentages
    ↓
[Backend] Creates main buy order
    ↓
[Backend] Creates pot trade participations (database)
    ↓
[Backend] Creates investor trade allocations (database)
    ↓
[Backend] Creates trader trade allocation (database)
    ↓
[Backend] Returns result to frontend
    ↓
[Frontend] Displays pot participation info
```

### 2. Profit Distribution Flow

```
[Backend] Trade completes (sell order executed)
    ↓
[Backend] Calculates total profit
    ↓
[Backend] Distributes profit to pots (pro-rata)
    ↓
[Backend] Distributes profit to investors (within each pot)
    ↓
[Backend] Distributes profit to trader
    ↓
[Backend] Updates all account balances
    ↓
[Backend] Sends notifications
    ↓
[Frontend] Receives notification, updates UI
```

## Database Design

### Core Tables

1. **PotTradeParticipation**: Links pots to trades, tracks ownership
2. **InvestorTradeAllocation**: Tracks individual investor shares
3. **TraderTradeAllocation**: Tracks trader's own share

### Key Relationships

```
Trade (1) ──→ (N) PotTradeParticipation
PotTradeParticipation (1) ──→ (N) InvestorTradeAllocation
Trade (1) ──→ (1) TraderTradeAllocation
```

## Pro-Rata Calculation Example

**Input:**
- Trade: 100 shares @ €10 = €1,000
- Pot 1: €500 (Investor A: €300, Investor B: €200)
- Pot 2: €300 (Investor C: €300)
- Trader Capital: €200

**Calculation:**
```
Total = €1,000
Pot 1 ownership = 50% → 50 shares
Pot 2 ownership = 30% → 30 shares
Trader ownership = 20% → 20 shares

Within Pot 1:
  Investor A = 60% of pot → 30 shares
  Investor B = 40% of pot → 20 shares

Within Pot 2:
  Investor C = 100% of pot → 30 shares
```

**Profit Distribution (€200 profit):**
```
Pot 1: €100 (Investor A: €60, Investor B: €40)
Pot 2: €60 (Investor C: €60)
Trader: €40
```

## Technology Stack

### Backend
- **Parse Server**: Main backend framework
- **MongoDB**: Database (via Parse)
- **Cloud Functions**: Business logic
- **REST API**: HTTP endpoints

### Frontend
- **SwiftUI**: UI framework
- **MVVM**: Architecture pattern
- **Async/Await**: Async operations
- **Combine**: Reactive updates

## Security Considerations

1. **Authorization**: Verify trader owns pots
2. **Validation**: Check pot balances before allocation
3. **Transactions**: Use database transactions for atomicity
4. **Audit Logging**: Log all pot-trade operations
5. **Rate Limiting**: Prevent abuse

## Performance Considerations

1. **Caching**: Cache active pots for trader
2. **Batch Operations**: Batch database writes
3. **Async Processing**: Process profit distribution asynchronously
4. **Indexing**: Proper database indexes

## Testing Strategy

1. **Unit Tests**: Pro-rata calculations, allocation logic
2. **Integration Tests**: End-to-end order placement
3. **UI Tests**: Pot participation display
4. **Load Tests**: Multiple concurrent orders

## Migration Path

1. **Phase 1**: Add database schema (non-breaking)
2. **Phase 2**: Implement backend services
3. **Phase 3**: Update frontend (feature flag)
4. **Phase 4**: Enable for all traders
5. **Phase 5**: Remove legacy code

## Conclusion

**Backend-driven architecture** is the recommended approach because:
- Ensures data consistency
- Protects business logic
- Enables proper transaction management
- Provides auditability
- Scales better

The frontend's role is to:
- Provide user interface
- Coordinate with backend services
- Display results
- Handle user interactions

This separation of concerns follows best practices for financial applications where data integrity and security are paramount.



