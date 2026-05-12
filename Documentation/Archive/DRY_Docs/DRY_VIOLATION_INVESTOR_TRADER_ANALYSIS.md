# DRY Violation Analyse: Investor vs. Trader Balance Berechnung

**Datum**: Januar 2026
**Status**: Analyse - DRY-Verletzung identifiziert

---

## 🔍 Problem-Identifikation

### Investor Balance Berechnung

#### Aktuelle Implementierung:

1. **InvestorCashBalanceService.getBalance()** ✅
   - Balance enthält bereits Wallet-Transaktionen
   - `processDeposit/Withdrawal()` aktualisiert die Balance direkt

2. **AccountStatementViewModel.buildInvestorStatement()** ⚠️
   ```swift
   let closingBalance = investorCashBalanceService.getBalance(for: user.id) // ✅ Enthält bereits Wallet
   let walletTransactions = try await paymentService.getTransactionHistory(...) // ⚠️ Lädt Wallet NOCHMAL
   let allEntries = investmentLedger + walletEntries // ⚠️ Kombiniert manuell
   ```

3. **DashboardStatsViewModel.updateInvestorBalance()** ✅
   ```swift
   investorBalance = investorCashBalanceService.getFormattedBalance(for: currentUserId) // ✅ Korrekt
   ```

4. **WalletViewModel.getUserSpecificBalance()** ✅
   ```swift
   return investorService.getBalance(for: currentUser.id) // ✅ Korrekt
   ```

**Problem:** `AccountStatementViewModel.buildInvestorStatement()` lädt Wallet-Transaktionen separat, obwohl die Balance bereits Wallet enthält. Das ist inkonsistent mit der Trader-Implementierung.

---

### Trader Balance Berechnung

#### Aktuelle Implementierung (nach Refactoring):

1. **TraderAccountStatementBuilder.buildSnapshotWithWallet()** ✅
   - Single Source of Truth
   - Kombiniert Trading + Wallet

2. **AccountStatementViewModel.buildTraderStatement()** ✅
   ```swift
   let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(...) // ✅ Konsistent
   ```

3. **DashboardStatsViewModel.updateTraderAccountBalance()** ✅
   ```swift
   let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(...) // ✅ Konsistent
   ```

4. **WalletViewModel.getUserSpecificBalance()** ✅
   ```swift
   let snapshot = await TraderAccountStatementBuilder.buildSnapshotWithWallet(...) // ✅ Konsistent
   ```

**Status:** ✅ Konsistent - alle verwenden `buildSnapshotWithWallet()`

---

## ❌ DRY-Verletzungen

### 1. **Inkonsistente Architektur: Investor vs. Trader**

| Aspekt | Investor | Trader |
|--------|----------|--------|
| **Balance-Service** | `InvestorCashBalanceService` (enthält Wallet) | `TraderAccountStatementBuilder` (kombiniert Trading + Wallet) |
| **Wallet-Integration** | Direkt im Service (`processDeposit/Withdrawal`) | Externe Kombination (`buildSnapshotWithWallet`) |
| **Account Statement** | Lädt Wallet separat (redundant) | Verwendet zentrale Methode |
| **Konsistenz** | ❌ Inkonsistent | ✅ Konsistent |

### 2. **Code-Duplikation: Wallet-Loading**

**Investor:**
- `AccountStatementViewModel.buildInvestorStatement()` lädt Wallet-Transaktionen
- `TraderAccountStatementBuilder.buildSnapshotWithWallet()` lädt Wallet-Transaktionen
- **Duplikation:** Gleiche Logik an 2 Stellen

### 3. **Inkonsistente Balance-Berechnung**

**Investor:**
- Balance enthält bereits Wallet (via `processDeposit/Withdrawal`)
- Account Statement lädt Wallet zusätzlich separat
- **Problem:** Balance wird doppelt berücksichtigt (implizit im Service + explizit im ViewModel)

**Trader:**
- Balance wird zentral berechnet (Trading + Wallet)
- Account Statement verwendet zentrale Methode
- **Status:** ✅ Konsistent

---

## 🎯 Best Practices Verletzungen

### Accounting Principles
- ❌ **Single Source of Truth**: Investor-Balance wird unterschiedlich berechnet
- ❌ **Konsistenz**: Investor und Trader haben unterschiedliche Architekturen
- ❌ **Klarheit**: Investor-Balance enthält Wallet implizit, Trader explizit

### MVVM Principles
- ❌ **Separation of Concerns**: Investor-Balance-Logik ist im Service, Trader im Builder
- ⚠️ **Reusability**: Wallet-Loading-Logik ist dupliziert

### DRY Principles
- ❌ **Don't Repeat Yourself**: Wallet-Loading-Logik wird wiederholt
- ❌ **Single Responsibility**: Balance-Berechnung ist an mehreren Stellen

---

## ✅ Lösung: Konsistente Architektur

### Option 1: Investor-Balance-Service erweitern (Empfohlen)

**Vorteile:**
- ✅ Konsistent mit Trader-Architektur
- ✅ Single Source of Truth
- ✅ Klare Trennung: Service für Balance, Builder für Statements

