'use strict';

function summarizeTimelineAmounts(timeline, initialBalance) {
  const totalCredits = timeline.reduce((s, r) => (r.amount > 0 ? s + r.amount : s), 0);
  const totalDebits = timeline.reduce((s, r) => (r.amount < 0 ? s + Math.abs(r.amount) : s), 0);
  const closingBal = timeline.length > 0
    ? timeline[timeline.length - 1].balanceAfter
    : initialBalance;
  return {
    totalCredits: parseFloat(totalCredits.toFixed(2)),
    totalDebits: parseFloat(totalDebits.toFixed(2)),
    closingBalance: parseFloat(closingBal.toFixed(2)),
    netChange: parseFloat((totalCredits - totalDebits).toFixed(2)),
  };
}

module.exports = {
  summarizeTimelineAmounts,
};
