---
alwaysApply: true
---

# FIN1 Compliance & Regulatory Rules

This rule file enforces compliance and regulatory requirements specific to FIN1's financial/trading platform. These rules ensure proper risk management, audit logging, and regulatory compliance (MiFID II, BaFin requirements).

## Pre-Trade Risk Checks

**CRITICAL**: All order and trade flows must include proper risk validation before execution.

### BuyOrderValidator Pattern

- **REQUIRED**: All new order/trade flows MUST extend `BuyOrderValidator`, not replace it
- **REQUIRED**: Risk-class-based validation MUST use existing `RiskClassCalculationService`
- **FORBIDDEN**: Creating new validators that bypass `BuyOrderValidator`
- **REQUIRED**: Pre-trade checks must validate:
  - User risk class compatibility with trade type
  - Transaction limits (daily/weekly/monthly)
  - Sufficient funds (including minimum reserve from `ConfigurationService`)
  - Price validity (not expired)
  - Order format validation (limit price format, quantity limits)

### Risk Class Integration

- **REQUIRED**: Risk class calculations MUST use `RiskClassCalculationService` (located in `Features/Authentication/Services/`)
- **REQUIRED**: Risk class changes MUST trigger compliance review
- **FORBIDDEN**: Hardcoding risk class logic - use service layer
- **REQUIRED**: Pre-trade risk scoring MUST consider:
  - User's risk class (`User.riskClass`)
  - Order size vs. portfolio size
  - Instrument volatility (when available)
  - Leverage (if applicable)

### Transaction Limits

- **REQUIRED**: Transaction limits MUST be risk-class-based
- **REQUIRED**: Limits MUST be validated before order placement
- **REQUIRED**: UI MUST show remaining limits and warnings
- **REQUIRED**: Daily, weekly, and monthly limits MUST be enforced
- **REQUIRED**: Limit validation MUST happen in service layer, not just UI

**Example Pattern**:
```swift
// ✅ CORRECT: Extend BuyOrderValidator
let validationResult = buyOrderValidator.validateOrderPlacement(
    quantity: quantity,
    orderMode: orderMode,
    limit: limit,
    priceValidityProgress: priceValidityProgress,
    estimatedCost: estimatedCost,
    userService: userService,
    cashBalanceService: cashBalanceService,
    configurationService: configurationService,
    maxQuantity: maxQuantity
)

// ❌ FORBIDDEN: Create new validator that bypasses BuyOrderValidator
let myCustomValidator = MyCustomValidator() // Don't do this
```

## MiFID II Compliance Logging

**CRITICAL**: All trading activities must be logged for regulatory compliance and audit trails.

### Audit Logging Service

- **REQUIRED**: All order placements MUST trigger audit logging via `AuditLoggingService`
- **REQUIRED**: All trade executions MUST be logged with:
  - User ID
  - Timestamp
  - Order details (type, quantity, price, instrument)
  - Execution price
  - Regulatory flags
  - Risk class at time of trade
- **REQUIRED**: New trading flows MUST integrate with existing `AuditLoggingService`
- **FORBIDDEN**: Creating new audit logging systems - extend existing one
- **REQUIRED**: All deposit/withdrawal transactions MUST be logged
- **REQUIRED**: All risk checks and validations MUST be logged

### AuditLoggingService Location

- **Service Protocol**: `Features/CustomerSupport/Services/AuditLoggingServiceProtocol.swift`
- **Service Implementation**: `Features/CustomerSupport/Services/AuditLoggingService.swift`
- **Models**: `Features/CustomerSupport/Models/AuditModels.swift`

**Example Pattern**:
```swift
// ✅ CORRECT: Use existing AuditLoggingService
try await auditLoggingService.logOrder(
    userId: user.id,
    orderType: .buy,
    orderDetails: orderDetails,
    regulatoryFlags: [.mifidII, .preTradeCheck]
)

// ❌ FORBIDDEN: Create new logging system
let myCustomLogger = MyCustomLogger() // Don't do this
```

