# Kostenlose Implementierungs-Roadmap

**Datum**: Januar 2026
**Ziel**: MVP-Features implementieren ohne externe kostenpflichtige Services
**Status**: Sofort umsetzbar

---

## 🎯 Übersicht

Dieses Dokument listet alle Features auf, die **sofort implementiert werden können**, ohne Geld für externe Services auszugeben. Wir nutzen Mock-Daten, Sandbox-Umgebungen und kostenlose Tools.

---

## ✅ Sofort umsetzbare Features (Priorisiert)

### 🔴 Höchste Priorität (MVP-kritisch)

#### 1. **Konto / Balance** (Konto-Feature deaktiviert)
**Status**: Teilweise vorhanden (`CashBalanceService`)

**Was zu implementieren ist:**
- ✅ CashBalanceService existiert bereits
- *(Konto-Feature deaktiviert; Nutzer hat normales Konto.)*

**Konkrete Tasks:**
```swift
// Konto (Wallet deaktiviert)
FIN1/Features/Shared/Views/
- Zeigt aktuelles Guthaben
- Zeigt Transaktionshistorie
- Buttons für Einzahlung/Auszahlung (Mock)

// 2. TransactionHistoryView
FIN1/Features/Shared/Views/TransactionHistoryView.swift
- Liste aller Transaktionen
- Filter nach Typ (Einzahlung, Auszahlung, Trade, Profit)

// 3. MockPaymentService
FIN1/Features/Shared/Services/MockPaymentService.swift
- simulateDeposit(amount:) -> Transaction
- simulateWithdrawal(amount:) -> Transaction
- validateWithdrawal(amount:) -> Bool
```

**Mock-Implementierung:**
- Keine echten Zahlungen
- Alle Transaktionen werden in Parse Server gespeichert
- UI zeigt "Demo-Modus" Badge
- Später einfach durch echte BaaS-Integration ersetzen

---

#### 2. **Transaktionslimits** (3-4 Tage)
**Status**: Nicht implementiert

**Was zu implementieren ist:**
- Tägliche Limits (z.B. 10.000€)
- Wöchentliche Limits
- Monatliche Limits
- Risikoklasse-basierte Limits

**Konkrete Tasks:**
```swift
// 1. TransactionLimitService
FIN1/Features/Shared/Services/TransactionLimitService.swift
protocol TransactionLimitServiceProtocol {
    func checkDailyLimit(userId: String, amount: Double) async throws -> Bool
    func checkWeeklyLimit(userId: String, amount: Double) async throws -> Bool
    func checkMonthlyLimit(userId: String, amount: Double) async throws -> Bool
    func getRemainingDailyLimit(userId: String) async throws -> Double
    func getRemainingWeeklyLimit(userId: String) async throws -> Double
    func getRemainingMonthlyLimit(userId: String) async throws -> Double
}

// 2. TransactionLimitModel
FIN1/Features/Shared/Models/TransactionLimit.swift
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

// 3. Integration in BuyOrderViewModel
- Pre-Trade-Check: checkDailyLimit() vor Order-Platzierung
- UI-Feedback: "Tägliches Limit erreicht" Warnung
```

**Mock-Implementierung:**
- Limits in Parse Server speichern (User-Klasse erweitern)
- Transaktions-Tracking in Parse Server
- Später durch echte Compliance-Engine ersetzen

---

#### 3. **Pre-Trade-Risiko-Checks** (2-3 Tage)
**Status**: Teilweise vorhanden (`BuyOrderValidator`)

**Was zu implementieren ist:**
- ✅ BuyOrderValidator existiert bereits
- ⚠️ **Fehlt**: Erweiterte Risiko-Checks
- ⚠️ **Fehlt**: Risiko-Scoring vor Trades
- ⚠️ **Fehlt**: UI-Feedback für Risiko-Warnungen

