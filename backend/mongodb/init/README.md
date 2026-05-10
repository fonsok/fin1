# MongoDB Initialization

## Übersicht

Diese Scripts werden beim ersten Start des MongoDB-Containers ausgeführt.
Sie erstellen Datenbank, User, Collections, Indexes und Schema-Validierung.

## Dateien

| Datei | Beschreibung |
|-------|--------------|
| `00_init_admin.js` | Datenbank, User, Collections, Initialdaten |
| `01_indexes.js` | Alle Performance-Indexes |
| `02_schema_validation.js` | Schema-Validierungsregeln |
| `../scripts/apply_ledger_document_indexes_fin1.js` | **Nur Indizes** für `AppLedgerEntry`, `BankContraPosting`, `Document` (für bestehende DBs; siehe unten) |

## Ausführungsreihenfolge

MongoDB führt Scripts in alphabetischer Reihenfolge aus:
1. `00_init_admin.js` - Basis-Setup
2. `01_indexes.js` - Indexes
3. `02_schema_validation.js` - Validierung

## Docker-Integration

Die Scripts werden automatisch ausgeführt wenn sie in `/docker-entrypoint-initdb.d/` gemountet sind:

```yaml
# docker-compose.yml
mongodb:
  volumes:
    - ./backend/mongodb/init:/docker-entrypoint-initdb.d
```

## Manuell ausführen

```bash
# Via mongosh
mongosh mongodb://admin:password@localhost:27017/admin

# Dann (interaktiv, mit absolutem Pfad zur Datei auf deinem Rechner):
load("/path/to/00_init_admin.js")
load("/path/to/01_indexes.js")
load("/path/to/02_schema_validation.js")
```

### Hinweis: `mongosh --file` und `01_indexes.js`

`01_indexes.js` beginnt mit `db._User.createIndex(...)`. In **mongosh** ist **`db._User`** (Collection mit führendem Unterstrich) per Punktnotation **nicht** erreichbar — das Skript bricht dann mit einem Fehler ab. Beim **ersten** Container-Start übernimmt der offizielle Entrypoint die Ausführung trotzdem (anderer Kontext). Auf **bestehenden** DBs: entweder interaktiv `load()` wie oben, oder das Wartungs-Skript **`backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js`** (nur Ledger-/Document-Indizes, ohne `_User`).

## Indizes nachziehen (Mac Terminal, Docker Compose im Repo)

Voraussetzungen: **Docker läuft**, Container heißt wie in `docker-compose.yml` typischerweise **`fin1-mongodb`**, Admin-Passwort steht bei dir in **`MONGO_INITDB_ROOT_PASSWORD`** / `docker-compose.yml` (lokal nicht ins Git committen).

**Passwort nur in der Shell-Session halten** (nicht dauerhaft in der Shell-History speichern — Befehl unten nutzt eine **Umgebungsvariable** in *dieser* Zeile):

```bash
cd /path/to/FIN1   # Repo-Root

# Passwort setzen (Wert aus deiner docker-compose / .env ersetzen):
export MONGO_PASS='HIER_DEIN_ADMIN_PASSWORT'

# Indizes anwenden (liest das JS von deinem Mac ein, führt es IN im Container aus):
cat backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js | docker exec -i fin1-mongodb \
  mongosh --quiet -u admin -p "$MONGO_PASS" --authenticationDatabase admin

unset MONGO_PASS
```

Wenn dein Container **anderen Namen** hat: `docker ps` → Namen anpassen.

## Indizes nachziehen (Mac → Ubuntu fin1-server, Skript liegt nur lokal)

Mongo läuft auf dem **Server** im Container **`fin1-mongodb`**; das JS muss **nicht** unter `/home/io/fin1-server/...` existieren — du kannst es **vom Mac-Repo** per Pipe durch **SSH** direkt in `docker exec … mongosh` schicken.

**Einmalig vom Mac** (Repo-Root mit der Datei `backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js`; `io@fin1-server` bei Bedarf durch Nutzer/Host oder SSH-Config-Alias ersetzen):

```bash
cd /path/to/FIN1
read -s -p "Mongo admin password (wie auf dem Server): " MONGO_PASS
echo
cat backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js | \
  ssh io@fin1-server "docker exec -i fin1-mongodb mongosh --quiet -u admin -p \"$MONGO_PASS\" --authenticationDatabase admin"
unset MONGO_PASS
```

Passwort-Quelle auf dem Server: z. B. `MONGO_INITDB_ROOT_PASSWORD` in `docker-compose.production.yml` oder `backend/.env`.

