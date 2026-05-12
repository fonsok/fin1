# Legacy-Parse-Klasse `Ticket` (Mongo-Collection `Ticket`)

Die App und das Admin-/CSR-Portal arbeiten mit **`SupportTicket`**. Die frühere Seed-Funktion `seedMockTickets` schrieb in die **separate** Klasse **`Ticket`**; solche Dokumente sind in Mongo weiterhin in der Collection **`Ticket`** vorhanden, falls sie jemals geseedet wurden. Sie erscheinen **nicht** in `getTickets` / `getSupportTickets`.

## Live-Bestand anzeigen (mongosh)

**Lokaler Stack** (`docker-compose.yml`, Mongo nur auf localhost):

```bash
docker exec fin1-mongodb mongosh -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin fin1 --quiet --eval '
  const c = db.getCollection("Ticket");
  const n = c.countDocuments({});
  print("Ticket count:", n);
  if (n > 0) printjson(c.find().sort({ _created_at: -1 }).limit(100).toArray());
'
```

`MONGO_PASSWORD` entspricht `MONGO_INITDB_ROOT_PASSWORD` aus der Compose-Umgebung bzw. `backend/.env` auf dem Server.

**Nur Zählen und `_id`-Liste:**

```bash
docker exec fin1-mongodb mongosh -u admin -p "$MONGO_PASSWORD" --authenticationDatabase admin fin1 --quiet --eval '
  db.Ticket.aggregate([
    { $count: "n" },
  ]);
  db.Ticket.find({}, { ticketNumber: 1, customerId: 1, subject: 1, _created_at: 1 }).toArray();
'
```

**Optional: alle Legacy-Datensätze löschen (nur nach Prüfung):**

```javascript
// In mongosh, DB fin1:
db.Ticket.deleteMany({});
```

## Typische Felder (über Parse SDK gespeichert)

Aus dem historischen Seed (`seedMockTickets` → `Parse.Object.extend('Ticket')`) wurden u. a. diese **logischen** Felder gesetzt (Namen wie in Parse; in Mongo können Parse-interne Spiegel wie `_created_at` / `_updated_at` zusätzlich vorkommen):

| Feld | Beispiel / Hinweis |
|------|---------------------|
| `ticketNumber` | `TKT-12345` … `TKT-12352` (ältere Seeds) |
| `customerId` | z. B. `CUST-INV-001` (Commit-Stand `HEAD`) oder später `ANL-2026-00001` (Zwischenstand vor Umstellung auf `SupportTicket`) |
| `customerName` | Anzeigename aus dem Mock |
| `subject`, `description` | Freitext |
| `status` | `open`, `in_progress`, `waiting`, `resolved`, … |
| `priority` | `low`, `medium`, `high`, `urgent` |
| `category` | u. a. `investment`, `account`, `billing`, `technical`, `kyc` (ohne `_issue`-Suffix) |
| `assignedTo` | `null` oder **E-Mail** des CSR (z. B. `csr1@test.com`) — kein Parse-`objectId` |
| `createdAt` / `resolvedAt` | gesetzt, soweit im Seed vorgesehen |

## Referenz: Mock-Zeilen aus dem letzten `Ticket`-Seed (Git `HEAD`)

Die folgende Tabelle entspricht dem **zuletzt committeden** `seed/tickets.js` (Klasse `Ticket`, Kunden-IDs `CUST-*`). Das ist **kein** Dump aus deiner Datenbank, sondern die **Spezifikation**, nach der ältere Umgebungen befüllt worden sein können.

| ticketNumber | customerId | customerName | subject | status | category | assignedTo |
|--------------|------------|--------------|---------|--------|----------|------------|
| TKT-12345 | CUST-INV-001 | Max Investor | Frage zu meiner Investition | open | investment | — |
| TKT-12346 | CUST-INV-002 | Sarah Smith | Problem beim Login | in_progress | account | csr1@test.com |
| TKT-12347 | CUST-INV-003 | Michael Johnson | Rechnung nicht erhalten | in_progress | billing | csr2@test.com |
| TKT-12348 | CUST-INV-001 | Max Investor | App stürzt beim Öffnen ab | in_progress | technical | csr3@test.com |
| TKT-12349 | CUST-TRD-001 | Thomas Trader | Auszahlung ausstehend | open | billing | — |
| TKT-12350 | CUST-TRD-002 | Alex Chen | KYC-Dokumente abgelehnt | waiting | kyc | csr1@test.com |
| TKT-12351 | CUST-INV-004 | Emma Williams | Passwort vergessen | resolved | account | csr2@test.com |
| TKT-12352 | CUST-INV-005 | David Brown | Falsche Gebührenberechnung | open | billing | — |

## Hinweis zum aktuellen Stand im Repo

`seedMockTickets` legt nur noch **`SupportTicket`**-Datensätze an. Eine bestehende Collection **`Ticket`** wird dabei **nicht** automatisch migriert oder gelöscht.

**SupportTicket:** Kanonisches Feld für den Endkunden ist **`userId`** (Parse **`_User.objectId`**). Ein veraltetes Feld **`customerId` auf dem Ticket** wurde entfernt: Beim Speichern migriert Cloud Code ggf. noch vorhandene Werte nach **`userId`** und entfernt **`customerId`** vom Dokument. CSR-/Admin-APIs können den Parameter weiterhin unter dem Namen `customerId` mitschicken; der Server behandelt ihn als Alias für dieselbe User-ID.

---

*Hinweis: In dieser Entwicklungsumgebung war kein laufender `fin1-mongodb`-Container und kein `mongosh` auf dem Host verfügbar; es liegt daher **kein** produktiver BSON-Dump bei. Mit den Befehlen oben kannst du die echten Dokumente auf deinem Rechner oder Server ausgeben und bei Bedarf hier ergänzen.*
