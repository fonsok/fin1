'use strict';

const { allocateSequentialCounter } = require('./helpers');

const BERLIN_TZ = 'Europe/Berlin';
const SEQUENCE_COUNTER_CLASS = 'SequenceCounter';

/**
 * Calendar year in Berlin for trade-number sequences (annual reset per trader).
 * @param {Date|string|number|undefined} date
 * @returns {number}
 */
function getTradeNumberCalendarYear(date = new Date()) {
  const value = date instanceof Date ? date : new Date(date);
  const safeDate = Number.isFinite(value.getTime()) ? value : new Date();
  const formatter = new Intl.DateTimeFormat('en-CA', {
    timeZone: BERLIN_TZ,
    year: 'numeric',
  });
  return Number(formatter.format(safeDate));
}

/**
 * @param {number} tradeNumber
 * @param {number|null|undefined} tradeNumberYear
 * @returns {string}
 */
function formatTradeNumberForDisplay(tradeNumber, tradeNumberYear) {
  const number = Number(tradeNumber);
  if (!Number.isFinite(number) || number <= 0) return '';
  const seq = String(number).padStart(3, '0');
  const year = Number(tradeNumberYear);
  if (Number.isFinite(year) && year > 0) return `${year}-${seq}`;
  return seq;
}

/**
 * User-facing label, e.g. `Trade #2026-001`.
 * @param {number} tradeNumber
 * @param {number|null|undefined} tradeNumberYear
 * @returns {string}
 */
function formatTradeNumberLabel(tradeNumber, tradeNumberYear) {
  const value = formatTradeNumberForDisplay(tradeNumber, tradeNumberYear);
  return value ? `Trade #${value}` : '';
}

/**
 * Resolve number, year, display and filename token from a Parse Trade (or plain object).
 * @param {import('parse').Object|Record<string, unknown>} trade
 * @returns {{
 *   tradeNumber: number|null,
 *   tradeNumberYear: number,
 *   formattedTradeNumber: string,
 *   filenameToken: string,
 *   label: string,
 * }}
 */
function resolveTradeNumberPresentation(trade) {
  const get = typeof trade.get === 'function'
    ? (key) => trade.get(key)
    : (key) => trade[key];

  const rawNumber = Number(get('tradeNumber'));
  const tradeNumber = Number.isFinite(rawNumber) && rawNumber > 0 ? rawNumber : null;
  const tradeNumberYear = resolveTradeNumberYear(trade);
  const formattedTradeNumber = formatTradeNumberForDisplay(tradeNumber, tradeNumberYear);
  const filenameToken = formattedTradeNumber || (tradeNumber != null ? String(tradeNumber) : '');
  return {
    tradeNumber,
    tradeNumberYear,
    formattedTradeNumber,
    filenameToken,
    label: formatTradeNumberLabel(tradeNumber, tradeNumberYear),
  };
}

/**
 * Resolve persisted or inferred trade-number year from a Parse Trade row.
 * @param {import('parse').Object|Record<string, unknown>} trade
 * @returns {number}
 */
function resolveTradeNumberYear(trade) {
  const get = typeof trade.get === 'function'
    ? (key) => trade.get(key)
    : (key) => trade[key];

  const explicit = Number(get('tradeNumberYear'));
  if (Number.isFinite(explicit) && explicit > 0) return explicit;

  const createdAt = get('createdAt');
  if (createdAt) return getTradeNumberCalendarYear(createdAt);

  return getTradeNumberCalendarYear();
}

/**
 * SequenceCounter key for per-trader, per-year trade numbers.
 * @param {string} traderId
 * @param {number} tradeNumberYear
 * @returns {string}
 */
function buildTradeNumberCounterKey(traderId, tradeNumberYear) {
  return `Trade::tradeNumber::${String(traderId || '').trim()}::${tradeNumberYear}`;
}

/**
 * Highest existing trade number for a trader within a calendar year (seed for SequenceCounter).
 * @param {string} traderId
 * @param {number} tradeNumberYear
 * @returns {Promise<number>}
 */
async function readMaxTradeNumberForTraderYear(traderId, tradeNumberYear) {
  const stableTraderId = String(traderId || '').trim();
  if (!stableTraderId) return 0;

  const q = new Parse.Query('Trade');
  q.equalTo('traderId', stableTraderId);
  q.equalTo('tradeNumberYear', tradeNumberYear);
  q.descending('tradeNumber');
  q.limit(1);
  const last = await q.first({ useMasterKey: true });
  const lastNumber = Number(last?.get('tradeNumber') || 0);
  return Number.isFinite(lastNumber) && lastNumber > 0 ? lastNumber : 0;
}

/**
 * Allocate next trade number for a trader within the calendar year (Europe/Berlin).
 * Race-safe via SequenceCounter (same pattern as order/ticket numbers).
 * @param {string} traderId
 * @param {Date|string|number|undefined} referenceDate
 * @returns {Promise<{ tradeNumber: number, tradeNumberYear: number }>}
 */
async function allocateNextTradeNumberForTrader(traderId, referenceDate = new Date()) {
  const stableTraderId = String(traderId || '').trim();
  if (!stableTraderId) {
    throw new Error('allocateNextTradeNumberForTrader: traderId required');
  }

  const tradeNumberYear = getTradeNumberCalendarYear(referenceDate);
  const key = buildTradeNumberCounterKey(stableTraderId, tradeNumberYear);
  const tradeNumber = await allocateSequentialCounter(
    key,
    () => readMaxTradeNumberForTraderYear(stableTraderId, tradeNumberYear),
  );

  return { tradeNumber, tradeNumberYear };
}

module.exports = {
  BERLIN_TZ,
  SEQUENCE_COUNTER_CLASS,
  getTradeNumberCalendarYear,
  formatTradeNumberForDisplay,
  formatTradeNumberLabel,
  resolveTradeNumberPresentation,
  resolveTradeNumberYear,
  buildTradeNumberCounterKey,
  readMaxTradeNumberForTraderYear,
  allocateNextTradeNumberForTrader,
};
