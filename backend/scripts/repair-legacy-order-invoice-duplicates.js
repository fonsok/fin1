// Advisory repair: remove duplicate buy invoices / client invoice documents for one order.
// Does NOT touch AccountStatement (real money). Dry-run by default.
//
// APPLY=1 mongosh fin1 repair-legacy-order-invoice-duplicates.js
//
// Env (mongosh): ORDER_ID, TRADE_ID (optional filters; defaults repair all detected groups)

/* global db, print, printjson */

const applyChanges = (typeof process !== 'undefined' && process.env && process.env.APPLY === '1');
const orderFilter = (typeof process !== 'undefined' && process.env && process.env.ORDER_ID) || null;
const tradeFilter = (typeof process !== 'undefined' && process.env && process.env.TRADE_ID) || null;

function pickInvoiceToKeep(invoices) {
  const sorted = invoices.slice().sort((a, b) => {
    const aBackend = a.source === 'backend' ? 1 : 0;
    const bBackend = b.source === 'backend' ? 1 : 0;
    if (bBackend !== aBackend) return bBackend - aBackend;
    const aNum = String(a.invoiceNumber || '');
    const bNum = String(b.invoiceNumber || '');
    return aNum.localeCompare(bNum);
  });
  return { keep: sorted[0], remove: sorted.slice(1) };
}

print(`=== Repair legacy order invoice duplicates === mode=${applyChanges ? 'APPLY' : 'DRY-RUN'}`);

const duplicateInvoiceGroups = db.Invoice.aggregate([
  { $match: { orderId: { $exists: true, $ne: null }, invoiceType: 'buy_invoice' } },
  {
    $group: {
      _id: '$orderId',
      count: { $sum: 1 },
      invoices: {
        $push: {
          _id: '$_id',
          invoiceNumber: '$invoiceNumber',
          tradeId: '$tradeId',
          source: '$source',
          createdAt: '$createdAt',
        },
      },
    },
  },
  { $match: { count: { $gt: 1 } } },
]).toArray();

let removedInvoices = 0;
let removedClientDocs = 0;

for (const group of duplicateInvoiceGroups) {
  const orderId = group._id;
  if (orderFilter && orderId !== orderFilter) continue;

  const { keep, remove } = pickInvoiceToKeep(group.invoices);
  printjson({ orderId, keep: keep._id, keepNumber: keep.invoiceNumber, removeIds: remove.map((r) => r._id) });

  for (const inv of remove) {
    if (applyChanges) {
      db.Invoice.deleteOne({ _id: inv._id });
    }
    removedInvoices += 1;
  }

  const tradeIds = [...new Set(group.invoices.map((i) => i.tradeId).filter(Boolean))];
  for (const tradeId of tradeIds) {
    if (tradeFilter && tradeId !== tradeFilter) continue;
    const clientDocs = db.Document.find({
      tradeId,
      type: 'invoice',
      $or: [{ source: { $exists: false } }, { source: { $ne: 'backend' } }],
    }).toArray();
    if (clientDocs.length <= 1) continue;
    printjson({
      tradeId,
      clientDocsToRemove: clientDocs.map((d) => ({ _id: d._id, documentNumber: d.documentNumber })),
    });
    for (const doc of clientDocs) {
      if (applyChanges) {
        db.Document.deleteOne({ _id: doc._id });
      }
      removedClientDocs += 1;
    }
  }
}

print(`removedInvoices=${removedInvoices}`);
print(`removedClientDocs=${removedClientDocs}`);
print(`done=${applyChanges ? 'applied' : 'dry-run-only'}`);
