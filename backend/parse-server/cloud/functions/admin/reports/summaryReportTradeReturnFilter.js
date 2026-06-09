'use strict';

const { buildTradeLegReturnPercentageMongoExpr } = require('../../../utils/accountingHelper/legPriceMetricsMongo');

const PRESET_RETURN_FILTERS = new Set([
  'gt:200',
  'gt:150',
  'gt:100',
  'gt:80',
  'gt:60',
  'gt:40',
  'gt:20',
  'gt:0',
  'lt:-10',
  'lt:-30',
  'lt:-50',
  'lt:-70',
  'lt:-90',
]);

const RETURN_OPS = new Set(['gt', 'gte', 'lt', 'lte']);

function trimParam(v) {
  if (v == null) return '';
  return String(v).trim();
}

/** SSOT: legPriceMetrics.resolveLegReturnPercentage (Einstand-Basis, inkl. Gebühren). */
function buildTradeReturnPercentageExpr(feeConfig = {}) {
  return buildTradeLegReturnPercentageMongoExpr(feeConfig);
}

function buildTradeReturnMongoClause(returnOp, returnThreshold, feeConfig = {}) {
  if (!returnOp || !RETURN_OPS.has(returnOp)) return null;
  const threshold = Number(returnThreshold);
  if (!Number.isFinite(threshold)) return null;
  const pct = buildTradeReturnPercentageExpr(feeConfig);
  const mongoOp = `$${returnOp}`;
  const persistedField = `legEconomicsSnapshot.returnPercentage`;
  return {
    $or: [
      { [persistedField]: { [returnOp]: threshold } },
      {
        $and: [
          {
            $or: [
              { legEconomicsSnapshot: { $exists: false } },
              { [persistedField]: { $exists: false } },
            ],
          },
          { $expr: { [mongoOp]: [pct, threshold] } },
        ],
      },
    ],
  };
}

function normalizeTradeReturnFilter(params = {}) {
  let returnFilter = trimParam(params.returnFilter);
  if (!returnFilter || returnFilter === 'any') return {};

  if (returnFilter === 'custom') {
    const op = trimParam(params.returnCustomOp);
    if (!RETURN_OPS.has(op)) return {};
    const pctRaw = parseFloat(String(params.returnCustomPct ?? '').replace(',', '.'));
    if (!Number.isFinite(pctRaw)) return {};
    return { returnOp: op, returnThreshold: pctRaw };
  }

  if (!PRESET_RETURN_FILTERS.has(returnFilter)) return {};
  const sep = returnFilter.indexOf(':');
  if (sep <= 0) return {};
  const op = returnFilter.slice(0, sep);
  const threshold = parseFloat(returnFilter.slice(sep + 1));
  if (!RETURN_OPS.has(op) || !Number.isFinite(threshold)) return {};
  return { returnOp: op, returnThreshold: threshold };
}

module.exports = {
  PRESET_RETURN_FILTERS,
  RETURN_OPS,
  buildTradeReturnPercentageExpr,
  buildTradeReturnMongoClause,
  normalizeTradeReturnFilter,
};
