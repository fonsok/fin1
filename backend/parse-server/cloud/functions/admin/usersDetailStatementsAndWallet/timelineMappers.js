'use strict';

const { syntheticEntryTypeFromLedgerRow } = require('../../../utils/investorAccountStatementMerge');

function mapInvestorTimelineToAdminEntries(timeline, formatDate) {
  const accountStatementEntries = [];
  for (const row of timeline) {
    const balanceAfter = row.balanceAfter;
    if (row.kind === 'stmt') {
      const e = row.stmt;
      accountStatementEntries.push({
        objectId: e.id,
        entryType: e.get('entryType'),
        amount: row.amount,
        balanceAfter,
        tradeId: e.get('tradeId'),
        tradeNumber: e.get('tradeNumber'),
        investmentId: e.get('investmentId'),
        description: e.get('description'),
        referenceDocumentId: e.get('referenceDocumentId') || null,
        referenceDocumentNumber: e.get('referenceDocumentNumber') || null,
        source: e.get('source'),
        createdAt: formatDate(e.get('createdAt')),
      });
    } else {
      const r = row.ledger;
      const meta = r.get('metadata') || {};
      const refType = String(r.get('referenceType') || '');
      const investmentId = refType === 'Investment' ? r.get('referenceId') : null;
      accountStatementEntries.push({
        objectId: `app-ledger:${r.id}`,
        entryType: syntheticEntryTypeFromLedgerRow(r),
        amount: row.amount,
        balanceAfter,
        tradeId: r.get('tradeId') || null,
        tradeNumber: r.get('tradeNumber') || null,
        investmentId,
        description: r.get('description') || syntheticEntryTypeFromLedgerRow(r),
        referenceDocumentId: meta.referenceDocumentId || null,
        source: 'app_subledger',
        createdAt: formatDate(r.get('createdAt')),
      });
    }
  }
  return accountStatementEntries;
}

function mapTraderTimelineToAdminEntries(timeline, formatDate) {
  return timeline.map((event) => ({
    objectId: String(event.objectId),
    entryType: event.entryType,
    amount: event.amount,
    balanceAfter: event.balanceAfter,
    tradeId: event.tradeId || undefined,
    tradeNumber: event.tradeNumber ?? undefined,
    investmentId: undefined,
    description: event.statementTitle || event.description || event.entryType,
    referenceDocumentId: event.referenceDocumentId || null,
    referenceDocumentNumber: event.referenceDocumentNumber || null,
    source: event.source || 'customer_display',
    createdAt: formatDate(event.at),
  }));
}

module.exports = {
  mapInvestorTimelineToAdminEntries,
  mapTraderTimelineToAdminEntries,
};