**Alternative:** Skript dauerhaft auf den Server legen (z. B. nach `git pull` fehlt nur der Ordner):

```bash
cd /path/to/FIN1
ssh io@fin1-server 'mkdir -p /home/io/fin1-server/backend/mongodb/scripts'
scp backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js \
  io@fin1-server:/home/io/fin1-server/backend/mongodb/scripts/
```

Danach auf dem Server wie oben im Abschnitt „Docker Compose im Repo“ mit `cat … | docker exec …` arbeiten.

## Indizes nachziehen (Mac Terminal, mongosh direkt gegen localhost-Port)

`docker-compose.yml` mappt Mongo oft auf **`127.0.0.1:27018`** (Host) → `27017` (Container). Dann reicht **mongosh auf dem Mac** (`brew install mongosh`), ohne `docker exec`:

```bash
cd /path/to/FIN1
export MONGO_PASS='HIER_DEIN_ADMIN_PASSWORT'

cat backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js | \
  mongosh --quiet "mongodb://admin:${MONGO_PASS}@127.0.0.1:27018/fin1?authSource=admin"

unset MONGO_PASS
```

**Hinweis:** Port und Host müssen zu deiner Umgebung passen (Firewall, anderer Port-Mapping).

## Erstellte User

| User | Passwort | Rechte | Verwendung |
|------|----------|--------|------------|
| `admin` | aus ENV | root | Administration |
| `fin1_app` | `fin1-app-password` | readWrite, dbAdmin | Parse Server |
| `fin1_analytics` | `fin1-analytics-password` | read | Analytics |

**WICHTIG:** In Production Passwörter über ENV-Variablen setzen!

## Collections

~45 Collections werden erstellt, darunter:

**User Management:**
- UserProfile, UserAddress, UserKYCDocument, UserRiskAssessment, UserConsent, UserDevice

**Business:**
- Investment, Trade, Order, Holding, Commission (Konto: Wallet-Feature deaktiviert)

**Support:**
- SupportTicket, TicketResponse, CSRAgent, FourEyesRequest

**Compliance:**
- ComplianceEvent, AuditLog, DataAccessLog, GDPRRequest

## Schema-Validierung

Validierung ist auf "moderate" und "warn" eingestellt:
- Validiert bei Insert/Update
- Warnt bei Verstößen (lehnt nicht ab)

Für Production auf "error" umstellen:
```javascript
db.runCommand({ collMod: "CollectionName", validationAction: "error" })
```

## TTL Indexes

Automatisches Löschen:
- `MarketData`: Nach 90 Tagen
- `Notification` (gelesen): Nach 90 Tagen

## Bestehende Datenbanken (kein frisches Volume)

Die Init-Skripte unter `/docker-entrypoint-initdb.d` laufen **nur beim ersten Start** von MongoDB (leeres `data`-Volume). Auf **länger laufenden** Umgebungen gilt:

| Thema | Was tun |
|--------|--------|
| **Indexes** | Neue Indizes aus `01_indexes.js` werden **nicht** automatisch nachgezogen. Für Ledger/Document: Skript `backend/mongodb/scripts/apply_ledger_document_indexes_fin1.js` per `cat … \| docker exec … mongosh` oder natives `mongosh` (siehe Abschnitte oben). `createIndex` mit gleicher Spezifikation ist idempotent. |
| **JSON Schema / `collMod`** | Änderungen in `02_schema_validation.js` (z. B. `SupportTicket` verlangt `userId` statt `customerId`) wirken erst nach **manuellem** `collMod` auf der Collection oder nach Ausführen des entsprechenden `runCommand`-Blocks in `mongosh`. Aktuell: `validationAction: "warn"` — Verstöße loggen, schreiben nicht hart fehl. |
| **Alte Ticket-Felder `customerId`** | Parse **beforeSave** (`triggers/support.js`) kopiert bei jedem Speichern `customerId` → `userId` und entfernt `customerId`. Unberührte alte Dokumente bleiben, bis sie gespeichert werden. **Bulk:** Script `backend/mongodb/scripts/migrate_customerId_to_userId_fin1.js` **oder** Cloud Function `migrateLegacyCustomerIdToUserId` (Admin, optional `dryRun: true`). |

## Troubleshooting

**Scripts werden nicht ausgeführt:**
- Nur beim ERSTEN Container-Start
- Volume löschen: `docker volume rm fin1_mongodb_data`

**Authentifizierungsfehler:**
- Prüfen ob MONGO_INITDB_ROOT_USERNAME/PASSWORD gesetzt
- Connection-String mit authSource: `?authSource=admin`
