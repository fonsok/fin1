'use strict';

function totalsByAccountFromEntries(entries) {
  const totals = {};
  for (const e of entries) {
    const key = e.account;
    if (!totals[key]) totals[key] = { credit: 0, debit: 0, net: 0 };
    if (e.side === 'credit') {
      totals[key].credit += e.amount;
      totals[key].net += e.amount;
    } else {
      totals[key].debit += e.amount;
      totals[key].net -= e.amount;
    }
  }
  for (const key of Object.keys(totals)) {
    totals[key].credit = Math.round(totals[key].credit * 100) / 100;
    totals[key].debit = Math.round(totals[key].debit * 100) / 100;
    totals[key].net = Math.round(totals[key].net * 100) / 100;
  }
  return totals;
}

module.exports = {
  totalsByAccountFromEntries,
};