**Implementierung:**
```swift
// In InvestorCashBalanceService
func getBalanceWithWallet(for investorId: String, paymentService: (any PaymentServiceProtocol)?) async -> Double {
    let baseBalance = getBalance(for: investorId)

    // Add wallet delta if payment service is available
    if let paymentService = paymentService {
        let walletTransactions = try? await paymentService.getTransactionHistory(...)
        let walletDelta = walletTransactions?.reduce(...) ?? 0.0
        return baseBalance + walletDelta
    }

    return baseBalance
}
```

**Problem:** Investor-Balance enthält bereits Wallet, also wäre das doppelt!

---

### Option 2: Investor-Balance-Service trennen (Besser)

**Vorgehen:**
1. `InvestorCashBalanceService` speichert nur Investment-Transaktionen
2. Wallet-Transaktionen werden separat geladen (wie bei Trader)
3. Balance wird kombiniert berechnet (wie bei Trader)

**Vorteile:**
- ✅ Konsistent mit Trader-Architektur
- ✅ Klare Trennung: Investment vs. Wallet
- ✅ Single Source of Truth für kombinierte Balance

**Nachteile:**
- ⚠️ Breaking Change: `processDeposit/Withdrawal` müsste angepasst werden
- ⚠️ Migration erforderlich

---

### Option 3: Investor-Balance-Builder erstellen (Empfohlen)

**Vorgehen:**
1. Erstelle `InvestorAccountStatementBuilder` (analog zu `TraderAccountStatementBuilder`)
2. Builder kombiniert Investment Ledger + Wallet Transactions
3. Alle ViewModels verwenden Builder

**Vorteile:**
- ✅ Konsistent mit Trader-Architektur
- ✅ Klare Trennung: Investment vs. Wallet
- ✅ Single Source of Truth
- ✅ Minimal invasive Änderung

**Implementierung:**
```swift
enum InvestorAccountStatementBuilder {
    static func buildSnapshotWithWallet(
        for user: User?,
        investorCashBalanceService: any InvestorCashBalanceServiceProtocol,
        paymentService: (any PaymentServiceProtocol)?
    ) async -> InvestorAccountStatementSnapshot {
        // Load investment transactions
        let investmentLedger = investorCashBalanceService.getTransactions(for: user.id)
        let baseBalance = investorCashBalanceService.getBalance(for: user.id)

        // Load wallet transactions
        var walletEntries: [AccountStatementEntry] = []
        var walletDelta: Double = 0.0

        if let paymentService = paymentService,
           let userId = user?.id {
            let walletTransactions = try? await paymentService.getTransactionHistory(...)
            let userWalletTransactions = walletTransactions?.filter { $0.userId == userId } ?? []

            walletEntries = userWalletTransactions.map { ... }
            walletDelta = userWalletTransactions.reduce(...) { ... }
        }

        // Combine
        let allEntries = investmentLedger + walletEntries
        let combinedBalance = baseBalance + walletDelta

        return InvestorAccountStatementSnapshot(
            entries: allEntries,
            openingBalance: ...,
            closingBalance: combinedBalance
        )
    }
}
```

---

## 📊 Vergleich: Aktuell vs. Empfohlen

| Aspekt | Aktuell | Empfohlen (Option 3) |
|--------|---------|---------------------|
| **Investor Balance** | Service (enthält Wallet) | Builder (kombiniert Investment + Wallet) |
| **Trader Balance** | Builder (kombiniert Trading + Wallet) | Builder (kombiniert Trading + Wallet) |
| **Konsistenz** | ❌ Inkonsistent | ✅ Konsistent |
| **Single Source of Truth** | ❌ Nein | ✅ Ja |
| **Wallet-Loading** | ⚠️ Dupliziert | ✅ Zentralisiert |
| **Wartbarkeit** | ❌ 2 Stellen ändern | ✅ 1 Stelle ändern |

---

## 🎯 Empfehlung

### ✅ **Option 3: InvestorAccountStatementBuilder erstellen**

**Warum:**
1. ✅ Konsistent mit Trader-Architektur
2. ✅ Klare Trennung: Investment vs. Wallet
3. ✅ Single Source of Truth
4. ✅ Minimal invasive Änderung
5. ✅ DRY-konform

**Implementierung:**
- Neue Datei: `InvestorAccountStatementBuilder.swift`
- Alle ViewModels verwenden `buildSnapshotWithWallet()`
- Entfernt Code-Duplikation
- Konsistente Architektur für Investor und Trader

---

## 🔄 Refactoring-Plan

1. **Erstelle InvestorAccountStatementBuilder**
   - Neue Methode `buildSnapshotWithWallet(...)`
   - Kombiniert Investment Ledger + Wallet Transactions

2. **Aktualisiere ViewModels**
   - `AccountStatementViewModel.buildInvestorStatement()`: Verwendet `buildSnapshotWithWallet()`
   - `DashboardStatsViewModel.updateInvestorBalance()`: Verwendet `buildSnapshotWithWallet()`
   - `WalletViewModel.getUserSpecificBalance()`: Verwendet `buildSnapshotWithWallet()`

3. **Entferne Duplikation**
   - Entferne manuelles Wallet-Loading aus `AccountStatementViewModel`
   - Zentralisiere Wallet-Loading in Builder

4. **Konsistenz prüfen**
   - Investor und Trader verwenden gleiche Architektur
   - Single Source of Truth für beide Rollen

---

**Erstellt**: Januar 2026
**Status**: Analyse - DRY-Verletzung identifiziert, Lösung vorgeschlagen ✅
