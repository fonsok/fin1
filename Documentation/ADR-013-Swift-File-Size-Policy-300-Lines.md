# ADR-013: Swift File Size Policy (<=300 Lines)

## Status
Accepted

## Date
2026-05-08

## Context
Mehrere zentrale Swift-Dateien sind organisch gewachsen und wurden schwer wartbar:
- hohe kognitive Last bei Reviews
- erschwerte Navigation und Ownership
- erhöhte Regressionen bei Änderungen in großen "God files"

Im laufenden Refactoring wurden große Dateien erfolgreich in fachlich getrennte Extensions/Dateien aufgeteilt, ohne Funktionsänderung.

## Decision
Wir führen dauerhaft folgende Engineering-Policy ein:
- Zielwert: **jede Swift-Quelldatei <= 300 Zeilen**
- Wenn ein Typ wächst, wird er in **kohäsive** Teilbereiche gesplittet (Core + thematische Extensions)
- Neue Split-Dateien sollen ebenfalls <= 300 Zeilen bleiben
- Ausnahmen sind erlaubt für statische Content-/Datendateien (z. B. rechtliche Texte), müssen aber im PR explizit begründet werden

## Rationale
- Bessere Lesbarkeit und schnellere Reviews
- Klare Verantwortlichkeiten pro Datei
- Bessere MVVM-Umsetzung durch Separation of Concerns
- Niedrigeres Risiko bei Refactors und Bugfixes

## Implementation Guidance
- Empfohlenes Muster:
  - `Type.swift` (State, Init, public API)
  - `Type+Loading.swift`
  - `Type+BackendSync.swift`
  - `Type+Computed.swift`
- Keine rein mechanischen Splits; fachliche Kohäsion bleibt priorisiert.
- Bei Split über mehrere Dateien können `private` Member auf modul-intern angepasst werden, wenn nötig.

## Consequences
### Positive
- Wartbarkeit steigt
- Onboarding wird einfacher
- PRs werden kleiner und präziser

### Trade-offs
- Mehr Dateien im Projekt
- Höherer Koordinationsaufwand bei Access-Control

## Related
- `Documentation/ENGINEERING_GUIDE.md`
- `Documentation/ARCHITECTURE_GUARDRAILS.md`
- `.cursor/rules/architecture.md`
