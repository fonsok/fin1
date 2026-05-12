// One-time: rename MongoDB collection PlatformLedgerEntry -> AppLedgerEntry
const db = db.getSiblingDB('fin1');
const from = 'PlatformLedgerEntry';
const to = 'AppLedgerEntry';
const names = db.getCollectionNames();
if (names.includes(from)) {
  db[from].renameCollection(to);
  print('OK: Renamed ' + from + ' to ' + to);
} else if (names.includes(to)) {
  print('OK: ' + to + ' already exists (migration done)');
} else {
  print('OK: No ' + from + ' collection (nothing to migrate)');
}
