# Implementierung: Eindeutige Belegnummern für alle Belege

## Zusammenfassung

Alle Buchhaltungsbelege (Rechnungen, Rechnungen/Bills, Gutschriften) haben jetzt eindeutige Belegnummern gemäß den Grundsätzen ordnungsgemäßer Buchführung (GoB).

## Durchgeführte Änderungen

### 1. Document-Modell erweitert

**Datei**: `FIN1/Shared/Models/Document.swift`

- ✅ `documentNumber: String?` Feld hinzugefügt
- ✅ Automatische Zuordnung aus `invoiceData.invoiceNumber` falls vorhanden
- ✅ Helper-Properties `accountingDocumentNumber` und `hasAccountingDocumentNumber` hinzugefügt

### 2. Alle Buchhaltungsbelege aktualisiert

#### Rechnungen (Invoices)
**Datei**: `FIN1/Features/Trader/Services/TradingNotificationService.swift`
- ✅ `documentNumber: invoice.invoiceNumber` wird jetzt gesetzt

#### Trader Collection Bills
**Datei**: `FIN1/Features/Trader/Services/TradingNotificationService.swift`
- ✅ `documentNumber: documentId` wird jetzt gesetzt (generiert via `TransactionIdService.generateInvoiceNumber()`)

#### Gutschriften (Credit Notes)
**Datei**: `FIN1/Features/Trader/Services/TradingNotificationService.swift`
- ✅ `documentNumber: creditNoteInvoice.invoiceNumber` wird jetzt gesetzt

#### Investor Collection Bills
**Dateien**:
- `FIN1/Features/Investor/Services/InvestmentDocumentService.swift`
- `FIN1/Features/Investor/Services/InvestmentCreationService.swift`
- `FIN1/Features/Investor/Services/InvestorNotificationService.swift`

**Änderungen**:
- ✅ UUID-Generierung durch `TransactionIdService.generateInvestorDocumentNumber()` ersetzt
- ✅ `documentNumber` wird jetzt explizit gesetzt
- ✅ `InvestmentDocumentService` erhält jetzt `transactionIdService` als Dependency

#### Commission Invoices & Credit Notes
**Datei**: `FIN1/Shared/Services/CommissionSettlementService.swift`
- ✅ `documentNumber: invoice.invoiceNumber` wird jetzt gesetzt

#### Investor Service Charge Invoices
**Datei**: `FIN1/Features/Investor/Services/InvestmentCashDeductionProcessor.swift`
- ✅ `documentNumber: invoice.invoiceNumber` wird jetzt gesetzt

### 3. Service-Abhängigkeiten aktualisiert

**Datei**: `FIN1/Shared/Services/AppServicesBuilder.swift`
- ✅ `InvestmentDocumentService` erhält jetzt `transactionIdService` als Dependency

## Belegnummer-Formate

### Rechnungen & Gutschriften
- **Format**: `FIN1-INV-YYYYMMDD-XXXXX`
- **Beispiel**: `FIN1-INV-20250123-00001`
- **Generierung**: `TransactionIdService.generateInvoiceNumber()`

### Investor Collection Bills
- **Format**: `FIN1-INVST-YYYYMMDD-XXXXX`
- **Beispiel**: `FIN1-INVST-20250123-00001`
- **Generierung**: `TransactionIdService.generateInvestorDocumentNumber()`

## Compliance mit GoB

✅ **Eindeutigkeit**: Alle Belegnummern sind eindeutig (via TransactionIdService mit täglichen Zählern)
✅ **Fortlaufend**: Belegnummern sind fortlaufend pro Tag
✅ **Nachvollziehbar**: Strukturiertes Format mit Datum und Sequenznummer
✅ **Unveränderlich**: `documentNumber` ist ein `let`-Feld (immutable)

## Rückwärtskompatibilität

- ✅ Bestehende Dokumente ohne `documentNumber` funktionieren weiterhin
- ✅ `documentNumber` ist optional (`String?`)
- ✅ Automatische Fallback-Logik: Falls `documentNumber` nicht gesetzt, wird `invoiceData.invoiceNumber` verwendet

## Nächste Schritte (Optional)

1. **Migration**: Bestehende Dokumente ohne `documentNumber` könnten nachträglich befüllt werden
2. **Validierung**: Validierungslogik könnte hinzugefügt werden, um sicherzustellen, dass alle Buchhaltungsbelege eine Belegnummer haben
3. **UI-Anzeige**: Belegnummern könnten in der UI angezeigt werden

## Getestete Dateien

- ✅ `Document.swift` - Modell-Erweiterung
- ✅ `TradingNotificationService.swift` - Invoice, Collection Bill, Credit Note
- ✅ `InvestmentDocumentService.swift` - Investor Collection Bills
- ✅ `InvestmentCreationService.swift` - Investor Collection Bills
- ✅ `InvestorNotificationService.swift` - Investor Collection Bills
- ✅ `CommissionSettlementService.swift` - Credit Notes & Commission Invoices
- ✅ `InvestmentCashDeductionProcessor.swift` - Service Charge Invoices
- ✅ `AppServicesBuilder.swift` - Service-Dependency-Update
