# Compliance Implementation Prioritäten

Basierend auf der Analyse der Cursor-Regeln und des aktuellen Code-Stands.

## 🔴 Priorität 1: Audit-Logging Integration (Quick Win - 1-2 Tage)

### Problem
- ✅ `AuditLoggingService` existiert bereits
- ❌ **NICHT integriert** in Trading-Services (`BuyOrderPlacementService`, `TraderService`)
- ❌ **NICHT integriert** in Payment-Services
- ❌ **NICHT integriert** in Accounting (`InvestorAccountStatementBuilder`)

### Konkrete Tasks

#### 1.1 BuyOrderPlacementService erweitern
**Datei**: `FIN1/Features/Trader/Services/BuyOrderPlacementService.swift`

```swift
// ✅ ERGÄNZEN: Audit-Logging nach erfolgreicher Order-Platzierung
final class BuyOrderPlacementService: BuyOrderPlacementServiceProtocol {
    private let auditLoggingService: any AuditLoggingServiceProtocol
    
    init(auditLoggingService: any AuditLoggingServiceProtocol) {
        self.auditLoggingService = auditLoggingService
    }
    
    func placeOrder(...) async throws -> BuyOrderPlacementResult {
        // ... existing code ...
        
        do {
            let order = try await traderService.placeBuyOrder(orderRequest)
            
            // ✅ NEU: Audit-Logging für MiFID II Compliance
            try? await auditLoggingService.logOrder(
                userId: user.id,
                orderType: .buy,
                orderDetails: [
                    "symbol": searchResult.wkn,
                    "quantity": actualQuantity,
                    "price": executedPrice,
                    "orderMode": orderMode.rawValue,
                    "underlyingAsset": searchResult.underlyingAsset
                ],
                regulatoryFlags: [.mifidII, .preTradeCheck]
            )
            
            return BuyOrderPlacementResult(success: true, error: nil)
        } catch {
            // ... error handling ...
        }
    }
}
```

#### 1.2 TraderService erweitern
**Datei**: `FIN1/Features/Trader/Services/TraderService.swift`

- Audit-Logging für `placeBuyOrder()` und `placeSellOrder()`
- Logging für Trade-Executions

#### 1.3 PaymentService erweitern
**Datei**: `FIN1/Features/Investor/Services/PaymentService.swift` (oder wo PaymentService ist)

- Audit-Logging für `processDeposit()` und `processWithdrawal()`

#### 1.4 InvestorAccountStatementBuilder erweitern
**Datei**: `FIN1/Shared/Accounting/InvestorAccountStatementBuilder.swift` (aktuell geöffnet)

- Optional: Logging für Statement-Generierung (für Audit-Trail)

### Impact
- ✅ **Sofortige Compliance-Verbesserung** - alle Trades werden geloggt
- ✅ **Niedriges Risiko** - bestehender Service wird nur erweitert
- ✅ **Schnell umsetzbar** - 1-2 Tage Arbeit

---

## 🟡 Priorität 2: Transaction Limits Service (Mittelfristig - 3-5 Tage)

### Problem
- ❌ **Kein TransactionLimitService vorhanden**
- ❌ **Keine täglichen/wöchentlichen/monatlichen Limits**
- ❌ **Keine Risk-Class-basierten Limits**

### Konkrete Tasks

#### 2.1 TransactionLimitService erstellen
**Neue Dateien**:
- `FIN1/Features/Shared/Services/TransactionLimitServiceProtocol.swift`
- `FIN1/Features/Shared/Services/TransactionLimitService.swift`
- `FIN1/Features/Shared/Models/TransactionLimit.swift`

**Implementierung** (Mock-First):
```swift
protocol TransactionLimitServiceProtocol {
    func checkDailyLimit(userId: String, amount: Double) async throws -> Bool
    func checkWeeklyLimit(userId: String, amount: Double) async throws -> Bool
    func checkMonthlyLimit(userId: String, amount: Double) async throws -> Bool
    func getRemainingDailyLimit(userId: String) async throws -> Double
    func getRemainingWeeklyLimit(userId: String) async throws -> Double
    func getRemainingMonthlyLimit(userId: String) async throws -> Double
    func getRiskClassBasedLimit(userId: String) async throws -> Double
}

struct TransactionLimit {
    let userId: String
    let dailyLimit: Double
    let weeklyLimit: Double
    let monthlyLimit: Double
    let riskClassBasedLimit: Double
    let dailySpent: Double
    let weeklySpent: Double
    let monthlySpent: Double
}
```

#### 2.2 BuyOrderValidator erweitern
**Datei**: `FIN1/Features/Trader/Services/BuyOrderValidator.swift`

