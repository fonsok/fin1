# Account Statement: Datenquellen & Architektur

**Datum**: Januar 2026
**Status**: ✅ Aktualisiert - Zentrale Builder-Architektur dokumentiert

**Hinweis**: Für detaillierte Architektur-Beschreibung siehe `445_ACCOUNT_STATEMENT_ARCHITECTURE.md`

---

## ✅ Korrekte Zuordnung

### Für Investoren (Investor Role)

```
Account Statement lädt:
├── Investment Ledger (InvestorCashBalanceService)
│   • Investments (Reservierung)
│   • Profit Distribution
│   • Commissions (Investor-Seite)
│   • Service Charges
│   • Remaining Balance Distribution
│   ❌ KEINE Wallet-Transaktionen
│
└── Wallet Transactions (PaymentService)
    • Einzahlungen (deposit)
    • Auszahlungen (withdrawal)
    ✅ Nur Wallet-Transaktionen
```

**Datenquellen:**
- `InvestorAccountStatementBuilder.buildSnapshotWithWallet()` → Single Source of Truth
  - Lädt Investment-Transaktionen: `InvestorCashBalanceService.getTransactions()`
  - Lädt Wallet-Transaktionen: `PaymentService.getTransactionHistory()`
  - Kombiniert beide und berechnet Balance chronologisch

---

### Für Trader (Trader Role)

```
Account Statement lädt:
├── Trading Ledger (TraderAccountStatementBuilder)
│   • Buy Orders (aus Invoices)
│   • Sell Orders (aus Invoices)
│   • Commissions (Trader-Seite, Credit Notes)
│   ❌ KEINE Wallet-Transaktionen
│
└── Wallet Transactions (PaymentService)
    • Einzahlungen (deposit)
    • Auszahlungen (withdrawal)
    ✅ Nur Wallet-Transaktionen
```

**Datenquellen:**
- `TraderAccountStatementBuilder.buildSnapshotWithWallet()` → Single Source of Truth
  - Lädt Trading-Transaktionen: `TraderAccountStatementBuilder.buildSnapshot()` (aus Invoices)
  - Lädt Wallet-Transaktionen: `PaymentService.getTransactionHistory()`
  - Kombiniert beide und berechnet Balance chronologisch

---

## 📊 Services & Verantwortlichkeiten

### InvestorCashBalanceService
- **Zweck**: Investment-Transaktionen für Investoren
- **Speichert**: Investments, Profits, Commissions (Investor-Seite)
- **NICHT**: Wallet-Transaktionen (werden im PaymentService gespeichert)

### TraderAccountStatementBuilder
- **Zweck**: Trading-Transaktionen für Trader
- **Speichert**: Buy/Sell Orders (aus Invoices), Commissions (Trader-Seite)
- **NICHT**: Wallet-Transaktionen (werden im PaymentService gespeichert)

### PaymentService
- **Zweck**: Wallet-Transaktionen (für beide Rollen)
- **Speichert**: Einzahlungen, Auszahlungen
- **Wird verwendet von**: Investor UND Trader

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
   • Kombiniert Investment Ledger + Wallet Transactions automatisch
   ↓
5. Balance wird chronologisch berechnet → Keine Duplikate ✅
```

### Trader: Einzahlung

```
1. User klickt "Einzahlen" im Wallet
   ↓
2. MockPaymentService.deposit()
   • Erstellt Transaction (PaymentService)
   • Aktualisiert globales CashBalanceService
   ↓
3. Account Statement lädt:
   • TraderAccountStatementBuilder.buildSnapshotWithWallet()
   • Kombiniert Trading Ledger (Invoices) + Wallet Transactions automatisch
   ↓
4. Balance wird chronologisch berechnet → Keine Duplikate ✅
```

---

## 🎯 Zusammenfassung

### InvestorCashBalanceService Ledger
- ✅ **Investment-Transaktionen** (für Investoren)
- ❌ **KEINE** Wallet-Transaktionen
- ❌ **KEINE** Trading-Transaktionen

### TraderAccountStatementBuilder
- ✅ **Trading-Transaktionen** (für Trader, aus Invoices)
- ❌ **KEINE** Wallet-Transaktionen
- ❌ **KEINE** Investment-Transaktionen

### PaymentService
- ✅ **Wallet-Transaktionen** (für beide Rollen)
- ❌ **KEINE** Investment-Transaktionen
- ❌ **KEINE** Trading-Transaktionen

---

**Erstellt**: Januar 2026
**Status**: Korrektur - Klarstellung der Datenquellen ✅
