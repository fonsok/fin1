# Account Statement: Datenquellen & Architektur

**Datum**: Januar 2026
**Status**: ✅ Aktualisiert - Zentrale Builder-Architektur dokumentiert

**Hinweis**: Vollständige Architektur inkl. **Backend-first / Fallback** siehe `ACCOUNT_STATEMENT_ARCHITECTURE.md` (dort auch **Beleg-Links iOS**: Tap auf „Belegnr.: …“ im Kontoauszug, Reparatur 2026-05). Parse-Buchungen und `SettlementAPIService`: `BACKEND_CALCULATION_MIGRATION.md`. Diese Datei fokussiert die **Zuordnung der Datenquellen** (Handels-/Investment-Daten vs. Konto-Zahlungsbewegungen).

**Konto:** Crypto-Wallet-Produktfeature ist deaktiviert; Nutzer führen ein **normales Konto**. Im Code heißt die Builder-Methode noch `buildSnapshotWithWallet` (Legacy-Name) — gemeint sind **Ledger + Zahlungsbewegungen**.

---

## ✅ Korrekte Zuordnung

### Für Investoren (Investor Role)

```
Kontoauszug lädt:
├── Handels-/Investment-Zeilen (primär Backend, Fallback lokales Ledger)
│   • Mit SettlementAPIService: Parse AccountStatement (z. B. commission_debit, investment_profit)
│   • Fallback: InvestorCashBalanceService.getTransactions()
│   • Investments, Profit Distribution, Commissions, Service Charges, Remaining Balance …
│   ❌ KEINE Zahlungsbewegungen (die liegen im PaymentService)
│
└── Zahlungsbewegungen (Konto) — PaymentService
    • Einzahlungen (deposit)
    • Auszahlungen (withdrawal)
    ✅ Nur Ein-/Auszahlungen auf dem Konto
```

**Datenquellen:**
- `InvestorAccountStatementBuilder.buildSnapshotWithWallet()` → zentrale Kombination *(Legacy-Methodenname)*
  - Investment-/Backend-Zeilen: `fetchAccountStatement` wenn `settlementAPIService` gesetzt, sonst `InvestorCashBalanceService.getTransactions()`
  - Zahlungsbewegungen: `PaymentService.getTransactionHistory()`
  - Kombination und chronologische Balance wie in `ACCOUNT_STATEMENT_ARCHITECTURE.md`

---

### Für Trader (Trader Role)

```
Kontoauszug lädt:
├── Handels-Zeilen (primär Backend, Fallback Rechnungs-/Credit-Note-Pfad)
│   • Mit SettlementAPIService: Parse AccountStatement (Trader-Provision u. a.)
│   • Fallback: TraderAccountStatementBuilder.buildSnapshot() (Invoices, Credit Notes)
│   • Buy/Sell Orders, Commissions (Trader-Seite)
│   ❌ KEINE Konto-Zahlungsbewegungen
│
└── Zahlungsbewegungen (Konto) — PaymentService
    • Einzahlungen (deposit)
    • Auszahlungen (withdrawal)
    ✅ Nur Ein-/Auszahlungen auf dem Konto
```

**Datenquellen:**
- `TraderAccountStatementBuilder.buildSnapshotWithWallet()` → zentrale Kombination *(Legacy-Methodenname)*
  - Handels-/Backend-Zeilen: `fetchAccountStatement` wenn `settlementAPIService` gesetzt, sonst `buildSnapshot()` aus Invoices
  - Zahlungsbewegungen: `PaymentService.getTransactionHistory()`
  - Kombination und chronologische Balance wie in `ACCOUNT_STATEMENT_ARCHITECTURE.md`

---

## 📊 Services & Verantwortlichkeiten

### InvestorCashBalanceService
- **Zweck**: Lokales Investment-Ledger für Investoren (Fallback, wenn Backend-Zeilen fehlen)
- **Speichert**: Investments, Profits, Commissions (Investor-Seite)
- **NICHT**: Zahlungsbewegungen auf dem Konto (liegen im `PaymentService`)

### TraderAccountStatementBuilder
- **Zweck**: Handelszeilen für Trader (Fallback-Pfad aus Invoices / Credit Notes)
- **Enthält**: Buy/Sell Orders, Commissions (Trader-Seite), wenn nicht durch Backend-Zeilen abgedeckt
- **NICHT**: Zahlungsbewegungen (liegen im `PaymentService`)

### PaymentService
- **Zweck**: **Zahlungsbewegungen** auf dem Konto (für beide Rollen)
- **Speichert**: Einzahlungen, Auszahlungen
- **Wird verwendet von**: Investor UND Trader

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
   • Kombiniert Investment-/Backend-Zeilen + Zahlungsbewegungen
   ↓
5. Balance wird chronologisch berechnet → Keine Duplikate ✅
```

### Trader: Einzahlung (Konto)

```
1. User löst Einzahlung auf dem Konto aus
   ↓
2. MockPaymentService.deposit()
   • Erstellt Zahlungsbewegung (PaymentService)
   • Aktualisiert globales CashBalanceService
   ↓
3. Kontoauszug lädt:
   • TraderAccountStatementBuilder.buildSnapshotWithWallet()
   • Kombiniert Handels-/Backend-Zeilen + Zahlungsbewegungen
   ↓
4. Balance wird chronologisch berechnet → Keine Duplikate ✅
```

---

## 🎯 Zusammenfassung

### InvestorCashBalanceService Ledger
- ✅ **Investment-Transaktionen** (für Investoren; Fallback neben Backend)
- ❌ **KEINE** Konto-Zahlungsbewegungen
- ❌ **KEINE** Trader-Handelszeilen

### TraderAccountStatementBuilder (Fallback-Pfad)
- ✅ **Handelszeilen** (für Trader, aus Invoices / Credit Notes, wenn nicht aus Backend)
- ❌ **KEINE** Konto-Zahlungsbewegungen
- ❌ **KEINE** Investor-Investment-Ledger-Einträge

### PaymentService
- ✅ **Zahlungsbewegungen** auf dem Konto (für beide Rollen)
- ❌ **KEINE** Investment-Ledger-Einträge
- ❌ **KEINE** Handelsbuchungen (Buy/Sell/Provision aus dem Handel)

---

**Erstellt**: Januar 2026
**Status**: Korrektur - Klarstellung der Datenquellen ✅
