'use strict';

const { APP_ACCOUNTS } = require('./shared');
const { aggregateTotalsAndCount } = require('./appLedgerCoreHelpers');
const { totalsByAccountFromEntries } = require('./appLedgerTotalsMath');
const { looksLikeParseObjectId } = require('./appLedgerParseIds');

async function buildAppLedgerTotalsAndCounts({
  filtered,
  account,
  userId,
  transactionType,
  dateFrom,
  dateTo,
  amountMin = null,
  amountMax = null,
  normalizedUserIdFilter,
  useMemoryFilterPath = false,
  memoryTotalCount = null,
}) {
  let totals = {};
  let effectiveTotalCount = memoryTotalCount ?? filtered.length;
  const userFilterIsFuzzy = normalizedUserIdFilter && !looksLikeParseObjectId(String(userId || '').trim());

  if (!useMemoryFilterPath && !userFilterIsFuzzy) {
    try {
      const aggregated = await aggregateTotalsAndCount({
        account,
        userId,
        transactionType,
        dateFrom,
        dateTo,
        amountMin,
        amountMax,
      });
      totals = aggregated.totals || {};
      effectiveTotalCount = aggregated.totalCount || 0;
    } catch (err) {
      console.warn('aggregateTotalsAndCount fallback to in-memory totals:', err.message);
    }
  }

  if (Object.keys(totals).length === 0) {
    totals = totalsByAccountFromEntries(filtered);
    if (useMemoryFilterPath || userFilterIsFuzzy) {
      effectiveTotalCount = filtered.length;
    } else if (!effectiveTotalCount) {
      effectiveTotalCount = filtered.length;
    }
  }

  const totalRevenue = APP_ACCOUNTS
    .filter((a) => a.group === 'revenue')
    .reduce((sum, a) => sum + (totals[a.code]?.net || 0), 0);

  const vatCollected = totals['PLT-TAX-VAT']?.credit || 0;
  const vatRemitted = totals['PLT-TAX-VAT']?.debit || 0;
  const inputVATClaimed = totals['PLT-TAX-VST']?.debit || 0;
  const vatSummary = {
    outputVATCollected: Math.round(vatCollected * 100) / 100,
    outputVATRemitted: Math.round(vatRemitted * 100) / 100,
    inputVATClaimed: Math.round(inputVATClaimed * 100) / 100,
    outstandingVATLiability: Math.round((vatCollected - vatRemitted - inputVATClaimed) * 100) / 100,
  };

  const totalRefunds = APP_ACCOUNTS
    .filter((a) => a.group === 'expense')
    .reduce((sum, a) => sum + (totals[a.code]?.debit || 0), 0);

  return {
    totals,
    totalRevenue,
    totalRefunds,
    vatSummary,
    effectiveTotalCount,
  };
}

module.exports = {
  buildAppLedgerTotalsAndCounts,
};
