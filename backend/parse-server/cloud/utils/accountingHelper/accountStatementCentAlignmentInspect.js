'use strict';

/**
 * ADR-018 P3c ops: sample recent AccountStatement rows for non-cent-aligned EUR fields.
 */

const { isCentAlignedEuro } = require('./moneyCents');

const MONETARY_FIELDS = ['amount', 'balanceBefore', 'balanceAfter'];

/**
 * @param {import('parse/node').Object} row
 * @returns {Array<{ field: string, value: number }>}
 */
function collectNonCentAlignedFields(row) {
  const bad = [];
  for (const field of MONETARY_FIELDS) {
    const raw = row.get(field);
    if (raw === undefined || raw === null) continue;
    const value = Number(raw);
    if (!isCentAlignedEuro(value)) {
      bad.push({ field, value });
    }
  }
  return bad;
}

/**
 * @param {import('parse/node').Cloud.FunctionRequest['params']} params
 */
async function inspectAccountStatementCentAlignment(params = {}) {
  const requestedLimit = Number(params.limitRows || 500);
  const limitRows = Math.min(5000, Math.max(1, requestedLimit));
  const previewLimit = Math.min(200, Math.max(1, Number(params.previewLimit || 25)));
  const filterUserId = String(params.userId || '').trim();

  const q = new Parse.Query('AccountStatement');
  if (filterUserId) {
    q.equalTo('userId', filterUserId);
  }
  q.descending('createdAt');
  q.limit(limitRows);
  const rows = await q.find({ useMasterKey: true });

  const violations = [];
  let examined = 0;
  let alignedRows = 0;
  let violationRows = 0;

  for (const row of rows) {
    examined += 1;
    const badFields = collectNonCentAlignedFields(row);
    if (!badFields.length) {
      alignedRows += 1;
      continue;
    }

    violationRows += 1;
    if (violations.length < previewLimit) {
      violations.push({
        id: row.id,
        userId: row.get('userId') || null,
        entryType: row.get('entryType') || null,
        tradeId: row.get('tradeId') || null,
        createdAt: row.createdAt ? row.createdAt.toISOString() : null,
        fields: badFields,
      });
    }
  }

  return {
    healthy: violationRows === 0,
    examined,
    alignedRows,
    violationRows,
    monetaryFields: MONETARY_FIELDS,
    limitRows,
    filterUserId: filterUserId || null,
    violations,
    previewTruncated: violationRows > violations.length,
  };
}

module.exports = {
  MONETARY_FIELDS,
  collectNonCentAlignedFields,
  inspectAccountStatementCentAlignment,
};
