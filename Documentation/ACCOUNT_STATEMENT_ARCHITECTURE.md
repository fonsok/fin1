# Account Statement Architecture: Final Implementation

**Datum**: Januar 2026
**Status**: ✅ Implementiert - Single Source of Truth etabliert

---

## 🎯 Übersicht

Das Account Statement System verwendet zentrale Builder-Methoden als Single Source of Truth für Balance-Berechnungen. Alle ViewModels verwenden die gleichen Builder-Methoden, was DRY-Verletzungen eliminiert und Konsistenz sichert.

---

## Backend-first / Fallback (Kontoauszug)

**Autoritative Buchungen** für abgeschlossene Trades liegen bei **Parse Cloud Code** (`trade.js` → `accountingHelper.settleCompletedTrade`): u. a. `AccountStatement`-Einträge, Credit Notes, Collection Bills. Details und Phasen: `Documentation/BACKEND_CALCULATION_MIGRATION.md`.

**Im Client (Anzeige):**

- `InvestorAccountStatementBuilder` und `TraderAccountStatementBuilder` akzeptieren optional `SettlementAPIService` und rufen **`fetchAccountStatement`** auf.
- **Online / erfolgreich:** Einträge aus dem Backend werden in `AccountStatementEntry` gemappt (z. B. `commission_debit`, `investment_profit`, `residual_return` beim Investor; Trader analog für Provision-Gutschriften).
- **Fallback:** Kein Service injiziert, leere Backend-Antwort, oder Fehler beim Abruf → **lokales Ledger** (Investor: `InvestorCashBalanceService.getTransactions()`; Trader: Rechnungs-/Credit-Note-Pfad in `buildSnapshot()`). Der Fallback ist **nur für Resilienz/Offline** gedacht, nicht als zweite „Wahrheit“ neben dem Backend.

**Konto:** Das Crypto-Wallet-Produktfeature ist deaktiviert; ein **normales Konto** reicht. Die Builder-Methode heißt im Code noch `buildSnapshotWithWallet` (Legacy-Name) — faktisch werden **Handels-/Investment-Ledger** und **Zahlungsbewegungen** (`PaymentService`) zusammengeführt.

---

## Beleg-Links (iOS): Tap auf „Belegnr.: …“ im Kontoauszug

**Stand:** Mai 2026

**Symptom (behoben):** Im **Trader**-Kontoauszug wirkten Verweise auf Buchungsbelege (unter anderem Belegnummern wie `CN-…`, `TSC-…`, `TBC-…`) beim Tippen oft wie ohne Wirkung oder lösten keinen zuverlässigen Beleg-Screen aus, während dieselben Dokumente unter **Notifications → Documents** sichtbar und nutzbar waren. Beim **Investor** trat das seltener auf, weil der `DocumentService`-Cache dort typischerweise schon alle benötigten `Document`-Zeilen enthielt.

**Ursache (nur Client):** `AccountStatementEntry.referencedDocument` suchte ausschließlich in `documentService.documents`. Fehlte die Zeile im Cache (z. B. Race nach Login, noch nicht abgeschlossenes `loadDocuments`, Rollen-/UserId-Kombination), gab es keinen Fallback auf die vom Backend mitgelieferte **`referenceDocumentId`** (Parse-`objectId` der `Document`-Klasse).

**Lösung:**

1. **Zweistufig:** Zuerst synchron wie bisher Cache (`referencedDocument`); bei Miss asynchron `AccountStatementEntry.resolveReferencedDocument` → `DocumentService.resolveDocumentForDeepLink(objectId:)` (Einzelabruf, Merge in den lokalen Cache).
2. **In-flight-Dedupe:** Mehrere parallele Aufrufe mit derselben `objectId` teilen sich **einen** Netzwerk-Fetch (`DocumentService`); `reset()` bricht ausstehende Tasks ab.

**Relevante Dateien:** `FIN1/Features/Dashboard/Models/AccountStatementEntry+ReferencedDocument.swift`, `FIN1/Features/Dashboard/Views/AccountStatementView.swift`, `FIN1/Features/Dashboard/Views/MonthlyAccountStatementView.swift`, `FIN1/Shared/Services/DocumentServiceProtocol.swift` (`DocumentService`).

