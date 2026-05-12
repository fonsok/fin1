# Code Review: DRY Refactoring & Balance Calculation Fixes

**Datum**: Januar 2026
**Review Scope**: Implementierungen aus diesem Chat (DRY-Violations, Balance-Berechnung)

---

## 📋 Implementierte Änderungen

### 1. **InvestorAccountStatementBuilder** (Neu)
- Single Source of Truth für Investor-Balance-Berechnung
- Kombiniert Investment Ledger + Wallet Transactions
- Berechnet `balanceAfter` chronologisch neu

### 2. **TraderAccountStatementBuilder.buildSnapshotWithWallet()** (Erweitert)
- Berechnet `balanceAfter` chronologisch neu
- Sortiert Entries im Builder (nicht im ViewModel)

### 3. **AccountStatementViewModel** (Aktualisiert)
- Verwendet zentrale Builder-Methoden
- Entfernt doppelte Sortierung

### 4. **DashboardStatsViewModel** (Aktualisiert)
- Verwendet `InvestorAccountStatementBuilder.buildSnapshotWithWallet()`
- Konsistente Balance-Berechnung für Investor

### 5. **WalletViewModel** (Aktualisiert)
- Verwendet zentrale Builder-Methoden für beide Rollen

---

## ✅ SwiftUI Best Practices

### ✅ **Was richtig ist:**

1. **Async/Await Patterns** ✅
   ```swift
   // ✅ CORRECT: Proper async/await usage
   static func buildSnapshotWithWallet(...) async -> InvestorAccountStatementSnapshot
   ```
   - Verwendet moderne Swift Concurrency
   - Keine Completion Handlers
   - **Cursor Rule Compliance**: ✅ "Prefer async/await patterns"

2. **MainActor Isolation** ✅
   ```swift
   // ✅ CORRECT: UI updates on main thread
   await MainActor.run {
       openingBalance = snapshot.openingBalance
       currentBalance = snapshot.closingBalance
   }
   ```
   - ViewModels sind `@MainActor`
   - UI-Updates explizit auf Main Thread
   - **Cursor Rule Compliance**: ✅ Thread safety

3. **State Management** ✅
   - `@Published` properties korrekt verwendet
   - ViewModels als `final class` mit `ObservableObject`
   - **Cursor Rule Compliance**: ✅ MVVM patterns

4. **Separation of Concerns** ✅
   - Builder-Methoden sind statisch (keine State)
   - ViewModels koordinieren nur, keine Business Logic
   - **Cursor Rule Compliance**: ✅ "Business logic in services, not ViewModels"

### ⚠️ **Verbesserungspotenzial:**

1. **Error Handling** ⚠️
   ```swift
   // ⚠️ CURRENT: print() statt proper error handling
   print("⚠️ InvestorAccountStatementBuilder: Failed to load wallet transactions: \(error.localizedDescription)")
   ```
   - **Problem**: Fehler werden nur geloggt, nicht propagiert
   - **Empfehlung**: `AppError` verwenden und an ViewModel weitergeben
   - **Cursor Rule**: ❌ "Use `AppError` enum for all error types"

2. **Error Propagation** ⚠️
   ```swift
   // ⚠️ CURRENT: Silent failure
   } catch {
       print("⚠️ ...")
       // Continue without wallet transactions if loading fails
   }
   ```
   - **Problem**: Fehler werden verschluckt
   - **Empfehlung**: Optional return type oder `Result` verwenden
   - **Cursor Rule**: ❌ "Avoid generic error handling"

---

## ✅ MVVM Architecture Principles

### ✅ **Was richtig ist:**

1. **Dependency Injection** ✅
   ```swift
   // ✅ CORRECT: Protocol-based dependencies
   init(services: AppServices) {
       self.investorCashBalanceService = services.investorCashBalanceService
       self.paymentService = services.paymentService
   }
   ```
   - Services werden über Protokolle injiziert
   - Keine Singletons in ViewModels
   - **Cursor Rule Compliance**: ✅ "Services implement protocols, not concrete types"

2. **Single Source of Truth** ✅
   ```swift
   // ✅ CORRECT: Centralized balance calculation
   let snapshot = await InvestorAccountStatementBuilder.buildSnapshotWithWallet(...)
   ```
   - Balance-Berechnung zentralisiert
   - Keine Duplikation
   - **Cursor Rule Compliance**: ✅ DRY principles

3. **ViewModel Responsibilities** ✅
   - ViewModels koordinieren nur
   - Business Logic in Builders/Services
   - **Cursor Rule Compliance**: ✅ "ViewModels depend on protocols, not concrete services"

4. **Data Processing** ✅
   ```swift
   // ✅ CORRECT: Data processing in Builder, not ViewModel
   let sortedEntries = allEntries.sorted { $0.occurredAt < $1.occurredAt }
   ```
   - Sortierung im Builder
   - ViewModel verwendet bereits verarbeitete Daten
   - **Cursor Rule Compliance**: ✅ "No data processing in Views"