**Konkrete Tasks:**
```swift
// 1. RiskCheckService erweitern
FIN1/Features/Trader/Services/RiskCheckService.swift
protocol RiskCheckServiceProtocol {
    func calculateTradeRisk(order: OrderBuy, userRiskClass: RiskClass) -> TradeRisk
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

// 2. Integration in BuyOrderViewModel
- Vor Order-Platzierung: calculateTradeRisk()
- UI: Zeige Risiko-Warnungen
- UI: "Bestätigen Sie, dass Sie das Risiko verstehen" Checkbox
```

**Mock-Implementierung:**
- Risiko-Berechnung basierend auf:
  - User Risk Class (bereits vorhanden)
  - Order-Größe vs. Portfolio-Größe
  - Leverage (falls vorhanden)
  - Volatilität des Instruments (Mock-Daten)

---

#### 4. **MiFID II Compliance-Logging** (3-4 Tage)
**Status**: Teilweise vorhanden (Audit-Logging für Customer Support)

**Was zu implementieren ist:**
- Alle Orders/Transaktionen protokollieren
- Trade-Reporting-Struktur
- Compliance-Dashboard (optional)

**Konkrete Tasks:**
```swift
// 1. ComplianceLoggingService
FIN1/Features/Shared/Services/ComplianceLoggingService.swift
protocol ComplianceLoggingServiceProtocol {
    func logOrder(order: Order, userId: String) async throws
    func logTrade(trade: Trade, userId: String) async throws
    func logTransaction(transaction: Transaction, userId: String) async throws
    func getComplianceReport(userId: String, startDate: Date, endDate: Date) async throws -> ComplianceReport
}

// 2. ComplianceLog Model
FIN1/Features/Shared/Models/ComplianceLog.swift
struct ComplianceLog {
    let id: String
    let userId: String
    let eventType: ComplianceEventType
    let timestamp: Date
    let details: [String: Any]
    let regulatoryFlags: [RegulatoryFlag]
}

enum ComplianceEventType {
    case orderPlaced
    case orderExecuted
    case tradeCompleted
    case deposit
    case withdrawal
    case riskCheck
}

// 3. Integration in alle Trading-Services
- TraderService.placeBuyOrder() -> logOrder()
- TraderService.placeSellOrder() -> logOrder()
- TradeLifecycleService.createNewTrade() -> logTrade()
```

**Mock-Implementierung:**
- Alle Logs in Parse Server (ComplianceLog-Klasse)
- Später durch echte MiFID II Reporting-Engine ersetzen
- Export-Funktion für Regulatoren (CSV/PDF)

---

### 🟡 Mittlere Priorität (Wichtig für UX)

#### 5. **KYC-Flow-UI (ohne echten Provider)** (4-5 Tage)
**Status**: KYC-Status-Tracking vorhanden, UI-Flow fehlt

**Was zu implementieren ist:**
- KYC-Onboarding-Flow-UI
- Dokument-Upload-UI (ohne echten Provider)
- KYC-Status-Tracking-UI
- Mock-KYC-Verifizierung

**Konkrete Tasks:**
```swift
// 1. KYCOnboardingView
FIN1/Features/Authentication/Views/KYCOnboardingView.swift
- Schritt 1: Persönliche Daten bestätigen
- Schritt 2: Identitätsdokument hochladen (UI nur)
- Schritt 3: Adressnachweis hochladen (UI nur)
- Schritt 4: VideoIdent-Info (Text: "Wird später aktiviert")
- Schritt 5: KYC-Status anzeigen

// 2. DocumentUploadView
FIN1/Features/Authentication/Views/DocumentUploadView.swift
- Kamera-Integration für Dokumente
- Dokument-Vorschau
- Upload-Button (speichert lokal/Parse, ohne echten Provider)

// 3. MockKYCService
FIN1/Features/Authentication/Services/MockKYCService.swift
protocol KYCServiceProtocol {
    func submitKYCData(userId: String, documents: [KYCDocument]) async throws -> KYCStatus
    func getKYCStatus(userId: String) async throws -> KYCStatus
    func simulateKYCVerification(userId: String) async throws -> KYCStatus
}

// Mock: simulateKYCVerification() setzt Status auf "verified" nach 2 Sekunden
```

