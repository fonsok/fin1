# Wallet vs. Account Statement: Architektur & Zusammenspiel

**Datum**: Januar 2026
**Status**: Architektur-Definition

---

## 🎯 Übersicht: Zwei verschiedene Features

### 1. **Account Statement / Kontoübersicht** (Bereits vorhanden ✅)
- **Zweck**: Read-only Übersicht aller Transaktionen
- **Zeigt**: Alle Buchungen (Trades, Profits, Commissions, etc.)
- **Funktion**: Dokumentation, Übersicht, PDF-Export
- **Zugriff**: Dashboard → "Kontoübersicht" / "Kontoauszug"

### 2. **Wallet** (Neu implementiert 🆕)
- **Zweck**: Interaktive Ein- und Auszahlungen
- **Zeigt**: Aktuelles Guthaben, Schnellaktionen, Transaktionshistorie
- **Funktion**: Geld auf Referenzkonto einzahlen/auszahlen
- **Zugriff**: Dashboard → "Wallet" Button

---

## 📊 Zusammenspiel

### Datenfluss

```
┌─────────────────────────────────────────────────────────────┐
│                    User's Referenzkonto                      │
│              (Externes Bankkonto des Users)                  │
└─────────────────────────────────────────────────────────────┘
                            ▲ │
                            │ │
                    Einzahlung │ Auszahlung
                            │ │
                            │ ▼
┌─────────────────────────────────────────────────────────────┐
│                      Wallet (FIN1)                           │
│  • Einzahlung: Referenzkonto → FIN1 Wallet                 │
│  • Auszahlung: FIN1 Wallet → Referenzkonto                  │
│  • Balance-Management                                        │
└─────────────────────────────────────────────────────────────┘
                            ▲ │
                            │ │
                    Gutschrift │ Belastung
                            │ │
                            │ ▼
┌─────────────────────────────────────────────────────────────┐
│              Cash Balance (FIN1 intern)                     │
│  • Trading-Transaktionen (Buy/Sell Orders)                  │
│  • Profit-Distribution                                      │
│  • Commissions                                              │
│  • Alle internen Buchungen                                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              Account Statement (Read-Only)                   │
│  • Zeigt ALLE Transaktionen (Wallet + Trading)              │
│  • Kontoübersicht                                            │
│  • PDF-Export                                                │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Transaktions-Typen

### Wallet-Transaktionen (über PaymentService)
- **Einzahlung** (`deposit`): Referenzkonto → FIN1 Wallet
- **Auszahlung** (`withdrawal`): FIN1 Wallet → Referenzkonto

### Trading-Transaktionen (über CashBalanceService)
- **Buy Order**: FIN1 Wallet → Position (Guthaben wird reduziert)
- **Sell Order**: Position → FIN1 Wallet (Guthaben wird erhöht)
- **Profit Distribution**: Gewinn wird dem Wallet gutgeschrieben
- **Commission**: Provision wird vom Wallet abgezogen

### Account Statement zeigt ALLES
- Wallet-Transaktionen (Einzahlung/Auszahlung)
- Trading-Transaktionen (Buy/Sell)
- Profit-Distribution
- Commissions
- Alle anderen Buchungen

---

## 🎨 User Journey

### Szenario 1: User möchte Geld einzahlen

1. **Dashboard** → "Wallet" Button klicken
2. **Wallet-View** öffnet sich
3. **"Einzahlen" Button** klicken
4. **Betrag eingeben** (z.B. 1.000€)
5. **"Einzahlen" bestätigen**
6. **Transaktion wird erstellt**:
   - Wallet-Balance erhöht sich um 1.000€
   - Transaction wird in PaymentService gespeichert
   - Transaction erscheint in Account Statement

### Szenario 2: User möchte Geld auszahlen

1. **Dashboard** → "Wallet" Button klicken
2. **Wallet-View** öffnet sich
3. **"Auszahlen" Button** klicken
4. **Betrag eingeben** (z.B. 500€)
5. **Validierung**: Prüft ob genug Guthaben vorhanden
6. **"Auszahlen" bestätigen**
7. **Transaktion wird erstellt**:
   - Wallet-Balance reduziert sich um 500€
   - Transaction wird in PaymentService gespeichert
   - Transaction erscheint in Account Statement
   - **Hinweis**: In Produktion würde hier eine SEPA-Überweisung initiiert

### Szenario 3: User möchte Kontoübersicht sehen

1. **Dashboard** → "Kontoübersicht" / "Kontoauszug" klicken
2. **Account Statement View** öffnet sich
3. **Zeigt ALLE Transaktionen**:
   - Wallet-Einzahlungen
   - Wallet-Auszahlungen
   - Trading-Transaktionen
   - Profit-Distribution
   - Commissions
4. **PDF-Export** möglich

---

## 🏗️ Technische Architektur

### Services

#### 1. **PaymentService** (Wallet-Transaktionen)
```swift
protocol PaymentServiceProtocol {
    func deposit(amount: Double) async throws -> Transaction
    func withdraw(amount: Double) async throws -> Transaction
    func getTransactionHistory(limit: Int, offset: Int) async throws -> [Transaction]
}
```
- **Verantwortung**: Ein- und Auszahlungen
- **Speichert**: Wallet-Transaktionen
- **Aktualisiert**: CashBalanceService (via `processGutschrift` / `processWithdrawal`)

#### 2. **CashBalanceService** (Trading-Transaktionen)
```swift
protocol CashBalanceServiceProtocol {
    var currentBalance: Double { get }
    func processBuyOrderExecution(amount: Double) async
    func processSellOrderExecution(amount: Double) async
    func processGutschrift(amount: Double) async
    func processWithdrawal(amount: Double) async
}
```
- **Verantwortung**: Internes Balance-Management für Trading
- **Wird aktualisiert von**: PaymentService, Trading-Services

#### 3. **AccountStatementViewModel** (Read-Only Übersicht)
```swift
class AccountStatementViewModel {
    func refresh() // Lädt alle Transaktionen
    var entries: [AccountStatementEntry] // Alle Transaktionen
}
```
- **Verantwortung**: Zeigt alle Transaktionen (Wallet + Trading)
- **Datenquellen**:
  - InvestorCashBalanceService (für Investoren)
  - TraderAccountStatementBuilder (für Trader)
  - PaymentService (für Wallet-Transaktionen)

---

## 📋 Integration: Wallet-Transaktionen in Account Statement

### Aktueller Stand
- Account Statement zeigt nur Trading-Transaktionen
- Wallet-Transaktionen werden noch nicht angezeigt

### Zu implementieren
- AccountStatementViewModel sollte auch Wallet-Transaktionen laden
- Kombiniere beide Datenquellen:
  ```swift
  // In AccountStatementViewModel
  private func buildInvestorStatement(for user: User) {
      // Trading-Transaktionen
      let tradingLedger = investorCashBalanceService.getTransactions(for: user.id)

      // Wallet-Transaktionen
      let walletTransactions = try await paymentService.getTransactionHistory(limit: 1000, offset: 0)

      // Konvertiere Wallet-Transaktionen zu AccountStatementEntry
      let walletEntries = walletTransactions.map { transaction in
          AccountStatementEntry.from(transaction: transaction)
      }

      // Kombiniere beide
      let allEntries = tradingLedger + walletEntries
      entries = allEntries.sorted { $0.occurredAt > $1.occurredAt }
  }
  ```

---

## 🎯 Zusammenfassung

### Account Statement / Kontoübersicht
- ✅ **Read-only** Übersicht
- ✅ Zeigt alle Transaktionen (Trading + Wallet)
- ✅ PDF-Export
- ✅ Kontoübersicht für Steuerberater
- ❌ **Keine** Ein-/Auszahlungen möglich

### Wallet
- ✅ **Interaktiv** - Ein- und Auszahlungen
- ✅ Schnellaktionen (Einzahlen/Auszahlen)
- ✅ Transaktionshistorie (nur Wallet-Transaktionen)
- ✅ Balance-Management
- ❌ Zeigt **nicht** Trading-Transaktionen (dafür Account Statement)

### Workflow
1. **Geld einzahlen**: Wallet → "Einzahlen"
2. **Trading**: Geld wird für Trades verwendet (automatisch)
3. **Gewinne**: Werden automatisch dem Wallet gutgeschrieben
4. **Geld auszahlen**: Wallet → "Auszahlen"
5. **Übersicht**: Account Statement zeigt alles

---

## 🔄 Nächste Schritte

1. **Wallet-Transaktionen in Account Statement integrieren**
   - AccountStatementViewModel erweitern
   - Wallet-Transaktionen laden und anzeigen

2. **Referenzkonto-Verwaltung** (später)
   - IBAN-Speicherung
   - SEPA-Überweisungen (via BaaS)

3. **Transaktionslimits** (später)
   - Tägliche/Wöchentliche Limits
   - Risikoklasse-basierte Limits

---

**Erstellt**: Januar 2026
**Status**: Architektur-Definition
