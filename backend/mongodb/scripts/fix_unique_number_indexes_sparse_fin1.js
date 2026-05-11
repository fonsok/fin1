/**
 * Fix: Unique-Indexe auf "*Number"-Feldern als `sparse: true` neu anlegen.
 *
 * Hintergrund: Sammlungen wie `AccountStatement.statementNumber`, `Investment.investmentNumber`,
 * `Trade.tradeNumber`, `Invoice.invoiceNumber` etc. legen Datensätze teilweise an, BEVOR die
 * laufende Nummer vergeben ist (oder nutzen die Sammlung auch für Datensätze, die nie eine
 * Nummer bekommen — z. B. AccountStatement-Ledger-Buchungen). Ohne `sparse: true` kollidiert
 * jeder weitere Insert ohne den Wert mit dem ersten `null`-Slot des Unique-Index → E11000
 * "duplicate value for a field with unique values". Folge: SettlementRetryJob wirft, Investments
 * bleiben `active` obwohl Trade `completed` ist.
 *
 * Dieses Skript löscht (falls vorhanden) den nicht-sparsen Unique-Index und legt ihn als
 * `unique + sparse` neu an. Idempotent — kann mehrfach laufen.
 *
 * Ausführung (Repo-Root, lokal über Docker):
 *   export MONGO_PASS='…'
 *   cat backend/mongodb/scripts/fix_unique_number_indexes_sparse_fin1.js | docker exec -i fin1-mongodb \
 *     mongosh --quiet -u admin -p "$MONGO_PASS" --authenticationDatabase admin
 *
 * Auf iobox (~/fin1-server):
 *   source ~/fin1-server/.env
 *   cat /tmp/fix_unique_number_indexes_sparse_fin1.js | docker exec -i fin1-mongodb \
 *     mongosh --quiet -u admin -p "$MONGO_INITDB_ROOT_PASSWORD" --authenticationDatabase admin
 */

db = db.getSiblingDB('fin1');

const targets = [
  { collection: 'AccountStatement', field: 'statementNumber' },
  { collection: 'Investment', field: 'investmentNumber' },
  { collection: 'InvestmentBatch', field: 'batchNumber' },
  { collection: 'Commission', field: 'commissionNumber' },
  { collection: 'Order', field: 'orderNumber' },
  { collection: 'Trade', field: 'tradeNumber' },
  { collection: 'Holding', field: 'positionNumber' },
  { collection: 'Invoice', field: 'invoiceNumber' },
  { collection: 'WalletTransaction', field: 'transactionNumber' },
  { collection: 'SupportTicket', field: 'ticketNumber' },
  { collection: 'GDPRRequest', field: 'requestNumber' },
];

print('=== fix_unique_number_indexes_sparse_fin1: start ===');

for (const t of targets) {
  const coll = db.getCollection(t.collection);
  const idxName = t.field + '_1';
  const existing = coll.getIndexes().find(i => i.name === idxName);
  if (!existing) {
    print('SKIP ' + t.collection + '.' + t.field + ' (no index ' + idxName + ' present)');
    continue;
  }
  const alreadyGood = existing.unique === true && existing.sparse === true;
  if (alreadyGood) {
    print('OK   ' + t.collection + '.' + t.field + ' (already unique+sparse)');
    continue;
  }
  print('FIX  ' + t.collection + '.' + t.field + ' (was unique=' + (existing.unique||false) + ', sparse=' + (existing.sparse||false) + ')');
  try { coll.dropIndex(idxName); } catch (e) { print('  dropIndex warn: ' + e.message); }
  const spec = {};
  spec[t.field] = 1;
  try {
    coll.createIndex(spec, { unique: true, sparse: true });
    print('  -> recreated as unique+sparse');
  } catch (e) {
    print('  createIndex FAILED: ' + e.message);
    // Wenn Recreate scheitert (z. B. doppelte vorhandene Werte), Index ohne Unique anlegen,
    // damit die Sammlung wenigstens schreibend nutzbar bleibt — und manuelle Daten-Bereinigung anfordern.
    try {
      coll.createIndex(spec, { sparse: true });
      print('  -> recreated as non-unique+sparse fallback (manual data cleanup required)');
    } catch (e2) {
      print('  fallback createIndex FAILED: ' + e2.message);
    }
  }
}

print('=== fix_unique_number_indexes_sparse_fin1: done ===');
