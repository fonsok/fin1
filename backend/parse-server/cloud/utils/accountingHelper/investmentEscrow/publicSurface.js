'use strict';

/**
 * Stable public surface for investment escrow (facade re-exports this object only).
 * Tier manifest is used by contract tests; new callers must use Tier 1–3 only.
 */

const { bookReserve } = require('./escrowReserve');
const {
  bookDeployToTrading,
  bookDeployForPoolParticipation,
} = require('./escrowDeploy');
const {
  bookReleaseReservation,
  bookReleaseTrading,
  bookReleaseReservedOnComplete,
} = require('./escrowRelease');
const {
  purgeReleaseTradingResidualCorrectionLeg,
  purgeTradingResidualReturnLeg,
  purgeReserveCapitalTradeSplitLeg,
  purgeDeployReversalForCapitalSplitLeg,
} = require('./escrowRepair');
const {
  bookReserveCapitalTradeSplit,
  bookTradingResidualReturn,
} = require('./escrowCapitalSplit');
const {
  resolveActivationCapitalSplitAmounts,
  ensureReserveCapitalTradeSplitOnActivation,
} = require('./escrowActivation');
const { bookTradeSettlementPayout } = require('./escrowSettlement');
const {
  bookPartialSellPoolRelease,
  bookPartialSellProfitRecognition,
} = require('./escrowPartialSell');
const {
  hasEscrowLeg,
  hasTradeSettlementEscrow,
} = require('./ledgerQueries');

/** Tier 1 — stable booking use-cases (triggers, settlement, partial sell). */
const tier1StableBooking = {
  bookReserve,
  bookReleaseReservation,
  bookReleaseTrading,
  bookReleaseReservedOnComplete,
  ensureReserveCapitalTradeSplitOnActivation,
  bookReserveCapitalTradeSplit,
  bookTradeSettlementPayout,
  bookPartialSellPoolRelease,
  bookPartialSellProfitRecognition,
};

/** Tier 2 — settlement/repair support (idempotency checks, split amounts). */
const tier2SettlementSupport = {
  hasEscrowLeg,
  hasTradeSettlementEscrow,
  resolveActivationCapitalSplitAmounts,
};

/** Tier 3 — admin repair / backfill purge ops. */
const tier3RepairOps = {
  purgeReleaseTradingResidualCorrectionLeg,
  purgeTradingResidualReturnLeg,
  purgeReserveCapitalTradeSplitLeg,
  purgeDeployReversalForCapitalSplitLeg,
};

/**
 * Tier 4 — legacy / package-internal (not on facade).
 * Still implemented in submodules for in-package use:
 *   bookDeployToTrading, bookDeployForPoolParticipation, bookTradingResidualReturn,
 *   ledgerQueries sum* helpers, buildPairedLedgerEntries, TRANSACTION_TYPE.
 */
const tier4PackageInternal = {
  bookDeployToTrading,
  bookDeployForPoolParticipation,
  bookTradingResidualReturn,
};

const publicSurface = {
  ...tier1StableBooking,
  ...tier2SettlementSupport,
  ...tier3RepairOps,
};

const API_TIERS = {
  stableBooking: Object.keys(tier1StableBooking),
  settlementSupport: Object.keys(tier2SettlementSupport),
  repairOps: Object.keys(tier3RepairOps),
  packageInternal: Object.keys(tier4PackageInternal),
};

module.exports = {
  publicSurface,
  API_TIERS,
};
