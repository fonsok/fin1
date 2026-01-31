# Project Documentation Index

Dieses Verzeichnis enthält die Hauptdokumentation für dieses Projekt.

## 📁 Dokumentationsstruktur

**⚠️ WICHTIG:** Es gibt **zwei** Documentation-Verzeichnisse:

1. **`Documentation/`** (Root-Level) - **24 Dateien**
   - Hauptdokumentation für Architektur, Entwicklung, Netzwerk
   - Projekt-weite Richtlinien und Best Practices
   - **Standort:** `/Users/ra/app/FIN1/Documentation/`

2. **`FIN1/Documentation/`** (Feature-Level) - **49 Dateien**
   - Feature-spezifische Dokumentation
   - Code-Reviews, Implementierungs-Details
   - Archive mit historischen Dokumenten
   - **Standort:** `/Users/ra/app/FIN1/FIN1/Documentation/`

## 📚 Root-Level Documentation (`Documentation/`)

### Architektur & Entwicklung

- **`ARCHITECTURE_GUARDRAILS.md`** - Automatisierte Checks und Guardrails für Architektur-Verbesserungen
- **`ENGINEERING_GUIDE.md`** - Engineering-Richtlinien und Best Practices
- **`MVVM_VALIDATION_GUIDE.md`** - MVVM-Architektur-Validierung und Patterns
- **`SEPARATION_OF_CONCERNS.md`** - Trennung von Concerns und File-Organisation
- **`UIKit_Reduction_Implementation.md`** - Migration von UIKit zu SwiftUI

### Berechnungen & Logik

- **`CalculationCoreLogic.md`** - Kern-Berechnungslogik
- **`InvestorCalculationLogic.md`** - Investor-spezifische Berechnungen
- **`CALCULATION_CONSISTENCY_AND_MVVM_IMPLEMENTATION.md`** - Konsistenz von Berechnungen
- **`CALCULATION_SCHEME_PROTECTION.md`** - Schutz von Berechnungsschemata

### Netzwerk & Performance

- **`NETWORK_TOOLS.md`** - Netzwerk-Diagnose-Tools (nmap, netcat, mtr) und Scripts
- **`NETWORK_PERFORMANCE_TUNING.md`** - Netzwerk-Performance-Optimierung

### Mac-Entwicklung

- **`MAC_DEVELOPMENT_OPTIMIZATION.md`** - Mac-Power-Management für Entwicklung
- **`SLEEP_MODES_EXPLAINED.md`** - Erklärung von Display Sleep vs. System Sleep
- **`CAFFEINATE_EXPERT_OPINION.md`** - Best Practices für `caffeinate` Usage

### Testing & Qualität

- **`LEGACY_TEST_SUITE_RETIREMENT.md`** - Legacy-Test-Suite Migration
- **`FILE_SIZE_LIMIT_UPDATE.md`** - File-Size-Limits und Refactoring-Strategien
- **`IMPROVEMENT_PROTECTION_SUMMARY.md`** - Zusammenfassung geschützter Verbesserungen

### Features & Funktionalität

- **`AccountStatementsAndReports.md`** - Account Statements und Reports
- **`InvestorQuantityFeature.md`** - Investor Quantity Feature
- **`FAQ_SUPPORT.md`** - FAQ und Support-Dokumentation

### Navigation & UI

- **`ADR-001-Navigation-Strategy.md`** - Navigation-Strategie (Architecture Decision Record)
- **`ResponsiveDesign.md`** - Responsive Design System

### Error Handling

- **`ERROR_HANDLING_MIGRATION.md`** - Error-Handling-Migration zu AppError

## 📚 Feature-Level Documentation (`FIN1/Documentation/`)

Enthält feature-spezifische Dokumentation, Code-Reviews und Archive:

- Feature-Implementierungen
- Code-Review-Dokumente
- Architektur-Analysen
- Test-Szenarien
- Archive mit historischen Dokumenten

**Vollständige Liste:** Siehe `FIN1/Documentation/` Verzeichnis

## 🔍 Dateien finden

### In Finder öffnen

```bash
# Root-Level Dokumentation
open Documentation/

# Feature-Level Dokumentation
open FIN1/Documentation/
```

### In Terminal anzeigen

```bash
# Root-Level Dateien
ls -la Documentation/*.md

# Feature-Level Dateien
ls -la FIN1/Documentation/*.md

# Beide Verzeichnisse
find . -path "*/Documentation/*.md" -type f | head -20
```

### In Xcode

Die `.md` Dateien werden standardmäßig nicht in Xcode angezeigt. Um sie zu öffnen:

1. **Rechtsklick** auf das Projekt im Navigator
2. **"Add Files to FIN1..."** wählen
3. `Documentation/` oder `FIN1/Documentation/` Verzeichnis auswählen
4. **"Create groups"** (nicht "Create folder references")
5. **"Add to targets"** deaktivieren (nur Referenz, nicht zum Build hinzufügen)

## 📝 Quick Links

### Wichtige Dokumentation (Root-Level)

- **Architektur:** `ARCHITECTURE_GUARDRAILS.md`, `ENGINEERING_GUIDE.md`
- **MVVM:** `MVVM_VALIDATION_GUIDE.md`, `SEPARATION_OF_CONCERNS.md`
- **Berechnungen:** `CalculationCoreLogic.md`, `InvestorCalculationLogic.md`
- **Netzwerk:** `NETWORK_TOOLS.md`, `NETWORK_PERFORMANCE_TUNING.md`
- **Mac Setup:** `MAC_DEVELOPMENT_OPTIMIZATION.md`, `CAFFEINATE_EXPERT_OPINION.md`

### Feature-Dokumentation

- **Feature-spezifisch:** `FIN1/Documentation/`
- **Archive:** `FIN1/Documentation/Archive/`

## 🗂️ Weitere Dokumentation

- **Scripts:** `scripts/*.md` - Script-Dokumentation
- **Tests:** `FIN1Tests/*.md` - Test-Dokumentation
- **Cursor Rules:** `.cursor/rules/` - Cursor AI Rules und Architektur-Richtlinien

## 💡 Empfehlung

Für neue Dokumentation:
- **Projekt-weite Richtlinien** → `Documentation/` (Root-Level)
- **Feature-spezifische Details** → `FIN1/Documentation/`

---

**Standorte:**
- Root-Level: `/Users/ra/app/FIN1/Documentation/` (24 Dateien)
- Feature-Level: `/Users/ra/app/FIN1/FIN1/Documentation/` (49 Dateien)

**Letzte Aktualisierung:** 2026-01-21
