---
title: "FIN1 – CSR Workflow & Aufgabenverteilung (Support Runbook)"
audience: ["Customer Support (CSR)", "QA", "Produkt", "Compliance", "Betrieb", "Entwicklung"]
lastUpdated: "2026-02-05"
---

## Zweck

Dieses Dokument beschreibt den **konkret implementierten** Support-Workflow in FIN1 (iOS + Backend) und die **Aufgabenverteilung** zwischen CSR-Rollen (L1/L2/Fraud/Compliance/Tech/Teamlead).

**Source of Truth** (Code):
- iOS CSR Portal: `FIN1/Features/CustomerSupport/**`
- RBAC/Permissions (iOS): `FIN1/Features/CustomerSupport/Models/CustomerSupportPermission*.swift`, `CSRRole.swift`
- RBAC/Permissions (Backend): `CSRPermission` und `CSRRole` Collections in MongoDB (siehe `backend/scripts/seed-csr-permissions.js`)
- Ticket-Workflow: `CustomerSupportService+Tickets.swift`, `+Resolution.swift`, `+UserConfirmation.swift`, `+Lifecycle.swift`
- SLA: `SLAModels.swift`, `SLAMonitoringService.swift`
- Backend Triggers: `backend/parse-server/cloud/triggers/support.js`
- Backend Cloud Functions: `backend/parse-server/cloud/functions/support.js` (getCSRRoles, getCSRPermissions, etc.)
- 4-Augen (Backend): `backend/parse-server/cloud/functions/admin.js` (`getPendingApprovals`, `approveRequest`)

## 1) Rollenmodell (wer macht was?)

### 1.1 CSR Rollen (iOS) + Kernbefugnisse

Rollen sind in `CSRRole` definiert und mappen auf Permission-Sets (`CustomerSupportPermissionSet`).

- **CSR L1 (Level 1 Support)**
  - Fokus: Ticketaufnahme, Standardantworten, Basis-Troubleshooting, Statuskommunikation.
  - **Wichtig**: L1 darf **keine** detaillierten Trades sehen (`viewCustomerTrades` ist bewusst entfernt).
- **CSR L2 (Senior Support)**
  - Fokus: tieferes Troubleshooting, Trading-/Investment-Fragen mit Detaildaten, Eskalationen, Account-Aktionen.
  - Darf Trades einsehen, darf u.a. `resetCustomerPassword`, `unlockCustomerAccount`, `escalateToAdmin`.
- **Fraud Analyst**
  - Fokus: Fraud Alerts, Transaction Patterns, (temporäre/erweiterte) Sperren, Chargeback-Flow.
  - Einige Aktionen **4-Augen-pflichtig** (z.B. `suspendAccountExtended`, `initiateChargeback`).
- **Compliance Officer**
  - Fokus: KYC/AML/GDPR Vorgänge, Audit Logs, SAR Reports (regulatorisch).
  - Hat Trade-Zugriff (AML/SAR) und **Approval Authority** für Compliance-Aktionen.
- **Tech Support**
  - Fokus: technische Analyse (Audit Logs, Fehlerbilder), keine direkten Kundendaten-Änderungen.
- **Teamlead**
  - Fokus: operatives Steering, Eskalationsentscheidungen, Genehmigungen (4-Augen), Permission-Management.

### 1.2 System- und Partnerrollen (Prozess)

- **System (SLA Monitoring)**
  - `SLAMonitoringService` prüft Tickets zyklisch und eskaliert automatisch bei SLA-Verletzungen.
- **Entwicklung (Dev Team)**
  - Empfängt Eskalationen (`escalateToDevTeam`) inkl. Severity + optionalem JIRA-Ticket.
- **Customer (Endnutzer)**
  - Erstellt Tickets, antwortet, bestätigt Lösung oder meldet “nicht gelöst” (Self-Service).

## 2) Aufgabenverteilung (RACI)

Legende: **R** = Responsible (führt aus), **A** = Accountable (trägt Verantwortung), **C** = Consulted, **I** = Informed

| Aktivität | L1 | L2 | Tech | Fraud | Compliance | Teamlead | Dev | System |
|---|---|---|---|---|---|---|---|---|
| Ticket aufnehmen (User/CSR) | R | R | I | I | I | A | I | I |
| Erste Antwort (First Response) | R | R | C | C | C | A | I | I |
| Ticket-Zuweisung (Auto/Manuell) | I | R | I | I | I | A | I | I |
| Standard-Troubleshooting (Login, UI, FAQ) | R | C | C | I | I | A | I | I |
| Trading/Investment-Fall mit Detaildaten | I | R | C | I | C | A | C | I |
| Technische Analyse (Logs, Repro, Fehlerbild) | I | C | R | I | C | A | C | I |
| Dev-Eskalation (Bug) | I | R | R | I | C | A | R | I |
| Fraud-Handling (Alerts/Patterns) | I | C | I | R | C | A | I | I |
| Compliance/KYC/AML/GDPR Case | I | C | I | C | R | A | I | I |
| Account Unlock / Password Reset | I | R | I | C | C | A | I | I |
| Adresse/Name ändern (4-Augen) | I | R (Request) | I | I | A (Approve) | A (Approve) | I | I |
| Ticket lösen/abschließen | R (einfach) | R | C | C | C | A | I | I |
| Auto-Eskalation bei SLA-Verletzung | I | I | I | I | I | I | I | R |

## 3) Ticket Lifecycle (Status, Übergänge, Reopen, Archive)

### 3.1 Statusmodell (iOS)

Siehe `SupportTicket.TicketStatus`:
- `open`
- `inProgress`
- `waitingForCustomer` (SLA wird pausiert)
- `escalated`
- `resolved`
- `closed`
- `archived`

### 3.2 Statusmodell (Backend / Parse)

