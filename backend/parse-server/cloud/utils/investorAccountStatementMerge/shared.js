'use strict';

const INVESTMENT_REF_TYPES = ['Investment', 'investment'];
const ESCROW_TX_TYPES = ['investmentEscrow', 'appServiceCharge'];

/**
 * AVA legs posted with trade settlement that split pool vs profit credits on CLT-LIAB-AVA.
 * The customer-facing line is AccountStatement `investment_return`; showing these rows
 * duplicates the same cash effect (see statements.js SETTLEMENT_GL_RULES.investment_return).
 */
const INTERNAL_TRADE_SETTLEMENT_RELEASE_LEGS = new Set([
  'tradeSettlementPoolRelease',
  'tradeSettlementProfitRelease',
  'tradeSettlementPartialPoolRelease',
]);

const INVESTOR_STMT_SOURCE_LIMIT = 500;
const INVESTOR_ESCROW_SOURCE_LIMIT = 1000;

function dedupeParseObjectsById(rows) {
  const seen = new Set();
  return rows.filter((row) => {
    if (!row?.id || seen.has(row.id)) return false;
    seen.add(row.id);
    return true;
  });
}

function iso(d) {
  if (!d || !(d instanceof Date)) return new Date(0).toISOString();
  return d.toISOString();
}

module.exports = {
  INVESTMENT_REF_TYPES,
  ESCROW_TX_TYPES,
  INTERNAL_TRADE_SETTLEMENT_RELEASE_LEGS,
  INVESTOR_STMT_SOURCE_LIMIT,
  INVESTOR_ESCROW_SOURCE_LIMIT,
  dedupeParseObjectsById,
  iso,
};
