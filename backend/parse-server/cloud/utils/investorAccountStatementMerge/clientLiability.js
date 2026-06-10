'use strict';

const { round2 } = require('../accountingHelper/shared');
const {
  CLT_LIAB_AVA,
  CLT_LIAB_RSV,
  CLT_LIAB_PTR,
  normalizeClientLiabilityAccount,
} = require('../accountingHelper/clientLiabilityAccounts');

/** Netto-Saldo Kundensicht auf Teil-Verbindlichkeit (Haben − Soll). */
function netClientLiabilityBalance(rows, accountCode) {
  const target = normalizeClientLiabilityAccount(accountCode);
  let net = 0;
  for (const row of rows) {
    if (normalizeClientLiabilityAccount(row.get('account')) !== target) continue;
    const amt = Number(row.get('amount')) || 0;
    net += row.get('side') === 'credit' ? amt : -amt;
  }
  return round2(net);
}

function summarizeClientFundsFromEscrowRows(escrowRows, initialBalance) {
  const available = netClientLiabilityBalance(escrowRows, CLT_LIAB_AVA);
  const reserved = netClientLiabilityBalance(escrowRows, CLT_LIAB_RSV);
  const poolTrade = netClientLiabilityBalance(escrowRows, CLT_LIAB_PTR);
  const totalClientFunds = round2(available + reserved + poolTrade);
  return {
    initialBalance: round2(initialBalance),
    available,
    reserved,
    poolTrade,
    totalClientFunds,
    /** Abweichung Wallet vs. Teil-Verbindlichkeiten (wenn Wallet nicht mitgeführt). */
    walletReconcileHint: totalClientFunds,
  };
}

module.exports = {
  netClientLiabilityBalance,
  summarizeClientFundsFromEscrowRows,
};