**Mock-Implementierung:**
- Dokumente in MinIO/Parse Server speichern
- KYC-Status in User-Klasse speichern
- Später durch echten KYC-Provider ersetzen (IDnow, Onfido)

---

#### 6. **Erweiterte Market-Data-UI (Mock-Daten)** (3-4 Tage)
**Status**: Market-Data-Service vorhanden, UI fehlt

**Was zu implementieren ist:**
- Live-Kurse-UI (mit Mock-Daten)
- Charts (einfache Line-Charts)
- Watchlist mit Live-Updates
- TradingView-ähnliche UI (optional)

**Konkrete Tasks:**
```swift
// 1. MarketDataView
FIN1/Features/Shared/Views/MarketDataView.swift
- Zeigt aktuelle Kurse (Mock-Daten)
- Auto-Refresh alle 5 Sekunden
- Filter nach Instrument-Typ

// 2. SimpleChartView
FIN1/Features/Shared/Components/SimpleChartView.swift
- Line-Chart mit Swift Charts
- Zeigt Preis-Historie (Mock-Daten)
- Zeitraum-Auswahl (1h, 1d, 1w, 1m)

// 3. MockMarketDataService erweitern
FIN1/Features/Shared/Services/MockMarketDataService.swift
- generateMockPrice(symbol: String) -> Double
- generateMockPriceHistory(symbol: String, timeframe: Timeframe) -> [PricePoint]
- simulatePriceMovement(symbol: String) -> AnyPublisher<Double, Never>
```

**Mock-Implementierung:**
- Preise werden zufällig generiert (mit realistischen Schwankungen)
- WebSocket-Simulation mit Timer
- Später durch echten Market-Data-Provider ersetzen

---

#### 7. **Order-Historie & Status-Tracking** (2-3 Tage)
**Status**: Teilweise vorhanden

**Was zu implementieren ist:**
- Erweiterte Order-Historie-UI
- Order-Status-Timeline
- Filter & Suche

**Konkrete Tasks:**
```swift
// 1. OrderHistoryView erweitern
FIN1/Features/Trader/Views/OrderHistoryView.swift
- Zeigt alle Orders (aktiv + abgeschlossen)
- Filter: Status, Datum, Symbol
- Suche nach Symbol/WKN

// 2. OrderStatusTimelineView
FIN1/Features/Trader/Views/Components/OrderStatusTimelineView.swift
- Zeigt Order-Status-Verlauf
- submitted → executed → confirmed → completed
- Mit Timestamps

// 3. OrderFilterView
FIN1/Features/Trader/Views/Components/OrderFilterView.swift
- Filter-UI für Order-Historie
```

**Mock-Implementierung:**
- Alle Daten aus Parse Server
- Status-Updates via OrderStatusSimulationService (bereits vorhanden)

---

### 🟢 Niedrige Priorität (Nice-to-have)

#### 8. **Compliance-Dashboard** (2-3 Tage)
**Status**: Nicht implementiert

**Was zu implementieren ist:**
- Dashboard für Compliance-Team
- Übersicht aller Trades/Orders
- Risiko-Flags
- Export-Funktionen

**Konkrete Tasks:**
```swift
// 1. ComplianceDashboardView
FIN1/Features/Admin/Views/ComplianceDashboardView.swift
- Übersicht aller Trades
- Risiko-Flags
- Export-Button (CSV/PDF)

// 2. ComplianceReportService
FIN1/Features/Admin/Services/ComplianceReportService.swift
- generateReport(startDate: Date, endDate: Date) -> ComplianceReport
- exportToCSV(report: ComplianceReport) -> Data
- exportToPDF(report: ComplianceReport) -> Data
```

---

#### 9. **Erweiterte Sicherheits-Features** (2-3 Tage)
**Status**: Basis-Sicherheit vorhanden

**Was zu implementieren ist:**
- Session-Timeout-Verbesserungen
- Security-Audit-Logging
- Device-Management-UI

