# Xcode Setup für neue PDF-Dateien

## Neue Dateien hinzufügen

Die folgenden Dateien müssen zum Xcode-Projekt hinzugefügt werden:

### Schritt 1: Dateien in Xcode hinzufügen

1. **Xcode öffnen**
2. **Im Project Navigator:**
   - Rechtsklick auf `FIN1/Features/Trader/Utils/`
   - Wählen Sie "Add Files to FIN1..."
   - Navigieren Sie zu den Dateien und wählen Sie:
     - `PDFStylingImproved.swift`
     - `PDFDrawingComponentsImproved.swift`
     - `PDFCoreGeneratorImproved.swift`
   - ✅ "Copy items if needed" **NICHT** aktivieren (Dateien sind bereits im richtigen Ordner)
   - ✅ "Add to targets: FIN1" aktivieren
   - Klicken Sie "Add"

3. **Für Service-Datei:**
   - Rechtsklick auf `FIN1/Features/Trader/Services/`
   - "Add Files to FIN1..."
   - Wählen Sie: `TradeStatementPDFServiceImproved.swift`
   - ✅ "Add to targets: FIN1"
   - Klicken Sie "Add"

### Schritt 2: Build prüfen

Nach dem Hinzufügen:
1. **Clean Build:** Product → Clean Build Folder (⇧⌘K)
2. **Build:** Product → Build (⌘B)
3. Prüfen Sie auf Fehler

## Alternative: Automatisches Hinzufügen

Falls Xcode die Dateien automatisch erkennt (bei neueren Xcode-Versionen mit File System Synchronization):
- Die Dateien sollten automatisch erscheinen
- Falls nicht, siehe Schritt 1

## Dateien-Übersicht

| Datei | Pfad | Status |
|-------|------|--------|
| `PDFStylingImproved.swift` | `FIN1/Features/Trader/Utils/` | ✅ Erstellt |
| `PDFDrawingComponentsImproved.swift` | `FIN1/Features/Trader/Utils/` | ✅ Erstellt |
| `PDFCoreGeneratorImproved.swift` | `FIN1/Features/Trader/Utils/` | ✅ Erstellt |
| `TradeStatementPDFServiceImproved.swift` | `FIN1/Features/Trader/Services/` | ✅ Erstellt |

## Falls Build weiterhin fehlschlägt

1. **Prüfen Sie die Build-Logs** in Xcode für spezifische Fehlermeldungen
2. **Prüfen Sie, ob alle Imports vorhanden sind:**
   - `import Foundation`
   - `import UIKit`
   - `import PDFKit` (nur in Services)

3. **Prüfen Sie Target-Membership:**
   - Dateien auswählen
   - File Inspector öffnen (⌥⌘1)
   - Prüfen Sie, dass "FIN1" unter "Target Membership" aktiviert ist
