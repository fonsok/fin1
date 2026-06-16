'use strict';

/**
 * P3c-2a: cent-normalize monetary fields in Beleg metadata at persist boundaries.
 * See Documentation/ADR-018-P3c-Monetary-Cent-Integer-Boundaries.md
 */

const {
  euroToCents,
  centsToEuro,
  TOLERANCE_CENTS,
} = require('./moneyCents');

const FEE_LINE_KEYS = ['orderFee', 'exchangeFee', 'foreignCosts', 'totalFees'];

const TAX_LINE_KEYS = [
  'withholdingTax',
  'solidaritySurcharge',
  'churchTax',
  'totalTax',
];

const TRADER_TOP_LEVEL_MONEY = ['amount', 'totalWithFees'];

const INVESTOR_TOP_LEVEL_MONEY = [
  'investmentNominal',
  'grossProfit',
  'commission',
  'netProfit',
  'transferAmount',
  'totalBuyCost',
  'netSellAmount',
  'residualAmount',
  'poolTradingAmount',
  'traderCommission',
  'appCommission',
];

const LEG_MONEY_KEYS = [
  'amount',
  'totalBuyCost',
  'netSellAmount',
  'residualAmount',
  'bookedTotalBuyCost',
];

function formatContext(context) {
  try {
    return JSON.stringify(context || {});
  } catch {
    return '{}';
  }
}

/**
 * @param {number|string|null|undefined} value
 * @param {string} fieldPath
 * @param {object} [context]
 * @returns {number|null|undefined}
 */
function normalizeMoneyField(value, fieldPath, context = {}) {
  if (value == null) return value;
  const n = Number(value);
  if (!Number.isFinite(n)) {
    throw new Error(
      `belegMetadataMoney: non-finite ${fieldPath} (${value}) ${formatContext(context)}`,
    );
  }
  return centsToEuro(euroToCents(n));
}

function normalizeFeesObject(fees, fieldPrefix, context = {}) {
  if (!fees || typeof fees !== 'object') return fees;
  const out = Object.assign({}, fees);
  for (const key of FEE_LINE_KEYS) {
    if (out[key] != null) {
      out[key] = normalizeMoneyField(out[key], `${fieldPrefix}.${key}`, context);
    }
  }
  return out;
}

function normalizeTaxBreakdown(taxBreakdown, context = {}) {
  if (!taxBreakdown || typeof taxBreakdown !== 'object') return taxBreakdown;
  const out = Object.assign({}, taxBreakdown);
  for (const key of TAX_LINE_KEYS) {
    if (out[key] != null) {
      out[key] = normalizeMoneyField(out[key], `taxBreakdown.${key}`, context);
    }
  }
  return out;
}

function normalizeLegMoney(leg, fieldPrefix, context = {}) {
  if (!leg || typeof leg !== 'object') return leg;
  const out = Object.assign({}, leg);
  for (const key of LEG_MONEY_KEYS) {
    if (out[key] != null) {
      out[key] = normalizeMoneyField(out[key], `${fieldPrefix}.${key}`, context);
    }
  }
  if (out.fees) {
    out.fees = normalizeFeesObject(out.fees, `${fieldPrefix}.fees`, context);
  }
  return out;
}

function isCentAlignedEuro(value) {
  if (value == null) return true;
  const n = Number(value);
  if (!Number.isFinite(n)) return false;
  return euroToCents(n) === euroToCents(centsToEuro(euroToCents(n)));
}

/**
 * @param {object} metadata
 * @param {object} [context]
 * @returns {object}
 */
function finalizeTraderBelegMetadata(metadata, context = {}) {
  if (!metadata || typeof metadata !== 'object') {
    throw new Error(`belegMetadataMoney: metadata must be object ${formatContext(context)}`);
  }
  const out = Object.assign({}, metadata);

  for (const key of TRADER_TOP_LEVEL_MONEY) {
    if (out[key] != null) {
      out[key] = normalizeMoneyField(out[key], key, context);
    }
  }
  if (out.fees) {
    out.fees = normalizeFeesObject(out.fees, 'fees', context);
  }

  return out;
}

/**
 * @param {object} metadata
 * @param {object} [context]
 * @returns {object}
 */
function finalizeInvestorBelegMetadata(metadata, context = {}) {
  if (!metadata || typeof metadata !== 'object') {
    throw new Error(`belegMetadataMoney: metadata must be object ${formatContext(context)}`);
  }
  const out = Object.assign({}, metadata);

  for (const key of INVESTOR_TOP_LEVEL_MONEY) {
    if (out[key] != null) {
      out[key] = normalizeMoneyField(out[key], key, context);
    }
  }
  if (out.buyLeg) {
    out.buyLeg = normalizeLegMoney(out.buyLeg, 'buyLeg', context);
  }
  if (out.sellLeg) {
    out.sellLeg = normalizeLegMoney(out.sellLeg, 'sellLeg', context);
  }
  if (out.taxBreakdown) {
    out.taxBreakdown = normalizeTaxBreakdown(out.taxBreakdown, context);
  }

  return out;
}

/**
 * Single persist-boundary guard for Document.metadata writes.
 * @param {object} metadata
 * @param {{ kind?: string, tradeId?: string, documentNumber?: string }} [options]
 * @returns {object}
 */
function finalizeBelegMetadataForPersist(metadata, options = {}) {
  const context = {
    kind: options.kind || metadata?.belegKind || null,
    tradeId: options.tradeId || null,
    documentNumber: options.documentNumber || null,
  };

  const kind = String(context.kind || '').trim();
  if (kind === 'investorCollectionBill') {
    return finalizeInvestorBelegMetadata(metadata, context);
  }
  return finalizeTraderBelegMetadata(metadata, context);
}

module.exports = {
  TOLERANCE_CENTS,
  FEE_LINE_KEYS,
  TRADER_TOP_LEVEL_MONEY,
  INVESTOR_TOP_LEVEL_MONEY,
  normalizeMoneyField,
  normalizeFeesObject,
  finalizeTraderBelegMetadata,
  finalizeInvestorBelegMetadata,
  finalizeBelegMetadataForPersist,
  isCentAlignedEuro,
};