**Konkrete Tasks:**
```swift
// 1. SessionTimeoutService erweitern
FIN1/Features/Authentication/Services/SessionTimeoutService.swift
- Konfigurierbare Timeouts
- Warnung vor Timeout
- Auto-Logout bei Inaktivität

// 2. SecurityAuditService
FIN1/Features/Shared/Services/SecurityAuditService.swift
- Loggt alle Security-Events
- Login-Versuche
- Fehlgeschlagene Authentifizierungen
- Device-Änderungen
```

---

## 📋 Implementierungs-Plan (4 Wochen)

### Woche 1: Konto & Limits
- **Tag 1-2**: Konto-/Limits-UI (Konto-Feature deaktiviert)
- **Tag 3-4**: Transaktionslimits implementieren
- **Tag 5**: Testing & Integration

### Woche 2: Risiko & Compliance
- **Tag 1-2**: Pre-Trade-Risiko-Checks erweitern
- **Tag 3-4**: MiFID II Compliance-Logging
- **Tag 5**: Testing & Integration

### Woche 3: KYC & Market Data
- **Tag 1-3**: KYC-Flow-UI implementieren
- **Tag 4-5**: Market-Data-UI mit Mock-Daten

### Woche 4: Polish & Testing
- **Tag 1-2**: Order-Historie erweitern
- **Tag 3-4**: Compliance-Dashboard
- **Tag 5**: Security-Features & Final Testing

---

## 🛠️ Technische Details

### Mock-Services Pattern

Alle Mock-Services folgen diesem Pattern:

```swift
protocol PaymentServiceProtocol {
    func deposit(amount: Double) async throws -> Transaction
    func withdraw(amount: Double) async throws -> Transaction
}

class MockPaymentService: PaymentServiceProtocol {
    func deposit(amount: Double) async throws -> Transaction {
        // Simuliere Delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde

        // Erstelle Transaction
        let transaction = Transaction(
            id: UUID().uuidString,
            type: .deposit,
            amount: amount,
            status: .completed,
            timestamp: Date()
        )

        // Speichere in Parse Server
        try await saveTransaction(transaction)

        return transaction
    }
}
```

### Daten-Persistierung

- **Parse Server**: Alle Daten in MongoDB/PostgreSQL
- **MinIO**: Dokumente (KYC, etc.)
- **Redis**: Session-Cache (optional)

### Spätere Integration

Alle Mock-Services haben klare Integration-Points:

```swift
// Später: Echte Integration
class RealPaymentService: PaymentServiceProtocol {
    private let baasClient: BaaSClient // Solaris/Basikon

    func deposit(amount: Double) async throws -> Transaction {
        // Echte BaaS-API-Calls
        let response = try await baasClient.createDeposit(amount: amount)
        return Transaction(from: response)
    }
}
```

---

## 🎯 Erfolgs-Kriterien

Nach 4 Wochen sollten folgende Features funktionieren:

1. ✅ Nutzer haben normales Konto (Kontostand; Konto-Feature deaktiviert)
2. ✅ Nutzer können Einzahlungen/Auszahlungen am Konto durchführen
3. ✅ Transaktionslimits werden durchgesetzt
4. ✅ Pre-Trade-Risiko-Checks funktionieren
5. ✅ Alle Orders/Trades werden für Compliance protokolliert
6. ✅ KYC-Flow-UI ist vollständig (ohne echten Provider)
7. ✅ Market-Data-UI zeigt Mock-Kurse
8. ✅ Order-Historie ist erweitert

---

## 📝 Nächste Schritte

1. **Diese Woche starten**: Konto-/Limits-Features (Konto-Feature deaktiviert)
2. **Parallel**: Transaktionslimits-Design finalisieren
3. **Woche 2**: Risiko-Checks erweitern

---

## 🔗 Verwandte Dokumente

- `PRODUCTION_ROADMAP_ANALYSIS.md` - Gesamt-Roadmap
- `BAAS_EVALUATION.md` - BaaS-Provider-Vergleich
- `ARCHITECTURE_GUARDRAILS.md` - Architektur-Richtlinien

---

**Erstellt**: Januar 2026
**Status**: Ready to implement
**Geschätzter Aufwand**: 4 Wochen (1 Entwickler)
