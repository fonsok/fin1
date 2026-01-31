# Pot-Based Trading Implementation: Complete Prompt

## Context

You are implementing a pot-based trading system for a SwiftUI iOS application (FIN1) that follows strict MVVM architecture, dependency injection, and service-oriented design patterns. The application uses Parse Server as the backend.

## Core Requirement

**Problem**: A trader places a buy order (e.g., 1000 pieces @ €2), and the system must simultaneously execute purchases for:
1. **Trader's portion**: Paid from trader's cash balance
2. **Investor pot portion**: Paid from an active investment pot balance (€15,321 in example)

**Key Constraints**:
- Trader sees only "pot is active" indicator, NOT the pot balance
- Single order executed on stock exchange combining both portions
- Exact quantity calculation must account for trading fees (which depend on order amount)
- Some securities have denomination constraints (10, 20, 50, 100, 1000)
- Some securities have minimum order amount requirements (e.g., minimum €100 order)
- Pro-rata profit distribution to trader and investors
- Admin-configurable handling of small remaining pot balances

## Technical Requirements

### 1. Quantity Calculation Service

**Location**: `FIN1/Shared/Services/PotQuantityCalculationService.swift`

**Functionality**:
- Calculate maximum purchasable quantity from pot balance accounting for fees
- Use binary search algorithm for efficiency
- Support denomination constraints (round down to valid multiples)
- Support minimum order amount constraints
- Combine trader quantity + pot quantity into single order
- Split fees proportionally between trader and pot portions

**Algorithm**:
- Binary search when no denomination constraint
- Incremental search in denomination steps when denomination specified
- Start from minimum required quantity when minimum order amount specified
- Validate total order meets minimum order amount (individual portions may be below)

**Key Methods**:
```swift
func calculateMaxPurchasableQuantity(
    potBalance: Double,
    pricePerSecurity: Double,
    denomination: Int?,
    minimumOrderAmount: Double?
) -> Int

func calculateCombinedOrderDetails(
    traderQuantity: Int,
    traderCashBalance: Double,
    potBalance: Double,
    pricePerSecurity: Double,
    denomination: Int?,
    minimumOrderAmount: Double?
) -> CombinedOrderCalculationResult
```

### 2. Trading Constraints

**Denominations**: Some securities trade only in multiples of 10, 20, 50, 100, or 1000
- Implemented in `CalculationConstants.SecurityDenominations`
- Helper functions: `roundDownToDenomination()`, `isValidDenomination()`

**Minimum Order Amount**: Some securities require minimum order value (e.g., €100)
- Helper functions: `meetsMinimumOrderAmount()`, `calculateMinimumQuantity()`
- Total order (trader + pot) must meet minimum
- Individual portions may be below minimum if total meets it

### 3. Remaining Balance Handling

**Admin-Configurable Strategy** (via `ConfigurationManagementView`):
- **Option 1: Immediate Distribution**: Distribute if remaining balance < threshold (default: €5)
- **Option 2: Accumulate Until Threshold**: Keep small remainders until threshold reached

**Implementation**:
- Configuration stored in `ConfigurationService`
- `PotBalanceDistributionService` handles distribution logic
- Proportional distribution to investors based on original investment amounts

### 4. Architecture Requirements

**Service Location**: `FIN1/Shared/Services/` (cross-cutting calculation utility)
- Similar to `FeeCalculationService` and `ProfitCalculationService`
- Stateless, thread-safe
- Implements `ServiceLifecycle` protocol

**Naming Conventions** (from `.cursorrules`):
- ✅ Use: Service, Repository, Store, Coordinator, Provider, Configurator, Utility
- ❌ FORBIDDEN: "Manager" suffix
- All classes must be `final` unless part of inheritance hierarchy
- Models use `struct`, ViewModels use `class`

**MVVM Compliance**:
- No business logic in Views
- All calculations in ViewModels or Services
- Services injected via protocols
- No `.shared` singletons outside composition root

### 5. Example Calculation

**Input**:
- Trader Desired: 1000 pieces @ €2
- Trader Cash: €50,000
- Pot Balance: €15,321
- Price: €2 per security

**Process**:
1. Validate trader can afford 1000 pieces: €2,000 + fees ≈ €2,011.50 ✅
2. Calculate pot's max purchasable: Binary search finds 7,624 pieces
   - Order Amount: 7,624 × €2 = €15,248
   - Fees: €71.50
   - Total Cost: €15,319.50
   - Remaining: €1.50
3. Combine: 1000 (trader) + 7,624 (pot) = **8,624 pieces total**
4. Calculate total fees: ~€83 (on €17,248 total order)
5. Split fees proportionally:
   - Trader: ~€11.50 (proportional to €2,000)
   - Pot: ~€71.50 (proportional to €15,248)

