# DRY Violation Analyse: Trader Balance Berechnung

**Datum**: Januar 2026
**Status**: Analyse - DRY-Verletzung identifiziert

---

## 🔍 Problem-Identifikation

### Wiederholte Logik an 3 Stellen:

#### 1. **DashboardStatsViewModel.updateTraderAccountBalance()** (Zeile 188-232)
```swift
let snapshot = TraderAccountStatementBuilder.buildSnapshot(...)
var balance = snapshot.closingBalance
let walletTransactions = try await paymentService.getTransactionHistory(...)
let kontoDelta = walletTransactions.reduce(...) { ... }
accountBalance = balance + kontoDelta
```

#### 2. **AccountStatementViewModel.buildTraderStatement()** (Zeile 148-180)
```swift
let snapshot = TraderAccountStatementBuilder.buildSnapshot(...)
let walletTransactions = try await paymentService.getTransactionHistory(...)
let kontoEntries = walletTransactions.map { ... }
let allEntries = snapshot.entries + kontoEntries
currentBalance = snapshot.closingBalance  // ⚠️ FEHLER: Berücksichtigt Konto nicht!
```

#### 3. **WalletViewModel.getUserSpecificBalance()** (Konto; Feature deaktiviert) (Zeile 121-130)
```swift
let snapshot = TraderAccountStatementBuilder.buildSnapshot(...)
return snapshot.closingBalance  // ⚠️ FEHLER: Berücksichtigt Konto nicht!
```

---

## ❌ DRY-Verletzungen

### 1. **Wiederholte Balance-Berechnung**
- **3x** `TraderAccountStatementBuilder.buildSnapshot()` Aufruf
- **2x** Konto-Transaktionen laden (`paymentService.getTransactionHistory()`)
- **3x** Balance-Berechnung (aber unterschiedlich implementiert!)

### 2. **Inkonsistente Implementierung**
- **DashboardStatsViewModel**: ✅ Berechnet korrekt (Trading + Konto)
- **AccountStatementViewModel**: ❌ Berechnet falsch (nur Trading, ignoriert Konto)
- **KontoViewModel**: ❌ Berechnet falsch (nur Trading, ignoriert Konto)

### 3. **Code-Duplikation**
- Konto-Transaktionen laden: 2x identisch
- Konto-Delta berechnen: 1x (nur in DashboardStatsViewModel)
- Balance kombinieren: 3x unterschiedlich

---

## 🎯 Best Practices Verletzungen

### Accounting Principles
- ❌ **Single Source of Truth**: Balance wird an 3 Stellen unterschiedlich berechnet
- ❌ **Konsistenz**: Verschiedene ViewModels zeigen unterschiedliche Balances
- ❌ **Wartbarkeit**: Änderung der Balance-Logik erfordert 3 Änderungen

### MVVM Principles
- ❌ **Separation of Concerns**: Balance-Berechnung gehört in einen Service, nicht in ViewModels
- ❌ **Reusability**: Balance-Berechnung sollte wiederverwendbar sein

### DRY Principles
- ❌ **Don't Repeat Yourself**: Gleiche Logik wird 3x wiederholt
- ❌ **Single Responsibility**: Balance-Berechnung sollte zentralisiert sein

---

## ✅ Lösung: Zentralisierte Balance-Berechnung

### Option 1: Erweitere TraderAccountStatementBuilder (Empfohlen)

**Vorteile:**
- ✅ Single Source of Truth
- ✅ Konsistent für alle ViewModels
- ✅ Wartbar (eine Stelle für Änderungen)

**Implementierung:**
```swift
// In TraderAccountStatementBuilder
static func buildSnapshotWithWallet(
    for user: User?,
    invoiceService: any InvoiceServiceProtocol,
    configurationService: any ConfigurationServiceProtocol,
    paymentService: (any PaymentServiceProtocol)?
) async -> TraderAccountStatementSnapshot {
    let snapshot = buildSnapshot(...)

    // Add wallet transactions
    if let paymentService = paymentService,
       let userId = user?.id {
        let walletTransactions = try? await paymentService.getTransactionHistory(...)
        let kontoDelta = walletTransactions?.reduce(...) ?? 0.0
        return TraderAccountStatementSnapshot(
            entries: snapshot.entries + kontoEntries,
            openingBalance: snapshot.openingBalance,
            closingBalance: snapshot.closingBalance + kontoDelta
        )
    }

    return snapshot
}
```

---

### Option 2: Neuer Service: TraderBalanceService

**Vorteile:**
- ✅ Klare Separation of Concerns
- ✅ Testbar
- ✅ Wiederverwendbar

**Implementierung:**
```swift
protocol TraderBalanceServiceProtocol {
    func getBalance(for traderId: String) async -> Double
    func getBalanceWithWallet(for traderId: String) async -> Double
}
```

---

### Option 3: Erweitere TraderCashBalanceService

**Vorteile:**
- ✅ Konsistent mit InvestorCashBalanceService
- ✅ Bereits vorhandene Infrastruktur

**Nachteile:**
- ⚠️ TraderCashBalanceService wird aktuell nicht für Balance verwendet
- ⚠️ Trader-Balance wird aus Invoices berechnet, nicht aus Service

---

## 📊 Vergleich: Aktuell vs. Empfohlen

| Aspekt | Aktuell | Empfohlen (Option 1) |
|--------|---------|---------------------|
| **Balance-Berechnung** | 3x wiederholt | 1x zentralisiert |
| **Konsistenz** | ❌ Inkonsistent | ✅ Konsistent |
| **Wartbarkeit** | ❌ 3 Stellen ändern | ✅ 1 Stelle ändern |
| **Single Source of Truth** | ❌ Nein | ✅ Ja |
| **Testbarkeit** | ⚠️ Schwer testbar | ✅ Einfach testbar |

---

## 🎯 Empfehlung

### ✅ **Option 1: Erweitere TraderAccountStatementBuilder**

**Warum:**
1. ✅ Single Source of Truth für Trader-Balance
2. ✅ Konsistent für alle ViewModels
3. ✅ Minimal invasive Änderung
4. ✅ Bereits etablierte Architektur

**Implementierung:**
- Neue Methode: `buildSnapshotWithWallet(...)`
- Alle ViewModels verwenden diese Methode
- Entfernt Code-Duplikation

---

## 🔄 Refactoring-Plan

1. **Erweitere TraderAccountStatementBuilder**
   - Neue Methode `buildSnapshotWithWallet(...)`
   - Berücksichtigt Konto-Transaktionen

2. **Aktualisiere ViewModels**
   - `DashboardStatsViewModel`: Verwendet `buildSnapshotWithWallet()`
   - `AccountStatementViewModel`: Verwendet `buildSnapshotWithWallet()`
   - `WalletViewModel` (Konto; Feature deaktiviert): Verwendet `buildSnapshotWithWallet()`

3. **Entferne Duplikation**
   - Entferne wiederholte Konto-Loading-Logik
   - Entferne wiederholte Balance-Berechnung

---

**Erstellt**: Januar 2026
**Status**: Analyse - DRY-Verletzung identifiziert, Lösung vorgeschlagen ✅
