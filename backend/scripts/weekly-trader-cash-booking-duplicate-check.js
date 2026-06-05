// Weekly duplicate check: backend trader cash bookings (trade_buy / trade_sell).
// Aggregation-only; writes OpsHealthSnapshot `trader-cash-booking-duplicates`.
// Requires opsFinanceSsot.mongodb.js prepended by run-finance-integrity-snapshots.sh.

/* global db, print, printjson */

const sampleLimit = 25;
const TRADER_CASH_ENTRY_TYPES = ['trade_buy', 'trade_sell'];
const accountStatements = db.getCollection('AccountStatement');

function duplicateGroups(groupIdFields, extraMatch) {
  return accountStatements.aggregate([
    {
      $match: Object.assign({
        source: 'backend',
        entryType: { $in: TRADER_CASH_ENTRY_TYPES },
      }, extraMatch || {}),
    },
    {
      $group: {
        _id: groupIdFields,
        count: { $sum: 1 },
        entryIds: { $push: '$_id' },
        amounts: { $push: '$amount' },
        tradeIds: { $addToSet: '$tradeId' },
        referenceDocumentNumbers: { $addToSet: '$referenceDocumentNumber' },
        createdAtMax: { $max: '$createdAt' },
      },
    },
    { $match: { count: { $gt: 1 } } },
    { $sort: { count: -1, createdAtMax: -1 } },
    { $limit: sampleLimit },
  ]).toArray();
}

const byTradeId = duplicateGroups(
  { userId: '$userId', entryType: '$entryType', tradeId: '$tradeId' },
  { tradeId: { $exists: true, $type: 'string', $ne: '' } },
);

const byBusinessCaseId = duplicateGroups(
  { userId: '$userId', entryType: '$entryType', businessCaseId: '$businessCaseId' },
  { businessCaseId: { $exists: true, $type: 'string', $ne: '' } },
);

const byTradeNumber = duplicateGroups(
  { userId: '$userId', entryType: '$entryType', tradeNumber: '$tradeNumber' },
  { tradeNumber: { $exists: true, $type: 'string', $ne: '' } },
);

const duplicateInvoicesByOrder = db.getCollection('Invoice').aggregate([
  { $match: { orderId: { $exists: true, $ne: null } } },
  {
    $group: {
      _id: { orderId: '$orderId', invoiceType: '$invoiceType' },
      count: { $sum: 1 },
      invoiceNumbers: { $addToSet: '$invoiceNumber' },
      invoiceIds: { $push: '$_id' },
      tradeIds: { $addToSet: '$tradeId' },
    },
  },
  { $match: { count: { $gt: 1 } } },
  { $limit: sampleLimit },
]).toArray();

const duplicateClientInvoiceDocs = db.getCollection('Document').aggregate([
  {
    $match: {
      type: 'invoice',
      tradeId: { $exists: true, $ne: null },
      $or: [{ source: { $exists: false } }, { source: { $ne: 'backend' } }],
    },
  },
  {
    $group: {
      _id: { tradeId: '$tradeId', userId: '$userId' },
      count: { $sum: 1 },
      documentNumbers: { $push: '$documentNumber' },
      documentIds: { $push: '$_id' },
    },
  },
  { $match: { count: { $gt: 1 } } },
  { $limit: sampleLimit },
]).toArray();

const violationCount = (
  byTradeId.length
  + byBusinessCaseId.length
  + byTradeNumber.length
  + duplicateInvoicesByOrder.length
  + duplicateClientInvoiceDocs.length
);

const samples = [];
function pushSamples(dimension, rows) {
  for (const row of rows) {
    if (samples.length >= sampleLimit) return;
    samples.push({
      dimension,
      userId: row._id.userId,
      entryType: row._id.entryType,
      key: Object.assign({}, row._id),
      count: row.count,
      entryIds: row.entryIds,
      amounts: row.amounts,
      tradeIds: row.tradeIds,
      referenceDocumentNumbers: row.referenceDocumentNumbers,
    });
  }
}
pushSamples('tradeId', byTradeId);
pushSamples('businessCaseId', byBusinessCaseId);
pushSamples('tradeNumber', byTradeNumber);
for (const row of duplicateInvoicesByOrder) {
  if (samples.length >= sampleLimit) break;
  samples.push({
    dimension: 'invoiceByOrderId',
    orderId: row._id.orderId,
    invoiceType: row._id.invoiceType,
    count: row.count,
    invoiceNumbers: row.invoiceNumbers,
    invoiceIds: row.invoiceIds,
    tradeIds: row.tradeIds,
  });
}
for (const row of duplicateClientInvoiceDocs) {
  if (samples.length >= sampleLimit) break;
  samples.push({
    dimension: 'clientInvoiceDocByTradeId',
    tradeId: row._id.tradeId,
    userId: row._id.userId,
    count: row.count,
    documentNumbers: row.documentNumbers,
    documentIds: row.documentIds,
  });
}

print('--- Weekly trader cash booking duplicate check ---');
print(`violationGroups=${violationCount}`);
print(`byTradeId=${byTradeId.length}`);
print(`byBusinessCaseId=${byBusinessCaseId.length}`);
print(`byTradeNumber=${byTradeNumber.length}`);
print(`duplicateInvoicesByOrder=${duplicateInvoicesByOrder.length}`);
print(`duplicateClientInvoiceDocs=${duplicateClientInvoiceDocs.length}`);
print(`healthy=${violationCount === 0}`);

if (samples.length > 0) {
  print(`violationSamples(limit=${sampleLimit})=`);
  samples.forEach((entry) => printjson(entry));
}

try {
  writeOpsHealthSnapshot({
    _id: 'trader-cash-booking-duplicates',
    kind: 'trader-cash-booking-duplicates',
    violationCount,
    byTradeId: byTradeId.length,
    byBusinessCaseId: byBusinessCaseId.length,
    byTradeNumber: byTradeNumber.length,
    duplicateInvoicesByOrder: duplicateInvoicesByOrder.length,
    duplicateClientInvoiceDocs: duplicateClientInvoiceDocs.length,
    healthy: violationCount === 0,
    violationSamples: samples,
  });
  print('snapshotWritten=OpsHealthSnapshot/trader-cash-booking-duplicates');
} catch (e) {
  print(`snapshotWriteError=${e && e.message ? e.message : String(e)}`);
}
