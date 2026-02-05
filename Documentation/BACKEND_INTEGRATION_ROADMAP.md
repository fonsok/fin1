# Backend-Integration Roadmap

**Datum**: 2026-02-05
**Status**: ✅ Alle Phasen abgeschlossen

---

## Übersicht

| Phase | Services | Status |
|-------|----------|--------|
| **Phase 1** | Trade, Investment, Order, Pool Participation | ✅ Abgeschlossen |
| **Phase 2** | Wallet, Documents, User Profile | ✅ Abgeschlossen |
| **Phase 3** | Securities Watchlist, Saved Filters, Push Tokens | ✅ Abgeschlossen |
| **Phase 4** | Price Alerts, Investor Watchlist | ✅ Abgeschlossen |

**App-Lifecycle Hook**: ✅ Alle Services synchronisieren parallel bei App-Background

---

## ✅ Phase 1: Abgeschlossen

| Service | Sync-Typ | Parse Klasse |
|---------|----------|--------------|
| `TradeAPIService` | Write-through | `Trade` |
| `InvestmentAPIService` | Write-through + Background | `Investment` |
| `OrderAPIService` | Write-through + Background | `Order` |
| `PoolTradeParticipationService` | Write-through | `PoolTradeParticipation` |

---

## ✅ Phase 2: Abgeschlossen

| Service | Sync-Typ | Parse Klasse |
|---------|----------|--------------|
| `MockPaymentService` | Write-through + Background | `WalletTransaction` |
| `DocumentAPIService` | Write-through + Background | `Document` |
| `UserService` | Write-through + Background | `_User` |

---

## ✅ Phase 3: Abgeschlossen

| Service | Sync-Typ | Parse Klasse |
|---------|----------|--------------|
| `WatchlistAPIService` | Write-through + Background | `Watchlist` |
| `FilterAPIService` | Write-through + Background | `SavedFilter` |
| `PushTokenAPIService` | Write-through + Background | `PushToken` |

---

## ✅ Phase 4: Abgeschlossen

| Service | Sync-Typ | Parse Klasse |
|---------|----------|--------------|
| `PriceAlertService` | Write-through + Background + Live Query | `PriceAlert` |
| `InvestorWatchlistAPIService` | Write-through + Background | `InvestorWatchlist` |

---

## 💡 Architektur-Pattern

Alle API-Services folgen dem etablierten Pattern:

```swift
protocol XAPIServiceProtocol {
    func saveX(_ x: X) async throws -> X
    func updateX(_ x: X) async throws -> X
    func fetchX(for userId: String) async throws -> [X]
    func deleteX(_ id: String) async throws
}

final class XAPIService: XAPIServiceProtocol {
    private let apiClient: ParseAPIClientProtocol
    // Implementation...
}
```

**Integration:**
- Service erweitern mit `syncToBackend()` Methode
- Write-through in CRUD-Methoden
- Background-Sync im App-Lifecycle Hook (`FIN1App.swift`)

---

## 📋 Synchronisierte Services im App-Lifecycle

Bei App-Background werden folgende Services parallel synchronisiert:

1. `investmentService.syncToBackend()`
2. `orderManagementService.syncToBackend()`
3. `paymentService.syncToBackend()`
4. `documentService.syncToBackend()`
5. `userService.syncToBackend()`
6. `securitiesWatchlistService.syncToBackend()`
7. `filterSyncService.syncToBackend()`
8. `notificationService.syncPushTokensToBackend()`
9. `priceAlertService.syncToBackend()`
10. `watchlistService.syncToBackend()` (Investor Watchlist)

---

## 📝 Parse Klassen (Backend)

| Klasse | Beschreibung | Schema vorhanden |
|--------|--------------|------------------|
| `Trade` | Abgeschlossene Trades | ✅ |
| `Investment` | Investor-Investments | ✅ |
| `Order` | Kauf-/Verkaufsaufträge | ✅ |
| `PoolTradeParticipation` | Pool-Beteiligungen | ✅ |
| `WalletTransaction` | Wallet-Transaktionen | ✅ |
| `Document` | Dokumente | ✅ |
| `_User` | Benutzerprofile | ✅ (Parse built-in) |
| `Watchlist` | Securities Watchlist | ✅ (erstellt 2026-02-05) |
| `SavedFilter` | Gespeicherte Filter | ✅ (erstellt 2026-02-05) |
| `PushToken` | Push-Tokens | ✅ (erstellt 2026-02-05) |
| `PriceAlert` | Preisalarme | ✅ |
| `InvestorWatchlist` | Trader-Watchlist | ✅ (erstellt 2026-02-05) |

---

## 🚀 Deployment-Status

**Parse Server**: Schemas erfolgreich initialisiert via `initializeNewSchemas` Cloud Function (2026-02-05)