### Compliance Event Types

When logging, use appropriate event types:
- `orderPlaced` - Order submitted but not yet executed
- `orderExecuted` - Order completed
- `tradeCompleted` - Trade finalized
- `deposit` - Funds deposited
- `withdrawal` - Funds withdrawn
- `riskCheck` - Risk validation performed
- `limitExceeded` - Transaction limit violation attempt

## Regulatory Compliance Requirements

### MiFID II Requirements

- **REQUIRED**: All trades MUST be reportable (logged with sufficient detail)
- **REQUIRED**: Best execution policy MUST be documented and enforced
- **REQUIRED**: Cost transparency - all fees MUST be clearly displayed
- **REQUIRED**: Risk warnings MUST be shown for appropriate instruments
- **REQUIRED**: Trade reporting structure MUST support regulatory export (CSV/PDF)

### BaFin Requirements

- **REQUIRED**: KYC/AML processes MUST be integrated (via BaaS when available)
- **REQUIRED**: Customer identification MUST be verified before trading
- **REQUIRED**: Suspicious activity MUST be flagged and logged

### PSD2 Compliance (when applicable)

- **REQUIRED**: Strong Customer Authentication (SCA) for payment operations
- **REQUIRED**: Payment Initiation Service (PIS) integration when implemented
- **REQUIRED**: Account Information Service (AIS) integration when implemented

## Integration Points

### Services That Must Integrate Compliance

1. **Trading Services**:
   - `TraderService.placeBuyOrder()` → MUST log via `AuditLoggingService`
   - `TraderService.placeSellOrder()` → MUST log via `AuditLoggingService`
   - `BuyOrderPlacementService.placeOrder()` → MUST validate via `BuyOrderValidator`

2. **Payment Services**:
   - `PaymentService.processDeposit()` → MUST log transaction
   - `PaymentService.processWithdrawal()` → MUST log transaction
   - `PaymentService.getTransactionHistory()` → MUST include audit trail

3. **Investment Services**:
   - `InvestmentService.createInvestment()` → MUST log investment creation
   - `InvestmentService.processCollectionBill()` → MUST log financial transactions

### ViewModels That Must Enforce Compliance

- `BuyOrderViewModel` → MUST use `BuyOrderValidator` for validation
- `SellOrderViewModel` → MUST use similar validation pattern
- `PaymentViewModel` → MUST log all transactions
- Any ViewModel handling financial transactions → MUST integrate audit logging

## Error Handling for Compliance

- **REQUIRED**: Compliance validation failures MUST throw specific `AppError` types
- **REQUIRED**: Compliance errors MUST be logged even when user-facing errors are shown
- **REQUIRED**: Audit logging failures MUST NOT block user operations (log error, continue)
- **REQUIRED**: Risk check failures MUST block operations (fail-safe)

## Testing Requirements

- **REQUIRED**: All compliance-related services MUST have unit tests
- **REQUIRED**: Test risk class validation scenarios
- **REQUIRED**: Test transaction limit enforcement
- **REQUIRED**: Test audit logging integration
- **REQUIRED**: Test error scenarios (logging failures, validation failures)

## Documentation References

When implementing compliance features, reference:
- `Documentation/PRODUCTION_ROADMAP_ANALYSIS.md` - Compliance requirements overview
- `Documentation/BAAS_EVALUATION.md` - BaaS integration for KYC/AML
- `Documentation/FREE_IMPLEMENTATION_ROADMAP.md` - Compliance implementation details
- `FIN1/Features/CustomerSupport/Services/AuditLoggingService.swift` - Existing audit logging implementation

## Guardrails (fail PRs if violated)

- **No new validators**: Must extend `BuyOrderValidator`, not create new ones
- **No bypassing audit logging**: All trades/orders must log via `AuditLoggingService`
- **No hardcoded risk logic**: Must use `RiskClassCalculationService`
- **No missing compliance checks**: All financial transactions must have pre-trade validation
- **No unlogged trades**: All order placements and executions must be logged
