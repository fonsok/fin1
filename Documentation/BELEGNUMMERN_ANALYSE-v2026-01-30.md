# Analyse: Eindeutige Belegnummern für alle Belege

## Zusammenfassung

Diese Analyse prüft, ob alle Belege (Rechnungen, Rechnungen/Bills, Gutschriften) gemäß den Prinzipien ordnungsgemäßer Buchführung eindeutige Belegnummern/-IDs haben.

## Aktueller Status

### ✅ Rechnungen (Invoices)
- **Status**: ✅ Hat eindeutige Belegnummer
- **Feld**: `Invoice.invoiceNumber: String`
- **Generierung**: `TransactionIdService.generateInvoiceNumber()` → Format: `FIN1-INV-YYYYMMDD-XXXXX`
- **Speicherung**: Direkt im Invoice-Modell

### ✅ Gutschriften (Credit Notes)
- **Status**: ✅ Hat eindeutige Belegnummer
- **Feld**: `Invoice.invoiceNumber: String` (Credit Notes sind Invoice-Objekte mit `type: .creditNote`)
- **Generierung**: `TransactionIdService.generateInvoiceNumber()` → Format: `FIN1-INV-YYYYMMDD-XXXXX`
- **Speicherung**: Im Invoice-Modell, das in `Document.invoiceData` gespeichert wird

### ⚠️ Trader Collection Bills
- **Status**: ⚠️ **PROBLEM**: Belegnummer wird generiert, aber nicht als strukturiertes Feld gespeichert
- **Generierung**: `TransactionIdService.generateInvoiceNumber()` → Format: `FIN1-INV-YYYYMMDD-XXXXX`
- **Aktuelle Speicherung**:
  - Nur in `Document.fileURL` (z.B. `"collectionbill://\(documentId).pdf"`)
  - Nur in `Document.name` (via `DocumentNamingUtility`)
  - **NICHT** als separates Feld im Document-Modell

### ⚠️ Investor Collection Bills
- **Status**: ⚠️ **PROBLEM**: Inkonsistente Belegnummer-Generierung
- **Generierung**: 
  - `UUID().uuidString` (in `InvestmentCreationService`, `InvestmentDocumentService`)
  - `TransactionIdService.generateInvestorDocumentNumber()` (in `InvestorNotificationService`) → Format: `FIN1-INVST-YYYYMMDD-XXXXX`
- **Aktuelle Speicherung**:
  - Nur in `Document.fileURL` (z.B. `"investment://\(documentId).pdf"` oder `"collectionbill://\(documentId).pdf"`)
  - Nur in `Document.name` (via `DocumentNamingUtility`)
  - **NICHT** als separates Feld im Document-Modell

## Problem

Das `Document`-Modell hat **KEIN** `documentNumber`-Feld. Für ordnungsgemäße Buchführung sollten **ALLE** Belege eine explizite, eindeutige Belegnummer als strukturiertes Feld haben, nicht nur eingebettet in Dateinamen oder URLs.

### Auswirkungen

1. **Schlechte Nachverfolgbarkeit**: Belegnummern sind schwer zu extrahieren und zu durchsuchen
2. **Verstoß gegen GoB**: Gemäß den Grundsätzen ordnungsgemäßer Buchführung müssen alle Belege eindeutig identifizierbar sein
3. **Inkonsistenz**: Unterschiedliche Generierungsmethoden (UUID vs. strukturierte IDs)
4. **Schwierige Validierung**: Keine einfache Möglichkeit, Duplikate zu erkennen

## Lösung

### 1. Document-Modell erweitern

Füge `documentNumber: String?` zum `Document`-Modell hinzu:

```swift
struct Document: Identifiable, Codable, Hashable {
    // ... bestehende Felder ...
    let documentNumber: String?  // Eindeutige Belegnummer für Buchhaltungsbelege
}
```

### 2. Belegnummer-Zuordnung

- **Invoices/Credit Notes**: Verwende `invoiceData.invoiceNumber` als `documentNumber`
- **Trader Collection Bills**: Verwende generierte `documentId` als `documentNumber`
- **Investor Collection Bills**: Verwende `generateInvestorDocumentNumber()` (nicht UUID)

### 3. Alle Erstellungsstellen aktualisieren

Folgende Dateien müssen aktualisiert werden:
- `TradingNotificationService.swift` - Invoice, Collection Bill, Credit Note
- `InvestmentDocumentService.swift` - Investor Collection Bills
- `InvestmentCreationService.swift` - Investor Collection Bills
- `InvestorNotificationService.swift` - Investor Collection Bills
- `CommissionSettlementService.swift` - Credit Notes
- `InvestmentCashDeductionProcessor.swift` - Invoices

## Compliance mit GoB

Gemäß den Grundsätzen ordnungsgemäßer Buchführung (GoB) müssen:
- ✅ Alle Belege eindeutig identifizierbar sein
- ✅ Belegnummern fortlaufend und lückenlos sein
- ✅ Belegnummern nachvollziehbar sein
- ✅ Belegnummern nicht verändert werden können

Die vorgeschlagene Lösung erfüllt alle diese Anforderungen.