Backend Defaults/Triggers (`triggers/support.js`):
- **Default bei Neuanlage**: `status="open"`, `priority` default `medium`
- Erzeugt `TicketSLATracking` mit Targets und `slaStatus="on_track"`
- Bei Statuswechsel auf `resolved`: setzt `resolvedAt`, erzeugt `SatisfactionSurvey` (7 Tage gültig) und sendet Notification

> Hinweis: Backend und iOS haben teilweise unterschiedliche Status-Namen/Granularität (z.B. `waitingForCustomer`, `archived`). Bei produktiver Anbindung muss eine **Mapping-Schicht** konsistent bleiben.

### 3.3 Reopen & Follow-up Regeln

Implementiert in `TicketModels.swift` + `CustomerSupportService+Lifecycle.swift`:
- **Reopen Grace Period**: Ticket kann **bis 7 Tage** nach `closedAt` wiedereröffnet werden (`canReopen`).
- **User Reopen**
  - Innerhalb der Frist: Status zurück auf `open` und Agent wird benachrichtigt.
  - Außerhalb der Frist: es wird ein **neues Folge-Ticket** erstellt, verlinkt über `parentTicketId`.
- **Auto-Archive**
  - Tickets werden **30 Tage nach Closure** automatisch auf `archived` gesetzt (`archiveOldTickets`).

## 4) SLA (Targets, Warnung, Breach, Auto-Eskalation)

### 4.1 Targets (First Response & Resolution)

Targets sind konsistent in Backend und iOS abgebildet:

| Priority | First Response Target | Resolution Target |
|---|---:|---:|
| `urgent` | 1h | 4h |
| `high` | 4h | 24h |
| `medium` | 8h | 48h |
| `low` | 24h | 72h |

### 4.2 Warn-/Breach-Logik (iOS)

Siehe `SLAModels.swift`:
- **Warning**: wenn verbleibende Zeit ≤ 25% (config `warningThreshold=0.25`)
- **Paused**: bei `waitingForCustomer`
- **Completed**: wenn erste Kundenantwort existiert (nicht-internal) bzw. Ticket `resolved/closed` ist

### 4.3 Auto-Eskalation (SLA Monitoring)

Siehe `SLAMonitoringService.swift`:
- Prüft periodisch alle aktiven Tickets.
- Bei Breach:
  - `escalateTicketInternal(..., isAutomatic: true)`
  - Interne Notiz wird hinzugefügt
  - Assigned Agent erhält High-Priority Notification
  - ComplianceEvent `.escalation` wird geloggt, `requiresReview=true`

## 5) Ticket Assignment (Auto vs Manuell)

### 5.1 Auto-Assignment (Skill + Workload + Round-Robin)

Siehe `TicketAssignmentService.swift` + `CustomerSupportService+Tickets.swift`:
- **Max Tickets pro Agent**: 8 (konfigurierbar), sonst “at capacity”.
- Scoring:
  - Language Match Weight: 0.4
  - Specialization Match Weight: 0.4
  - Workload Weight: 0.2
- Top-Kandidaten (Score-Toleranz 10%) werden per Round-Robin verteilt.
- Wenn niemand verfügbar:
  - Ticket bleibt unassigned (Queue) oder Fallback-Verhalten (konfigurierbar).

### 5.2 Manuelle Zuweisung

CSR Dashboard zeigt unassigned Tickets in der Warteschlange (`TicketQueueView`) und erlaubt manuelle Zuweisung.

## 6) Kommunikation: Public Reply vs Internal Note

`TicketResponse` unterstützt:
- **Public** (für Kunden sichtbar): `isInternal=false`
- **Internal** (nur CSR/Teams): `isInternal=true`

Guideline:
- **Alles mit sensiblen Details** (internes Debugging, Verdachtsmomente, Account-Sicherheitsinfos, AML/Fraud) als **Internal Note** dokumentieren.
- Kundenkommunikation kurz, nachvollziehbar, ohne PII/Secrets.

## 7) Eskalationen (Admin/Dev/Compliance/Fraud)

### 7.1 Eskalation an “Admin” (operativ)

Siehe `CustomerSupportService+Tickets.swift` (`escalateTicket`):
- Setzt Status auf `escalated`
- Schreibt Audit Action + ComplianceEvent

### 7.2 Eskalation an Entwicklung

Siehe `CustomerSupportService+Resolution.swift` (`escalateToDevTeam`):
- Erzeugt internen “escalation” Response inkl. Team, Severity, optional JIRA.
- Setzt Ticket auf `escalated` und passt Priority an Severity an.
- Loggt ComplianceEvent; bei `critical` mit `requiresReview=true`.

## 8) “Approved Modifications” & 4-Augen Prinzip

### 8.1 Änderungstypen und Approval-Pflicht

Permissions markieren Approval-Pflicht (`CustomerSupportPermission.requiresApproval`), u.a.:
- `updateCustomerAddress`
- `updateCustomerName`
- `suspendAccountExtended`
- `initiateChargeback`
- `createSARReport`
- `approveGDPRDeletion`

### 8.2 Wer darf genehmigen?

Siehe `CSRRole.canApprove`:
- **Teamlead** und **Compliance** dürfen genehmigen.
- 4-Augen-Regel: **Requester ≠ Approver** (Backend enforced in `approveRequest`).

## 9) Audit & Compliance Logging (Pflicht)

iOS `CustomerSupportService` loggt:
- **Data Access** (Kategorie, Fields, Zweck, Legal Basis)
- **Actions** (Permission, Beschreibung, CustomerId)
- **Compliance Events** (z.B. Eskalation, Account Unlock, Password Reset)

Backend loggt zusätzlich serverseitig (z.B. `AuditLog` bei `updateUserStatus`).