### ⚠️ **Verbesserungspotenzial:**

1. **ViewModel File Size** ⚠️
   - `AccountStatementViewModel`: 164 Zeilen ✅ (≤ 400)
   - `DashboardStatsViewModel`: ~330 Zeilen ✅ (≤ 400)
   - `WalletViewModel`: ~260 Zeilen ✅ (≤ 400)
   - **Status**: ✅ Alle unter Limit

2. **Function Length** ⚠️
   ```swift
   // ⚠️ CURRENT: buildSnapshotWithWallet() ist ~80 Zeilen
   static func buildSnapshotWithWallet(...) async -> InvestorAccountStatementSnapshot {
       // ... 80+ lines
   }
   ```
   - **Problem**: Funktion ist > 50 Zeilen
   - **Cursor Rule**: ❌ "Keep functions under 50 lines"
   - **Empfehlung**: In kleinere Helper-Methoden aufteilen

---

## ✅ Principles of Proper Accounting

### ✅ **Was richtig ist:**

1. **Chronological Balance Calculation** ✅
   ```swift
   // ✅ CORRECT: Balance calculated in chronological order
   let sortedEntries = allEntries.sorted { $0.occurredAt < $1.occurredAt }
   var runningBalance = openingBalance
   for entry in sortedEntries {
       runningBalance += entry.signedAmount
       // balanceAfter = runningBalance
   }
   ```
   - Balance wird chronologisch berechnet
   - Jeder Entry hat korrekten `balanceAfter` Wert
   - **Accounting Principle**: ✅ "Running balance must reflect chronological order"

2. **Single Source of Truth** ✅
   - Balance-Berechnung zentralisiert
   - Keine Duplikation zwischen ViewModels
   - **Accounting Principle**: ✅ "One authoritative source for financial calculations"

3. **Opening Balance Calculation** ✅
   ```swift
   // ✅ CORRECT: Opening balance calculated from all transactions
   let totalDelta = allEntries.reduce(0.0) { $0 + $1.signedAmount }
   let calculatedOpening = serviceBalance - totalDelta
   ```
   - Opening Balance wird korrekt berechnet
   - Berücksichtigt alle Transaktionen
   - **Accounting Principle**: ✅ "Opening balance = Closing balance - Total delta"

4. **Transaction Combination** ✅
   ```swift
   // ✅ CORRECT: Investment + Wallet transactions combined
   let allEntries = investmentLedger + walletEntries
   ```
   - Alle Transaktionen werden kombiniert
   - Keine Duplikation
   - **Accounting Principle**: ✅ "All transactions must be included in statement"

### ⚠️ **Verbesserungspotenzial:**

1. **Balance Validation** ⚠️
   ```swift
   // ⚠️ CURRENT: No validation that calculated balance matches service balance
   let combinedClosingBalance = serviceBalance
   ```
   - **Problem**: Keine Validierung, ob berechnete Balance mit Service-Balance übereinstimmt
   - **Empfehlung**: Assertion oder Logging hinzufügen
   - **Accounting Principle**: ⚠️ "Balances should be validated"

2. **Transaction Deduplication** ⚠️
   - **Problem**: Keine explizite Deduplizierung
   - **Empfehlung**: Prüfen, ob Wallet-Transaktionen nicht bereits im Ledger sind
   - **Accounting Principle**: ⚠️ "No duplicate transactions in statement"

---

## ✅ Project Cursor Rules

### ✅ **Was richtig ist:**

1. **DRY Principles** ✅
   - Single Source of Truth implementiert
   - Keine Code-Duplikation
   - **Cursor Rule Compliance**: ✅ "No DRY violations"

2. **Class vs Struct** ✅
   ```swift
   // ✅ CORRECT: Builder is enum (value type)
   enum InvestorAccountStatementBuilder {
       static func buildSnapshotWithWallet(...) async -> InvestorAccountStatementSnapshot
   }
   ```
   - Builder ist `enum` (statische Methoden)
   - Snapshot ist `struct` (value type)
   - **Cursor Rule Compliance**: ✅ "Models use struct"

3. **File Size Limits** ✅
   - `InvestorAccountStatementBuilder`: 106 Zeilen ✅ (≤ 400)
   - `TraderAccountStatementBuilder`: ~315 Zeilen ✅ (≤ 400)
   - **Cursor Rule Compliance**: ✅ "All classes ≤ 400 lines"

4. **Naming Conventions** ✅
   - Builder-Pattern korrekt verwendet
   - Klare, beschreibende Namen
   - **Cursor Rule Compliance**: ✅ "Use meaningful names"

