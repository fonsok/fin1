# TPPDF Integration Guide (Optional)

## Übersicht

TPPDF ist eine Swift-Bibliothek für professionelle PDF-Generierung. Diese Anleitung zeigt, wie TPPDF in FIN1 integriert werden kann für noch professionellere PDFs.

## Vorteile von TPPDF

- ✅ Sehr professionelle Tabellen
- ✅ Einfache Layout-Gestaltung
- ✅ Gute Dokumentation
- ✅ Swift-native
- ✅ Kostenlos (Open Source)

## Installation

### Schritt 1: Swift Package Manager

1. Öffnen Sie das Xcode-Projekt
2. File → Add Packages...
3. URL eingeben: `https://github.com/techprimate/TPPDF`
4. Version: Latest (2.x)
5. Add to Target: FIN1

### Schritt 2: Import hinzufügen

In den Dateien, die TPPDF verwenden:

```swift
import TPPDF
```

## Implementierung

### Beispiel: Invoice mit TPPDF

```swift
import TPPDF

struct TPPDFInvoiceGenerator {

    static func generatePDF(from invoice: Invoice) -> Data {
        // Create document with A4 format
        let document = PDFDocument(format: .a4)

        // Add header
        document.add(.headerLeft, text: PDFCompanyInfo.companyName)
        document.add(.headerCenter, text: "Wertpapierabrechnung")
        document.add(.headerRight, text: invoice.formattedInvoiceNumber)

        // Add spacing
        document.add(.contentCenter, space: 20)

        // Add customer info
        document.add(.contentLeft, text: "Rechnungsempfänger")
        document.add(.contentLeft, text: invoice.customerInfo.name)
        document.add(.contentLeft, text: invoice.customerInfo.address)

        // Add table
        let table = PDFTable()
        table.headers = PDFTableConfigImproved.columnTitles

        // Add rows
        for item in invoice.items {
            table.addRow([
                item.description,
                item.quantity.formattedAsLocalizedInteger(),
                item.unitPrice.formattedAsLocalizedCurrency(),
                item.totalAmount.formattedAsLocalizedCurrency(),
                item.itemType.displayName
            ])
        }

        document.add(.contentCenter, table: table)

        // Add totals
        document.add(.contentRight, text: "Zwischensumme: \(invoice.formattedSubtotal)")
        if invoice.totalTax > 0 {
            document.add(.contentRight, text: "Steuer: \(invoice.formattedTaxAmount)")
        }
        document.add(.contentRight, text: "Gesamtbetrag: \(invoice.formattedTotalAmount)")

        // Generate PDF
        let generator = PDFGenerator(document: document)
        do {
            let pdfData = try generator.generateData()
            return pdfData
        } catch {
            print("❌ TPPDF generation failed: \(error)")
            // Fallback to improved PDFKit version
            return PDFCoreGeneratorImproved.generatePDF(from: invoice)
        }
    }
}
```

## Integration in PDFGenerator

```swift
// In PDFGenerator.swift
static var useTPPDF: Bool = false // Toggle für TPPDF

static func generatePDF(from invoice: Invoice) -> Data {
    if useTPPDF {
        return TPPDFInvoiceGenerator.generatePDF(from: invoice)
    } else if useImprovedGeneration {
        return PDFCoreGeneratorImproved.generatePDF(from: invoice)
    } else {
        return PDFCoreGenerator.generatePDF(from: invoice)
    }
}
```

## Vorteile vs. Aktuelle Lösung

| Feature | Aktuell (PDFKit) | TPPDF |
|---------|------------------|-------|
| **Tabellen** | Manuell gezeichnet | Automatisch |
| **Layout** | Manuell | Automatisch |
| **Wartung** | Komplex | Einfacher |
| **Flexibilität** | Sehr flexibel | Etwas eingeschränkter |
| **Performance** | Sehr gut | Gut |

## Empfehlung

**Für jetzt:** Die verbesserte PDFKit-Version (`PDFCoreGeneratorImproved`) ist ausreichend und professionell.

**Für später:** TPPDF kann hinzugefügt werden, wenn:
- Noch professionellere Tabellen benötigt werden
- Layout-Änderungen häufiger vorkommen
- Wartbarkeit wichtiger wird

## Migration

Falls Sie zu TPPDF migrieren möchten:

1. TPPDF installieren (siehe oben)
2. `TPPDFInvoiceGenerator.swift` erstellen (siehe Beispiel)
3. In `PDFGenerator.swift` Toggle aktivieren
4. Testen und anpassen

---

**Status:** Optional, für zukünftige Verbesserungen
**Priorität:** Niedrig (aktuelle Lösung ist bereits professionell)
