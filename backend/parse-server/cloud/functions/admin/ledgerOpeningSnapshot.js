'use strict';

/**
 * Admin: Eröffnungs-/Stichtagssalden fürs App-Hauptbuch (LedgerOpeningSnapshot).
 */

const { requirePermission } = require('../../utils/permissions');
const {
  saveLedgerOpeningSnapshot,
  listLedgerOpeningSnapshots,
  getLatestLedgerOpeningSnapshotBefore,
} = require('../../utils/accountingHelper/ledgerOpeningSnapshot');

async function handleSaveLedgerOpeningSnapshot(request) {
  requirePermission(request, 'getFinancialDashboard');
  const p = request.params || {};
  const row = await saveLedgerOpeningSnapshot({
    effectiveDate: p.effectiveDate,
    label: p.label,
    notes: p.notes,
    balances: p.balances,
    source: p.source,
  });
  return {
    objectId: row.id,
    effectiveDate: row.get('effectiveDate'),
    label: row.get('label'),
    balances: row.get('balances'),
    source: row.get('source'),
  };
}

async function handleListLedgerOpeningSnapshots(request) {
  requirePermission(request, 'getFinancialDashboard');
  const p = request.params || {};
  return listLedgerOpeningSnapshots({ limit: p.limit });
}

async function handleGetLatestLedgerOpeningSnapshotBefore(request) {
  requirePermission(request, 'getFinancialDashboard');
  const p = request.params || {};
  const t = p.periodStart || p.dateFrom || p.from;
  if (!t) {
    throw new Parse.Error(Parse.Error.INVALID_QUERY, 'periodStart oder dateFrom (ISO) erforderlich.');
  }
  const snap = await getLatestLedgerOpeningSnapshotBefore(new Date(t));
  return { snapshot: snap };
}

function registerLedgerOpeningSnapshotFunctions() {
  Parse.Cloud.define('saveLedgerOpeningSnapshot', handleSaveLedgerOpeningSnapshot);
  Parse.Cloud.define('listLedgerOpeningSnapshots', handleListLedgerOpeningSnapshots);
  Parse.Cloud.define('getLatestLedgerOpeningSnapshotBefore', handleGetLatestLedgerOpeningSnapshotBefore);
}

registerLedgerOpeningSnapshotFunctions();

module.exports = { registerLedgerOpeningSnapshotFunctions };
