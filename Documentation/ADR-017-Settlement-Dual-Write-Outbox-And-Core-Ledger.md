# ADR-017 – Settlement: Dual-Write, Outbox oder Core Ledger?

- **Status:** Accepted
- **Datum:** 2026-06-10
- **Bezug:** `ADR-010`, `ADR-011`, `ADR-014`, `ADR-016`, `ENGINEERING_GUIDE.md`

## Kontext

FIN1 bucht Trade-Settlement in **zwei Schichten**:

| Schicht | Klasse / Pfad | Zweck |
|---------|----------------|--------|
| **Personenkonto** | `AccountStatement` | Kundensaldo, Kontoauszug iOS, GoB-Belegbezug |
| **Hauptbuch** | `AppLedgerEntry` | SKR-Mapping, Admin-Ledger, Clearing (`PLT-LIAB-COM`, Steuer, Fees) |

Seit ADR-010 schreibt `bookSettlementEntry` beide Seiten. GL-Fehler sind **fail-open** (Settlement läuft weiter); Drift wird per Monitor erkannt (`getSettlementGLReconciliationStatus`, Cron).

**Auslöser dieser ADR:** Idempotenz-Bug bei `commission_debit` (ein GL-Pair pro Trade statt pro Investment) — behoben durch `leg: commission:inv:{investmentId}` + Backfill `backfillMissingSettlementGL`. Kein Beweis für „falsche Gesamtarchitektur“, aber Klärungsbedarf: reicht Dual-Write langfristig?

## Entscheidung (2026–2028)

**Wir bleiben bei Dual-Write + Reconciliation + Repair** als Settlement-Modell.

**Nicht** Ziel in diesem Horizont: separates Kernbankensystem oder ACID-2PC über zwei unabhängige Datenmodelle.

**Nächster inkrementeller Schritt** (wenn Settlement-Volumen oder Audit-Druck steigt): **Outbox in derselben Mongo-Transaktion** wie `AccountStatement` — GL asynchron, idempotent, mit bestehendem Reconciliation-Monitor als zweiter Verteidigungslinie.

**Core Ledger / Postgres-only-Buchungsmotor** nur bei expliziten Triggern (siehe unten) — separates Großprojekt, kein Default.

## Optionen (Kurzvergleich)

| Option | Stärke | Schwäche | FIN1-Fit |
|--------|--------|----------|----------|
| **A) Dual-Write + Monitor** (heute) | Einfach, retry-tauglich, Parse-nativ | Eventual consistency; Ops-Reife nötig | ✅ **Jetzt** |
| **B) Outbox + Worker** | At-least-once GL garantiert; ein Write-Pfad für Statement | Worker-Betrieb, Schema für Outbox | ✅ **Nächster Schritt** |
| **C) Mongo-Transaction Statement+GL** | Atomar innerhalb eines Clusters | Nur ein Store; Parse-Cloud-Grenzen; kein Cross-Service | ⚠️ Optional lokal |
| **D) Core Ledger / 2PC** | Starke Konsistenz-Narrative | Teuer, Team, Migration; Overkill ohne Banklizenz | ❌ **Nicht jetzt** |

## Was „Best Practice“ für eine Trading-App hier heißt

FIN1 ist **Trading-/Investment-Plattform mit Sub-Ledger**, nicht Vollbank-Kern:

- Settlement **ereignisgetrieben** (Trade completed), nicht Mikrosekunden-Zahlungsverkehr.
- GoB = **Beleg + nachvollziehbare Buchung + Audit**, nicht zwingend „Hauptbuch = Saldo in Echtzeit ohne Reconciliation“.
- Branchenüblich: **Sub-Ledger (Kunde) + GL (Plattform) + periodischer Abgleich**.

Pflicht-Invarianten (unabhängig vom Modell):

1. Idempotenz-Grain = Business-Grain (`investmentId` bei Investor-Zeilen).
2. Automatischer **Statement ↔ GL**-Abgleich (Monitor).
3. Dokumentierter **Repair** ohne Statement-Löschung (`backfillMissingSettlementGL`).
4. ADR + Tests für Multi-Investor-/Multi-Leg-Szenarien.

## Wann wir das Modell **neu bewerten** müssen

| Trigger | Richtung |
|---------|----------|
| BaFin-**Banklizenz** oder eigene Kontoführung ohne Partnerbank | Core Ledger oder BaaS als Geld-SSOT |
| Prüfer verlangt **Live-Hauptbuch = Kundensaldo** ohne Reconciliation-Job | Outbox → oder ein Buchungsmotor |
| **> ~5k** abgeschlossene Settlements/Monat oder starke Parallelität | Outbox-Worker skalieren; ggf. Ledger-DB |
| Wiederholte GL-Drift trotz Monitor + Fix | Outbox-Pflicht (B), nicht sofort D |
| SEPA Instant / Dispo / Valuta im selben Motor | Partnerbank/Core — außerhalb Parse-Settlement |

Bis keiner dieser Trigger greift: **kein** Kernbanken-Rewrite.

## Konkrete Roadmap (minimal)

| Phase | Inhalt | Done when |
|-------|--------|-----------|
| **Jetzt** | Investment-scoped GL-Legs; `getSettlementGLReconciliationStatus`; Backfill | Monitor grün; ADR-010 aktualisiert |
| **+1** (optional) | `SettlementOutbox` + Worker `postSettlementGLFromOutbox` in **einer** Mongo-Transaction mit Statement | Kein GL-Write mehr im synchronen Settlement-Pfad |
| **+2** (nur bei Trigger) | Ledger-Engine-Evaluierung (Postgres double-entry / Partner) | Entscheidungs-ADR mit Migrationsplan |

## Konsequenzen

**Positiv**

- Kein Big-Bang; Parse-Cloud-Stack bleibt stabil.
- Commission-Bug-Klasse wird durch Monitor + Leg-SSOT abgefangen.
- Outbox ist evolutionär, kein Bruch mit ADR-010-Mapping.

**Negativ / Akzeptiert**

- Kurzzeitige Drift Statement vs. GL theoretisch möglich (Sekunden bis Cron) — für Admin und GoB mit Monitor + Repair vertretbar.
- Zwei Collections bleiben fachlich getrennt — bewusst, nicht technische Schuld allein.

## Nicht-Ziele

- Temenos/Mambu/„Kernbank“-Ersatz auf Parse.
- ACID-2PC über Mongo + externen Dienst in Phase 1–2.
- Entfernen von `AccountStatement` zugunsten nur GL (Kundensaldo-SSOT bleibt Personenkonto).

## Referenzen (Implementierung)

- `settlementGLPoster.js` — `resolveSettlementGLLeg`, `backfillMissingSettlementGLForTrade`
- `settlementGLReconciliation.js` — `reconcileSettlementGLForTrade`
- `opsHealthSettlementGLReconciliation.js` — `getSettlementGLReconciliationStatus`
- Cron: `run-settlement-gl-reconciliation-monitor.sh`
