'use strict';

const { requireAdminRole } = require('../../../utils/permissions');
const {
  envTrue,
  writeDevMaintenanceAudit,
  destroyParseObjectsTolerant,
} = require('./shared');

function statusRank(status) {
  switch (String(status || '').toLowerCase()) {
  case 'completed':
    return 4;
  case 'active':
  case 'executing':
  case 'closed':
  case 'closing':
  case 'paused':
    return 3;
  case 'reserved':
    return 2;
  case 'cancelled':
    return 1;
  default:
    return 0;
  }
}

function compareInvestmentPriority(a, b) {
  const rankA = statusRank(a.get('status'));
  const rankB = statusRank(b.get('status'));
  if (rankA !== rankB) return rankB - rankA;

  const updatedA = new Date(a.updatedAt || 0).getTime();
  const updatedB = new Date(b.updatedAt || 0).getTime();
  if (updatedA !== updatedB) return updatedB - updatedA;

  const createdA = new Date(a.createdAt || 0).getTime();
  const createdB = new Date(b.createdAt || 0).getTime();
  if (createdA !== createdB) return createdB - createdA;

  return String(b.id || '').localeCompare(String(a.id || ''));
}

function classifyDuplicateGroup(rows) {
  const sorted = [...rows].sort(compareInvestmentPriority);
  const keep = sorted[0];
  const losers = sorted.slice(1);

  // Conservative/safe cleanup: delete only stale reserved rows when a stronger
  // row for the same split exists. Anything else is review-only.
  const keepRank = statusRank(keep.get('status'));
  const removable = losers.filter((row) => statusRank(row.get('status')) <= 2 && keepRank >= 3);
  const reviewOnly = losers.filter((row) => !removable.includes(row));

  return { keep, removable, reviewOnly };
}

function groupKey(inv) {
  const investorId = String(inv.get('investorId') || '').trim();
  const batchId = String(inv.get('batchId') || '').trim();
  const seqRaw = Number(inv.get('sequenceNumber'));
  const seq = Number.isFinite(seqRaw) && seqRaw > 0 ? String(Math.trunc(seqRaw)) : '';
  if (!investorId || !batchId || !seq) return '';
  return `${investorId}::${batchId}::${seq}`;
}

function registerCleanupDuplicateInvestmentSplitsFunctions() {
  Parse.Cloud.define('cleanupDuplicateInvestmentSplits', async (request) => {
    requireAdminRole(request);

    const nodeEnv = String(process.env.NODE_ENV || '').toLowerCase();
    const enabled = envTrue('ALLOW_DEV_TRADING_RESET');
    const allowInProd = envTrue('ALLOW_DEV_TRADING_RESET_IN_PRODUCTION');
    if (!enabled) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Cleanup disabled (ALLOW_DEV_TRADING_RESET=false).');
    }
    if (nodeEnv === 'production' && !allowInProd) {
      throw new Parse.Error(
        Parse.Error.OPERATION_FORBIDDEN,
        'Cleanup blocked in production (set ALLOW_DEV_TRADING_RESET_IN_PRODUCTION=true to override).'
      );
    }

    const dryRun = request.params?.dryRun !== false;
    const scanLimit = Math.min(Math.max(Number(request.params?.scanLimit) || 1000, 1), 5000);

    const q = new Parse.Query('Investment');
    q.exists('investorId');
    q.exists('batchId');
    q.exists('sequenceNumber');
    q.limit(scanLimit);
    q.descending('updatedAt');
    const rows = await q.find({ useMasterKey: true });

    const groups = new Map();
    for (const row of rows) {
      const key = groupKey(row);
      if (!key) continue;
      const arr = groups.get(key) || [];
      arr.push(row);
      groups.set(key, arr);
    }

    const duplicateGroups = Array.from(groups.entries()).filter(([, arr]) => arr.length > 1);
    const decisions = duplicateGroups.map(([key, arr]) => ({ key, ...classifyDuplicateGroup(arr) }));

    const removableAll = decisions.flatMap((d) => d.removable);
    const reviewAll = decisions.flatMap((d) => d.reviewOnly);
    const keepAll = decisions.map((d) => d.keep);

    let deletedCount = 0;
    if (!dryRun && removableAll.length) {
      deletedCount = await destroyParseObjectsTolerant(removableAll);
    }

    const sample = decisions.slice(0, 20).map((d) => ({
      key: d.key,
      keep: {
        id: d.keep.id,
        status: String(d.keep.get('status') || ''),
        updatedAt: d.keep.updatedAt,
      },
      removableIds: d.removable.map((r) => r.id),
      reviewOnlyIds: d.reviewOnly.map((r) => r.id),
    }));

    const payload = {
      dryRun,
      nodeEnv,
      scanLimit,
      scannedRows: rows.length,
      duplicateGroupCount: duplicateGroups.length,
      keepCount: keepAll.length,
      removableCount: removableAll.length,
      reviewOnlyCount: reviewAll.length,
      deletedCount,
      sample,
    };

    await writeDevMaintenanceAudit({
      action: dryRun ? 'cleanup_duplicate_investment_splits_dry_run' : 'cleanup_duplicate_investment_splits_execute',
      request,
      payload,
    });

    return {
      success: true,
      ...payload,
      hint: dryRun
        ? 'Dry-run only. Re-run with dryRun=false to delete removable stale rows.'
        : 'Cleanup applied. Re-run dryRun=true to verify no removable duplicates remain.',
    };
  });
}

module.exports = {
  registerCleanupDuplicateInvestmentSplitsFunctions,
  classifyDuplicateGroup,
  compareInvestmentPriority,
  statusRank,
};
