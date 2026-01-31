# Transaction Limits Service Implementation

## Übersicht

Der Transaction Limits Service wurde implementiert, um regulatorische Anforderungen (MiFID II, BaFin) zu erfüllen. Er stellt tägliche, wöchentliche und monatliche Transaktionslimits basierend auf der Risikoklasse des Users bereit.

## Wichtige Information: Risk Class Storage

**⚠️ WICHTIG**: Die Risikoklasse wird während des Registrierungsprozesses (Get Started, Step 13+) berechnet und im User-Model gespeichert.

### Wie Risk Class gespeichert wird:

1. **Während SignUp (Step 13+)**: 
   - `SignUpData.finalRiskClass` wird berechnet (siehe `SignUpDataRiskCalculation.swift`)
   - `finalRiskClass` = `userSelectedRiskClass ?? calculatedRiskClass`
   - Die berechnete Risk Class wird als `User.riskTolerance` gespeichert

2. **In User Model**:
   - `User.riskTolerance: Int` enthält tatsächlich die **Risk Class** (1-7), nicht die ursprüngliche Risk Tolerance (1-10)
   - Siehe `SignUpDataUserCreation.swift:59`: `riskTolerance: finalRiskClass.rawValue`
   - Siehe `UserFactory.swift:288`: `riskTolerance: signUpData.finalRiskClass.rawValue`

3. **Im TransactionLimitService**:
   - Wir lesen `User.riskTolerance` direkt als RiskClass
   - `RiskClass(rawValue: user.riskTolerance)` gibt die korrekte Risk Class zurück
   - **KEINE Neuberechnung nötig** - die gespeicherte Risk Class wird verwendet

## Implementierung

### Dateien

- `FIN1/Features/Shared/Models/TransactionLimit.swift` - Model mit Limits und Validierung
- `FIN1/Features/Shared/Services/TransactionLimitServiceProtocol.swift` - Protocol
- `FIN1/Features/Shared/Services/TransactionLimitService.swift` - Implementation (Mock-First)
- `FIN1/Shared/Models/CalculationConstants.swift` - Erweitert um `TransactionLimits` Struktur

### Features

1. **Risk-Class-basierte Limits**:
   - Base Limits: Daily €10k, Weekly €50k, Monthly €200k
   - Multiplier basierend auf Risk Class (0.5x bis 2.5x)
   - Risk Class 1: 0.5x (€5k daily)
   - Risk Class 7: 2.5x (€25k daily)

2. **Transaction Tracking**:
   - Tägliche/wöchentliche/monatliche Ausgaben werden getrackt
   - In-memory Storage (später Parse Server)

3. **Pre-Trade Validation**:
   - `BuyOrderPlacementService` prüft Limits vor Order-Platzierung
   - Blockiert Orders, die Limits überschreiten

4. **UI-Feedback**:
   - `BuyOrderViewModel` zeigt Warnungen bei Limit-Überschreitung
   - Verbleibende Limits werden angezeigt

## Integration

### Services

- `TransactionLimitService` in `AppServices` registriert
- Wird an `BuyOrderPlacementService` und `BuyOrderViewModel` injiziert

### Flow

1. User öffnet Buy Order View
2. `BuyOrderViewModel` prüft Limits automatisch bei `estimatedCost`-Änderungen
3. Bei Order-Platzierung: `BuyOrderPlacementService` prüft Limits erneut
4. Nach erfolgreicher Order: Transaction wird für Limit-Tracking aufgezeichnet

## Nächste Schritte

- [ ] Parse Server Integration: Limits persistent speichern
- [ ] UI-Integration: Limit-Warnungen in `BuyOrderView` anzeigen
- [ ] Limit-Anzeige: Verbleibende Limits in UI zeigen