**Output**:
- Single order executed: **8,624 pieces @ €2**
- Trader pays: €2,011.50
- Pot pays: €15,319.50
- Pot remaining: €1.50 (handled per admin configuration)

## Files Created/Modified

### Services
- `FIN1/Shared/Services/PotQuantityCalculationService.swift` (NEW)
- `FIN1/Shared/Services/PotQuantityCalculationServiceProtocol.swift` (NEW)
- `FIN1/Shared/Services/ConfigurationService.swift` (MODIFIED - added pot balance distribution settings)
- `FIN1/Shared/Services/ConfigurationServiceProtocol.swift` (MODIFIED - added pot balance distribution settings)

### Models
- `FIN1/Shared/Models/CalculationConstants.swift` (MODIFIED - added `SecurityDenominations` with denomination and minimum order amount helpers)

### ViewModels
- `FIN1/Features/Admin/ViewModels/ConfigurationManagementViewModel.swift` (MODIFIED - added pot balance distribution properties)

### Views
- `FIN1/Features/Admin/Views/ConfigurationManagementView.swift` (MODIFIED - added pot balance distribution UI with tappable buttons)
- `FIN1/Features/Dashboard/Views/AdminDashboardView.swift` (MODIFIED - added navigation link to Configuration)

### Documentation
- `FIN1/Documentation/POT_TRADING_COMPREHENSIVE_IMPLEMENTATION.md` (CONSOLIDATED - combines all pot trading documentation)

### Renamed Files (Manager → Appropriate Suffix)
- `TradingStateManagerProtocol.swift` → `TradingStateLifecycleProtocol.swift`
- `LegacyTradingStateManager.swift` → `LegacyTradingStateStore.swift`
- `DownloadsFolderManager.swift` → `DownloadsFolderUtility.swift`
- `PaginationManager.swift` → `PaginationPreview.swift`

## Key Implementation Details

### Fee Calculation
Fees are calculated on total order amount, then split proportionally:
- Order Fee: 0.5% (min €5, max €50)
- Exchange Fee: 0.1% (min €1, max €20)
- Foreign Costs: €1.50 (fixed)

### Binary Search Optimization
- Without denomination: Standard binary search
- With denomination: Incremental search in denomination steps
- With minimum order: Start from minimum required quantity

### Combined Order Logic
1. Round trader quantity to denomination if specified
2. Calculate trader's actual quantity (may be limited by cash)
3. Calculate pot's purchasable quantity (with all constraints)
4. Validate total order meets minimum order amount
5. Calculate and split fees proportionally
6. Return combined result

### Admin Configuration UI
- Two tappable buttons for strategy selection (not Picker)
- Text field for threshold input
- Validation and error handling
- Wrapped in ScrollView for visibility

## Testing Considerations

- Unit tests for quantity calculation with various constraints
- Edge cases: insufficient balance, denomination rounding, minimum order not met
- Integration tests for full order placement flow
- Validation that total order meets minimum when individual portions don't

## Backend Integration

Parse Server cloud function should:
1. Validate pot exists and has sufficient balance
2. Calculate quantities using same algorithm
3. Execute single order on stock exchange
4. Update trader cash balance and pot balance
5. Handle remaining balance distribution per admin configuration
6. Create trade record with pro-rata profit distribution

## Security & Validation

- Pot balance validation server-side
- Price validation (positive, reasonable)
- Quantity limits enforcement
- Atomic database transactions
- Audit logging for all calculations

## Next Steps for Full Implementation

1. Integrate `PotQuantityCalculationService` into `BuyOrderViewModel`
2. Update `UnifiedOrderService` to use combined quantity calculation
3. Implement `PotBalanceDistributionService` for remaining balance handling
4. Add backend Parse Server cloud functions
5. Add unit and integration tests
6. Add UI indicators for denomination/minimum order constraints
7. Add error handling for insufficient balances

## Architecture Compliance Checklist

- ✅ Service in `Shared/Services/` (cross-cutting utility)
- ✅ Protocol-oriented design
- ✅ `ServiceLifecycle` conformance
- ✅ No "Manager" suffix
- ✅ `final` class declaration
- ✅ Stateless service design
- ✅ Proper error handling
- ✅ Documentation updated
- ✅ Build succeeds

---

**Use this prompt to:**
- Understand the complete pot-based trading system
- Implement missing pieces (backend integration, UI updates)
- Debug issues with quantity calculation
- Extend functionality (additional constraints, optimizations)
- Onboard new developers to the system