**Kurzreferenz:** `Documentation/FIN1_APP_DOCS/04_DEVELOPER_GUIDE.md` → Abschnitt *Dokumente / Account Statement (Beleg-Links)*.

---

## 📊 Architektur

### Investor Account Statement

**Builder**: `InvestorAccountStatementBuilder.buildSnapshotWithWallet()` *(Legacy-Name; siehe Abschnitt Backend-first / Zahlungsbewegungen oben)*

**Datenquellen:**
1. **Investment-Ledger** (`InvestorCashBalanceService.getTransactions()`) — nur im **Fallback**, wenn kein Backend-Eintrag genutzt wird; sonst siehe Backend-first oben.
   - Investments (Reservierung)
   - Profit Distribution
   - Commissions (Investor-Seite)
   - Service Charges
   - Remaining Balance Distribution

2. **Zahlungsbewegungen (Konto)** (`PaymentService.getTransactionHistory()`)
   - Einzahlungen (deposit)
   - Auszahlungen (withdrawal)

**Verwendung:**
- `AccountStatementViewModel.buildInvestorStatement()`
- `DashboardStatsViewModel.updateInvestorBalance()`
- `WalletViewModel.getUserSpecificBalance()` *(Klassenname historisch; Kontext: Kontosaldo / Zahlungsbewegungen)*

---

### Trader Account Statement

**Builder**: `TraderAccountStatementBuilder.buildSnapshotWithWallet()` *(Legacy-Name; kombiniert Handels-Ledger + Zahlungsbewegungen)*

**Datenquellen:**
1. **Handels-Ledger** (`TraderAccountStatementBuilder.buildSnapshot()`) — im Fallback ohne nutzbare Backend-Zeilen; mit Backend siehe Abschnitt Backend-first oben.
   - Buy Orders (aus Invoices)
   - Sell Orders (aus Invoices)
   - Commissions (Trader-Seite, Credit Notes)

2. **Zahlungsbewegungen (Konto)** (`PaymentService.getTransactionHistory()`)
   - Einzahlungen (deposit)
   - Auszahlungen (withdrawal)

**Verwendung:**
- `AccountStatementViewModel.buildTraderStatement()`
- `DashboardStatsViewModel.updateTraderAccountBalance()`
- `WalletViewModel.getUserSpecificBalance()` *(Klassenname historisch; Kontext: Kontosaldo / Zahlungsbewegungen)*

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

### Investor: Einzahlung (Konto)

```
1. User löst Einzahlung auf dem Konto aus
   ↓
2. MockPaymentService.deposit()
   • Erstellt Zahlungsbewegung (PaymentService)
   • Ruft InvestorCashBalanceService.processDeposit() auf
   ↓
3. InvestorCashBalanceService.processDeposit()
   • Aktualisiert Balance
   • ❌ Speichert NICHT im Investment-Ledger (verhindert Duplikate)
   ↓
4. Kontoauszug lädt:
   • InvestorAccountStatementBuilder.buildSnapshotWithWallet()
   • Kombiniert Investment-Ledger (bzw. Backend-Zeilen) + Zahlungsbewegungen
   ↓
5. Balance wird chronologisch berechnet → Keine Duplikate ✅
```

### Trader: Einzahlung (Konto)

```
1. User löst Einzahlung auf dem Konto aus
   ↓
2. MockPaymentService.deposit()
   • Erstellt Zahlungsbewegung (PaymentService)
   ↓
3. Kontoauszug lädt:
   • TraderAccountStatementBuilder.buildSnapshotWithWallet()
   • Kombiniert Handels-Ledger (Invoices; bzw. Backend-Zeilen) + Zahlungsbewegungen
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
- `FIN1/Features/Shared/ViewModels/WalletViewModel.swift` *(Kontosaldo; kein Crypto-Konto-Feature)*

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
- Handels-/Investment-Daten und Konto-**Zahlungsbewegungen** werden kombiniert
- Keine Duplikation; bei Online-Betrieb autoritative Trade-Buchungen im Backend (siehe Backend-first oben)

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
