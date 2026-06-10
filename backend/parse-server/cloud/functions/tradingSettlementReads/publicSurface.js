'use strict';

const { handleGetTradeSettlement } = require('./getTradeSettlement');
const { handleGetAccountStatement } = require('./getAccountStatement');
const { handleGetTradeInvoices } = require('./getTradeInvoices');
const { handleGetUserInvoices } = require('./getUserInvoices');

/** Tier 1 — registered Cloud Function handlers (stable read API). */
const tier1ReadHandlers = {
  handleGetTradeSettlement,
  handleGetAccountStatement,
  handleGetTradeInvoices,
  handleGetUserInvoices,
};

const publicSurface = { ...tier1ReadHandlers };

const API_TIERS = {
  readHandlers: Object.keys(tier1ReadHandlers),
};

module.exports = { publicSurface, API_TIERS };