```swift
func validateOrderPlacement(
    ...,
    transactionLimitService: (any TransactionLimitServiceProtocol)?,
    estimatedCost: Double
) -> Bool {
    // ... existing validations ...
    
    // ✅ NEU: Transaction limit check
    if let limitService = transactionLimitService,
       let user = userService.currentUser {
        // Check daily limit (async - needs refactoring to async validator)
        // Or: Check synchronously with cached limits
    }
    
    return isValid
}
```

**Hinweis**: BuyOrderValidator ist synchron, TransactionLimitService ist async. Zwei Optionen:
1. **Option A**: Validator async machen (größere Refactoring)
2. **Option B**: Limits im ViewModel cachen und synchron prüfen

#### 2.3 BuyOrderViewModel erweitern
**Datei**: `FIN1/Features/Trader/ViewModels/BuyOrderViewModel.swift`

- Pre-Trade-Check: `checkDailyLimit()` vor Order-Platzierung
- UI-Feedback: "Tägliches Limit erreicht" Warnung
- Anzeige: Verbleibendes Limit

#### 2.4 Parse Server Mock-Implementierung
- Limits in Parse Server speichern (User-Klasse erweitern)
- Transaktions-Tracking in Parse Server
- Später durch echte Compliance-Engine ersetzen

### Impact
- ✅ **Regulatorische Anforderung** - Transaktionslimits sind Pflicht
- ⚠️ **Mittleres Risiko** - Neue Service-Integration
- ⏱️ **3-5 Tage** Arbeit

---

## 🟢 Priorität 3: Risk Scoring Service (Langfristig - 5-7 Tage)

### Problem
- ✅ `BuyOrderValidator` existiert (Basis-Validierung)
- ❌ **Fehlt**: Erweiterte Risiko-Checks
- ❌ **Fehlt**: Risiko-Scoring vor Trades
- ❌ **Fehlt**: UI-Feedback für Risiko-Warnungen

### Konkrete Tasks

#### 3.1 RiskCheckService erstellen
**Neue Dateien**:
- `FIN1/Features/Trader/Services/RiskCheckServiceProtocol.swift`
- `FIN1/Features/Trader/Services/RiskCheckService.swift`

```swift
protocol RiskCheckServiceProtocol {
    func calculateTradeRisk(
        order: OrderBuy,
        userRiskClass: RiskClass,
        portfolioSize: Double
    ) -> TradeRisk
    
    func validateTradeRisk(tradeRisk: TradeRisk) -> RiskValidationResult
    func getRiskWarnings(tradeRisk: TradeRisk) -> [RiskWarning]
}

enum TradeRisk {
    case low
    case medium
    case high
    case veryHigh
}

struct RiskValidationResult {
    let isAllowed: Bool
    let warnings: [RiskWarning]
    let requiresConfirmation: Bool
}

struct RiskWarning {
    let severity: RiskWarningSeverity
    let message: String
    let requiresUserConfirmation: Bool
}
```

#### 3.2 Integration in BuyOrderViewModel
- Vor Order-Platzierung: `calculateTradeRisk()`
- UI: Zeige Risiko-Warnungen
- UI: "Bestätigen Sie, dass Sie das Risiko verstehen" Checkbox

#### 3.3 Mock-Implementierung
- Risiko-Berechnung basierend auf:
  - User Risk Class (bereits vorhanden)
  - Order-Größe vs. Portfolio-Größe
  - Leverage (falls vorhanden)
  - Volatilität des Instruments (Mock-Daten)

### Impact
- ✅ **Bessere UX** - Nutzer sehen Risiko-Warnungen
- ✅ **Compliance** - Risiko-Bewusstsein dokumentiert
- ⏱️ **5-7 Tage** Arbeit

---

## 📋 Empfohlene Reihenfolge

### Sprint 1 (Diese Woche)
1. ✅ **Audit-Logging Integration** (Priorität 1)
   - BuyOrderPlacementService
   - TraderService
   - PaymentService
   - **Zeit**: 1-2 Tage

### Sprint 2 (Nächste Woche)
2. ✅ **Transaction Limits Service** (Priorität 2)
   - Service erstellen
   - BuyOrderValidator erweitern
   - UI-Integration
   - **Zeit**: 3-5 Tage

### Sprint 3 (Später)
3. ✅ **Risk Scoring Service** (Priorität 3)
   - Service erstellen
   - UI-Integration
   - **Zeit**: 5-7 Tage

---

## 🎯 Quick Win: Audit-Logging (Start hier!)

**Warum zuerst?**
- ✅ Schnell umsetzbar (1-2 Tage)
- ✅ Sofortige Compliance-Verbesserung
- ✅ Niedriges Risiko (bestehender Service)
- ✅ Hoher Impact (alle Trades werden geloggt)

**Nächster Schritt**: Soll ich mit der Audit-Logging-Integration in `BuyOrderPlacementService` beginnen?
