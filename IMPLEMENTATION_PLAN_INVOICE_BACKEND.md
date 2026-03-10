# 🎯 Implementierungsplan: Invoice Service Backend-Integration

**Datum:** 2026-02-05
**Ziel:** Vollständige Backend-Integration für alle Invoice-Typen
**Aufwand:** 2-3 Tage

---

## 📋 Aktueller Status

✅ **Vorhanden:**
- `InvoiceService` mit `parseAPIClient` Property
- Service Charge Invoice Backend-Integration (via Cloud Function)
- Parse Server Invoice Klasse existiert (`backend/parse-server/cloud/triggers/order.js`)
- PostgreSQL Invoice Schema existiert (`backend/postgres/init/007_schema_finance.sql`)

❌ **Fehlt:**
- `InvoiceAPIService` für direkte Parse-Klasse-Interaktion
- Buy/Sell Invoice Synchronisation
- `syncToBackend()` Methode
- Invoice-Loading vom Backend

---

## 🏗️ Implementierungsschritte

### Schritt 1: InvoiceAPIService erstellen (4-6 Stunden)

**Datei:** `FIN1/Features/Trader/Services/InvoiceAPIService.swift`

**Pattern:** Analog zu `InvestmentAPIService.swift`

**Struktur:**
```swift
protocol InvoiceAPIServiceProtocol {
    func saveInvoice(_ invoice: Invoice) async throws -> Invoice
    func updateInvoice(_ invoice: Invoice) async throws -> Invoice
    func fetchInvoices(for userId: String) async throws -> [Invoice]
    func deleteInvoice(_ invoiceId: String) async throws
}

final class InvoiceAPIService: InvoiceAPIServiceProtocol {
    private let apiClient: ParseAPIClientProtocol

    // Parse Invoice Input/Output Models
    // Mapping zwischen Invoice (App) ↔ ParseInvoice (Backend)
}
```

**Parse Invoice Schema (basierend auf order.js):**
- `invoiceNumber`: String
- `invoiceType`: String (buy_invoice, sell_invoice, platformServiceCharge)
- `userId`: String
- `orderId`: String?
- `tradeId`: String?
- `subtotal`: Double
- `totalFees`: Double
- `totalAmount`: Double
- `invoiceDate`: Date
- `status`: String (issued, paid, cancelled)

---

### Schritt 2: InvoiceService erweitern (2-3 Stunden)

**Datei:** `FIN1/Features/Trader/Services/InvoiceService.swift`

**Änderungen:**
1. `invoiceAPIService` Property hinzufügen
2. `configure(invoiceAPIService:)` Methode hinzufügen
3. `syncToBackend()` Methode implementieren
4. Buy/Sell Invoice Synchronisation in `addInvoice()` hinzufügen

**Code-Beispiel:**
```swift
final class InvoiceService: InvoiceServiceProtocol {
    private var invoiceAPIService: InvoiceAPIServiceProtocol?

    func configure(invoiceAPIService: InvoiceAPIServiceProtocol) {
        self.invoiceAPIService = invoiceAPIService
    }

    func syncToBackend() async {
        guard let apiService = invoiceAPIService else { return }

        // Sync pending invoices (ohne objectId oder mit local- prefix)
        let pendingInvoices = invoices.filter { invoice in
            invoice.id.starts(with: "local-") ||
            !invoice.id.contains("-") // UUID ohne Parse objectId
        }

        for invoice in pendingInvoices {
            do {
                let syncedInvoice = try await apiService.saveInvoice(invoice)
                // Update local invoice with objectId
                await updateLocalInvoice(invoice.id, with: syncedInvoice)
            } catch {
                print("⚠️ Failed to sync invoice \(invoice.invoiceNumber): \(error)")
            }
        }
    }

    func addInvoice(_ invoice: Invoice) async {
        // Write-through: Sync immediately if API service available
        if let apiService = invoiceAPIService {
            do {
                let syncedInvoice = try await apiService.saveInvoice(invoice)
                await MainActor.run {
                    self.invoices.append(syncedInvoice)
                }
                return
            } catch {
                print("⚠️ Failed to sync invoice immediately: \(error)")
                // Fall through to local-only storage
            }
        }

        // Fallback: Local storage only
        await MainActor.run {
            self.invoices.append(invoice)
        }
    }
}
```