5. **Async/Await** ✅
   - Moderne Swift Concurrency
   - Keine Completion Handlers
   - **Cursor Rule Compliance**: ✅ "Prefer async/await patterns"

### ❌ **Cursor Rule Violations:**

1. **Magic Numbers** ❌
   ```swift
   // ❌ VIOLATION: Magic number
   let initialBalance = 25000.0 // Default initial investor balance
   ```
   - **Problem**: Hardcoded Wert
   - **Cursor Rule**: ❌ "All magic numbers must be defined as constants"
   - **Empfehlung**: In `CalculationConstants` oder `ConfigurationService` verschieben
   - **Fix**:
   ```swift
   // ✅ CORRECT: Use constant
   let initialBalance = configurationService.initialInvestorBalance
   ```

2. **Error Handling** ❌
   ```swift
   // ❌ VIOLATION: print() statt AppError
   print("⚠️ InvestorAccountStatementBuilder: Failed to load wallet transactions: \(error.localizedDescription)")
   ```
   - **Problem**: Fehler werden nicht als `AppError` behandelt
   - **Cursor Rule**: ❌ "Use `AppError` enum for all error types"
   - **Empfehlung**: `AppError` verwenden und propagieren

3. **Function Length** ❌
   ```swift
   // ❌ VIOLATION: Function > 50 lines
   static func buildSnapshotWithWallet(...) async -> InvestorAccountStatementSnapshot {
       // ... 80+ lines
   }
   ```
   - **Problem**: Funktion ist > 50 Zeilen
   - **Cursor Rule**: ❌ "Keep functions under 50 lines"
   - **Empfehlung**: In Helper-Methoden aufteilen:
     - `loadWalletEntries()`
     - `recalculateBalanceAfter()`
     - `combineAndSortEntries()`

---

## 📊 Zusammenfassung

### ✅ **Stärken:**

1. ✅ **DRY Principles**: Single Source of Truth implementiert
2. ✅ **MVVM Architecture**: Korrekte Dependency Injection
3. ✅ **SwiftUI Best Practices**: Async/await, MainActor korrekt
4. ✅ **Accounting Principles**: Chronologische Balance-Berechnung
5. ✅ **File Size**: Alle Dateien unter Limit

### ❌ **Kritische Probleme:**

1. ❌ **Magic Numbers**: `25000.0` sollte Konstante sein
2. ❌ **Error Handling**: `print()` statt `AppError`
3. ❌ **Function Length**: Funktionen > 50 Zeilen

### ⚠️ **Verbesserungspotenzial:**

1. ⚠️ **Balance Validation**: Keine Validierung der berechneten Balance
2. ⚠️ **Transaction Deduplication**: Keine explizite Deduplizierung
3. ⚠️ **Error Propagation**: Fehler werden verschluckt

---

## 🔧 Empfohlene Fixes

### 1. **Magic Number entfernen**
```swift
// ❌ CURRENT
let initialBalance = 25000.0

// ✅ FIXED
let initialBalance = configurationService.initialInvestorBalance
```

### 2. **Error Handling verbessern**
```swift
// ❌ CURRENT
} catch {
    print("⚠️ ...")
    // Continue without wallet transactions
}

// ✅ FIXED
} catch {
    // Log error
    print("⚠️ InvestorAccountStatementBuilder: Failed to load wallet transactions: \(error.localizedDescription)")
    // Return error or use Result type
    throw AppError.service(.dataLoadFailed(error.localizedDescription))
}
```

### 3. **Function Length reduzieren**
```swift
// ✅ FIXED: Split into helper methods
static func buildSnapshotWithWallet(...) async -> InvestorAccountStatementSnapshot {
    let investmentLedger = investorCashBalanceService.getTransactions(for: user.id)
    let serviceBalance = investorCashBalanceService.getBalance(for: user.id)
    let walletEntries = await loadWalletEntries(for: user, paymentService: paymentService)
    let allEntries = investmentLedger + walletEntries
    let openingBalance = calculateOpeningBalance(serviceBalance: serviceBalance, entries: allEntries)
    let recalculatedEntries = recalculateBalanceAfter(entries: allEntries, openingBalance: openingBalance)
    return InvestorAccountStatementSnapshot(
        entries: recalculatedEntries.sorted { $0.occurredAt > $1.occurredAt },
        openingBalance: openingBalance,
        closingBalance: serviceBalance
    )
}

private static func loadWalletEntries(...) async -> [AccountStatementEntry] { ... }
private static func calculateOpeningBalance(...) -> Double { ... }
private static func recalculateBalanceAfter(...) -> [AccountStatementEntry] { ... }
```

---

**Review Status**: ⚠️ **Gut, aber Verbesserungen erforderlich**
**Priorität**: 🔴 **Hoch** (Magic Numbers, Error Handling)
**Nächste Schritte**: Fixes für Magic Numbers und Error Handling implementieren
