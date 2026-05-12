# Account Statement Architecture: Final Implementation

**Datum**: Januar 2026  
**Status**: ✅ Implementiert - Single Source of Truth etabliert

---

## 🎯 Übersicht

Das Account Statement System verwendet zentrale Builder-Methoden als Single Source of Truth für Balance-Berechnungen. Alle ViewModels verwenden die gleichen Builder-Methoden, was DRY-Verletzungen eliminiert und Konsistenz sichert.

---

## 📊 Architektur

### Investor Account Statement

**Builder**: `InvestorAccountStatementBuilder.buildSnapshotWithWallet()`

**Datenquellen:**
1. **Investment Ledger** (`InvestorCashBalanceService.getTransactions()`)
   - Investments (Reservierung)
   - Profit Distribution
   - Commissions (Investor-Seite)
   - Service Charges
   - Remaining Balance Distribution

2. **Wallet Transactions** (`PaymentService.getTransactionHistory()`)
   - Einzahlungen (deposit)
   - Auszahlungen (withdrawal)

**Verwendung:**
- `AccountStatementViewModel.buildInvestorStatement()`
- `DashboardStatsViewModel.updateInvestorBalance()`
- `WalletViewModel.getUserSpecificBalance()`

---

### Trader Account Statement

**Builder**: `TraderAccountStatementBuilder.buildSnapshotWithWallet()`

**Datenquellen:**
1. **Trading Ledger** (`TraderAccountStatementBuilder.buildSnapshot()`)
   - Buy Orders (aus Invoices)
   - Sell Orders (aus Invoices)
   - Commissions (Trader-Seite, Credit Notes)

2. **Wallet Transactions** (`PaymentService.getTransactionHistory()`)
   - Einzahlungen (deposit)
   - Auszahlungen (withdrawal)

**Verwendung:**
- `AccountStatementViewModel.buildTraderStatement()`
- `DashboardStatsViewModel.updateTraderAccountBalance()`
- `WalletViewModel.getUserSpecificBalance()`

---

## ✅ Implementierte Features

### 1. Single Source of Truth
- ✅ Alle Balance-Berechnungen zentralisiert in Builders
- ✅ Keine Code-Duplikation
- ✅ Konsistente Balance-Werte in allen ViewModels

### 2. Chronologische Balance-Berechnung
- ✅ `balanceAfter` wird chronologisch neu berechnet
- ✅ Entries werden sortiert (aufsteigend für Berechnung, absteigend für Anzeige)
- ✅ Korrekte Running Balance für jeden Entry

### 3. Error Handling
- ✅ Builder-Methoden werfen `AppError`
- ✅ ViewModels fangen Fehler ab und zeigen sie an
- ✅ Fallback-Mechanismen bei Fehlern

### 4. Code Quality
- ✅ Funktionen ≤ 50 Zeilen (Helper-Methoden)
- ✅ Magic Numbers entfernt (Konstanten in `CalculationConstants`)
- ✅ Proper async/await patterns

---

## 🔄 Transaktions-Fluss

### Investor: Einzahlung

```
1. User klickt "Einzahlen" im Wallet
   ↓
2. MockPaymentService.deposit()
   • Erstellt Transaction (PaymentService)
   • Ruft InvestorCashBalanceService.processDeposit() auf
   ↓
3. InvestorCashBalanceService.processDeposit()
   • Aktualisiert Balance
   • ❌ Speichert NICHT im Ledger (verhindert Duplikate)
   ↓
4. Account Statement lädt:
   • InvestorAccountStatementBuilder.buildSnapshotWithWallet()
   • Kombiniert Investment Ledger + Wallet Transactions
   ↓
5. Balance wird chronologisch berechnet → Keine Duplikate ✅
```

### Trader: Einzahlung

```
1. User klickt "Einzahlen" im Wallet
   ↓
2. MockPaymentService.deposit()
   • Erstellt Transaction (PaymentService)
   ↓
3. Account Statement lädt:
   • TraderAccountStatementBuilder.buildSnapshotWithWallet()
   • Kombiniert Trading Ledger (Invoices) + Wallet Transactions
   ↓
4. Balance wird chronologisch berechnet → Keine Duplikate ✅
```

---

## 📁 Dateien

### Builder
- `FIN1/Shared/Accounting/InvestorAccountStatementBuilder.swift`
- `FIN1/Shared/Accounting/TraderAccountStatementBuilder.swift`

### ViewModels
- `FIN1/Features/Dashboard/ViewModels/AccountStatementViewModel.swift`
- `FIN1/Features/Dashboard/ViewModels/DashboardStatsViewModel.swift`
- `FIN1/Features/Shared/ViewModels/WalletViewModel.swift`

### Services
- `FIN1/Features/Investor/Services/InvestorCashBalanceService.swift`
- `FIN1/Shared/Services/MockPaymentService.swift`

---

## 🎯 Best Practices

### ✅ DRY Principles
- Single Source of Truth für Balance-Berechnung
- Keine Code-Duplikation
- Zentrale Builder-Methoden

### ✅ MVVM Architecture
- ViewModels koordinieren nur
- Business Logic in Builders
- Protocol-based Dependency Injection

### ✅ Accounting Principles
- Chronologische Balance-Berechnung
- Alle Transaktionen werden kombiniert
- Keine Duplikation

### ✅ SwiftUI Best Practices
- Async/await patterns
- MainActor isolation
- Proper error handling

---

## 📝 Migration History

### Vorher (DRY-Verletzung)
- Balance-Berechnung an 3+ Stellen
- Inkonsistente Implementierung
- Code-Duplikation

### Nachher (DRY-konform)
- Single Source of Truth
- Konsistente Architektur
- Zentrale Builder-Methoden

---

**Erstellt**: Januar 2026  
**Status**: ✅ Final Implementation - Alle DRY-Verletzungen behoben