---

### Schritt 3: Invoice-Loading vom Backend (2-3 Stunden)

**Datei:** `FIN1/Features/Trader/Services/InvoiceService.swift`

**Änderungen:**
- `loadInvoices(for userId:)` erweitern um Backend-Loading

**Code-Beispiel:**
```swift
func loadInvoices(for userId: String) async throws {
    await MainActor.run {
        isLoading = true
    }

    // Try loading from backend first
    if let apiService = invoiceAPIService {
        do {
            let backendInvoices = try await apiService.fetchInvoices(for: userId)
            await MainActor.run {
                self.invoices = backendInvoices
                self.isLoading = false
            }
            return
        } catch {
            print("⚠️ Failed to load invoices from backend: \(error)")
            // Fall through to mock/fallback
        }
    }

    // Fallback: Load mock invoices or empty
    await MainActor.run {
        self.isLoading = false
        self.loadMockInvoices() // Or keep empty if no mocks needed
    }
}
```

---

### Schritt 4: AppServicesBuilder Integration (1 Stunde)

**Datei:** `FIN1/Shared/Services/AppServicesBuilder.swift`

**Änderungen:**
1. `InvoiceAPIService` erstellen
2. `InvoiceService` mit `InvoiceAPIService` konfigurieren

**Code-Beispiel:**
```swift
// In buildLiveServices()
let invoiceAPIService = InvoiceAPIService(apiClient: parseAPIClient)
let invoiceService = InvoiceService(
    transactionIdService: transactionIdService,
    parseAPIClient: parseAPIClient
)
invoiceService.configure(invoiceAPIService: invoiceAPIService)
```

---

### Schritt 5: Background-Sync Integration (30 Minuten)

**Datei:** `FIN1/FIN1App.swift`

**Änderungen:**
- `invoiceService.syncToBackend()` zum Background-Sync hinzufügen

**Code-Beispiel:**
```swift
// In syncPendingDataToBackend()
await withTaskGroup(of: Void.self) { group in
    // ... existing services ...
    group.addTask { await self.services.invoiceService.syncToBackend() } // ✅ Neu
}
```

---

## 🧪 Testing-Strategie

### Unit Tests
- `InvoiceAPIService` Mock-Tests
- `InvoiceService.syncToBackend()` Tests
- Invoice-Mapping Tests (App ↔ Parse)

### Integration Tests
- Invoice-Create vom Backend
- Invoice-Update Synchronisation
- Invoice-Loading vom Backend
- Background-Sync Verhalten

### Regression Tests
- Invoice-Generierung für Trades bleibt funktional
- Service Charge Invoice Integration bleibt funktional
- PDF-Generierung bleibt funktional

---

## 📝 Checkliste

- [ ] `InvoiceAPIService.swift` erstellen
- [ ] `ParseInvoice` Input/Output Models erstellen
- [ ] `InvoiceService.configure(invoiceAPIService:)` hinzufügen
- [ ] `InvoiceService.syncToBackend()` implementieren
- [ ] Buy/Sell Invoice Synchronisation in `addInvoice()`
- [ ] `loadInvoices()` Backend-Integration
- [ ] `AppServicesBuilder` Integration
- [ ] Background-Sync Integration in `FIN1App.swift`
- [ ] Unit Tests schreiben
- [ ] Integration Tests schreiben
- [ ] Dokumentation aktualisieren

---

## 🎯 Erfolgs-Kriterien

- ✅ Alle Invoice-Typen werden synchronisiert (Buy, Sell, Service Charge)
- ✅ Invoices werden beim Erstellen sofort synchronisiert (Write-through)
- ✅ Invoices werden beim App-Start vom Backend geladen
- ✅ Background-Sync funktioniert für pending Invoices
- ✅ Bestehende Funktionalität bleibt erhalten (Regression)

---

**Bereit zum Start?** 🚀
