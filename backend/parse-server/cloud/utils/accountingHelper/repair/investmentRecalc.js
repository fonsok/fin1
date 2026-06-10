'use strict';

const { round2 } = require('../shared');
const { findOtherSettledParticipationsForInvestment } = require('./queries');

function resetParticipation(part) {
  part.set('profitShare', 0);
  part.set('commissionAmount', 0);
  part.set('commissionRate', 0);
  part.set('grossReturn', 0);
  part.set('isSettled', false);
  part.unset('settledAt');
  part.unset('profitBasis');
  return part;
}

async function recalcInvestmentTotalsFromOtherTrades({ investment, excludeTradeId }) {
  // Re-derive Investment.profit / commission / currentValue / numberOfTrades
  // from the participations of OTHER (still-settled) trades. If no other
  // settled participation remains, the Investment is reset to its initial
  // capital state — same as before any trade ran on it.
  const others = await findOtherSettledParticipationsForInvestment(
    investment.id,
    excludeTradeId,
  );

  let totalProfit = 0;
  let totalCommission = 0;
  for (const p of others) {
    totalProfit += Number(p.get('grossReturn') || 0); // grossReturn = netProfit per participation
    totalCommission += Number(p.get('commissionAmount') || 0);
  }

  const initialValue =
    Number(investment.get('initialValue')) ||
    Number(investment.get('amount')) ||
    0;

  investment.set('numberOfTrades', others.length);
  investment.set('profit', round2(totalProfit));
  investment.set('totalCommissionPaid', round2(totalCommission));
  investment.set('currentValue', round2(initialValue + totalProfit));
  if (initialValue > 0) {
    investment.set('profitPercentage', round2((totalProfit / initialValue) * 100));
  } else {
    investment.set('profitPercentage', 0);
  }

  // Note: we deliberately keep `status` and `completedAt` as-is. The Investment
  // beforeSave trigger forbids `completed → active` transitions, and changing
  // status here is unnecessary: the subsequent `settleAndDistribute` re-runs
  // will increment the counters back to their correct values, leaving the
  // investment in the same `completed` lifecycle state with corrected
  // numeric totals (profit / commission / currentValue / numberOfTrades).
  return investment;
}

module.exports = {
  resetParticipation,
  recalcInvestmentTotalsFromOtherTrades,
};
