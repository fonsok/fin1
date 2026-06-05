'use strict';

/**
 * Client-funds sub-ledger (CLT-LIAB-*): reserve → pool trade (PTR) → release.
 * Balanced pairs only; idempotent per investmentId + metadata.leg.
 * See Documentation/INVESTMENT_ESCROW_LEDGER_SKETCH.md
 */

const { round2, resolveTradeBuyPrice } = require('./shared');
const {
  applyLedgerSnapshotToEntry,
  mergeMetadataWithSnapshot,
} = require('./accountMappingResolver');
const { createInvestmentReservationEigenbelegDocument } = require('./documents');
const { computeInvestorBuyLeg } = require('./legs');
const { loadConfig } = require('../configHelper/index.js');
const { mergeInvestorFeeConfig } = require('./feeConfigSnapshot');
const { ensureBusinessCaseIdForTrade } = require('./businessCaseId');
const { bookAccountStatementEntry } = require('./statements');
const { resolveCanonicalUserId } = require('../canonicalUserId');
const { audit } = require('../structuredLogger');
const {
  CLT_LIAB_AVA,
  CLT_LIAB_RSV,
  CLT_LIAB_PTR,
  CLT_LIAB_TRD_LEGACY,
} = require('./clientLiabilityAccounts');

const POOL_TRADE_ACCOUNTS = [CLT_LIAB_PTR, CLT_LIAB_TRD_LEGACY];
/** Investor-Erfolg bei Trade-Abwicklung (Schritt 4, Gegenkonto zu AVA). */
const CLT_EQT_INV_PNL = 'CLT-EQT-INV-PNL';

const TRANSACTION_TYPE = 'investmentEscrow';
const REFERENCE_TYPE = 'Investment';

async function hasEscrowLeg(investmentId, leg, { tradeId } = {}) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(100);
  const rows = await q.find({ useMasterKey: true });
  const tradeKey = tradeId != null ? String(tradeId).trim() : '';
  return rows.some((e) => {
    const m = e.get('metadata') || {};
    if (m.leg !== leg) return false;
    if (!tradeKey) return true;
    return String(m.tradeId || '').trim() === tradeKey;
  });
}

async function sumEscrowPoolTradeDebitForLeg(investmentId, leg) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.containedIn('account', POOL_TRADE_ACCOUNTS);
  q.equalTo('side', 'debit');
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });
  return rows.reduce((sum, e) => {
    const m = e.get('metadata') || {};
    if (m.leg !== leg) return sum;
    return round2(sum + (Number(e.get('amount')) || 0));
  }, 0);
}

/** Restbetrag auf AVA (reserveCapitalTradeSplit oder Legacy tradingResidualReturn). */
async function sumCapitalSplitToAvailable(investmentId) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });
  return rows.reduce((sum, e) => {
    const m = e.get('metadata') || {};
    const amt = Number(e.get('amount')) || 0;
    if (m.leg === 'reserveCapitalTradeSplit' && e.get('account') === CLT_LIAB_AVA && e.get('side') === 'credit') {
      return round2(sum + amt);
    }
    if (m.leg === 'tradingResidualReturn' && POOL_TRADE_ACCOUNTS.includes(e.get('account')) && e.get('side') === 'debit') {
      return round2(sum + amt);
    }
    return sum;
  }, 0);
}

/**
 * GoB: Folgebuchungen (deploy, release, …) beziehen sich auf denselben Eigenbeleg wie `leg: reserve`.
 * Liest `metadata.referenceDocumentId` / `referenceDocumentNumber` von einer bestehenden Reserve-Zeile.
 */
async function eigenbelegRefFromReserveLeg(investmentId) {
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(100);
  const rows = await q.find({ useMasterKey: true });
  for (const e of rows) {
    const m = e.get('metadata') || {};
    if (m.leg !== 'reserve') continue;
    const id = String(m.referenceDocumentId || '').trim();
    const num = String(m.referenceDocumentNumber || '').trim();
    if (id && num) {
      return { referenceDocumentId: id, referenceDocumentNumber: num };
    }
  }
  return {};
}

function baseFields(investorId, investmentId, leg, description, extraMeta = {}) {
  const invNum = String(extraMeta.investmentNumber || '').trim();
  const businessReference = invNum ? `Investition ${invNum}` : '';
  return {
    userId: investorId || '',
    userRole: 'investor',
    transactionType: TRANSACTION_TYPE,
    referenceId: investmentId,
    referenceType: REFERENCE_TYPE,
    description,
    metadata: Object.assign({ leg, businessReference }, extraMeta),
  };
}

function buildPairedLedgerEntries(debitAccount, creditAccount, amount, common) {
  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const d = new AppLedgerEntry();
  d.set('account', debitAccount);
  const debitSnapshot = applyLedgerSnapshotToEntry(d, debitAccount);
  d.set('side', 'debit');
  d.set('amount', amount);
  d.set('userId', common.userId);
  d.set('userRole', common.userRole);
  d.set('transactionType', common.transactionType);
  d.set('referenceId', common.referenceId);
  d.set('referenceType', common.referenceType);
  d.set('description', common.description);
  d.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, common.metadata, { pairedAccount: creditAccount }),
    debitSnapshot,
  ));

  const c = new AppLedgerEntry();
  c.set('account', creditAccount);
  const creditSnapshot = applyLedgerSnapshotToEntry(c, creditAccount);
  c.set('side', 'credit');
  c.set('amount', amount);
  c.set('userId', common.userId);
  c.set('userRole', common.userRole);
  c.set('transactionType', common.transactionType);
  c.set('referenceId', common.referenceId);
  c.set('referenceType', common.referenceType);
  c.set('description', common.description);
  c.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, common.metadata, { pairedAccount: debitAccount }),
    creditSnapshot,
  ));

  return [d, c];
}

function buildSingleLedgerEntry(account, side, amount, common, extraMeta = {}) {
  const AppLedgerEntry = Parse.Object.extend('AppLedgerEntry');
  const row = new AppLedgerEntry();
  row.set('account', account);
  const snapshot = applyLedgerSnapshotToEntry(row, account);
  row.set('side', side);
  row.set('amount', amount);
  row.set('userId', common.userId);
  row.set('userRole', common.userRole);
  row.set('transactionType', common.transactionType);
  row.set('referenceId', common.referenceId);
  row.set('referenceType', common.referenceType);
  row.set('description', common.description);
  row.set('metadata', mergeMetadataWithSnapshot(
    Object.assign({}, common.metadata, extraMeta),
    snapshot,
  ));
  return row;
}

async function savePair(debitAccount, creditAccount, amount, common) {
  if (amount <= 0) return;
  const pair = buildPairedLedgerEntries(debitAccount, creditAccount, amount, common);
  await Parse.Object.saveAll(pair, { useMasterKey: true });
}

/**
 * New investment (reserved): available → reserved
 *
 * GoB: **Erst Beleg, dann Buchung.** Persistierter Eigenbeleg (Document) muss
 * vor dem App-Ledger-Paar existieren; ohne Beleg findet keine Reservierung statt.
 */
async function bookReserve({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  parseInvestment,
}) {
  const amt = round2(amount);
  if (amt <= 0) return { ok: true, skipped: 'non_positive' };

  const objId = parseInvestment && typeof parseInvestment.get === 'function'
    ? (parseInvestment.id || parseInvestment.get('objectId'))
    : null;
  const paramId = investmentId != null ? String(investmentId).trim() : '';
  const resolvedId = String(objId || paramId || '').trim();
  if (!resolvedId) {
    console.error('❌ bookReserve abgebrochen: objectId fehlt — GoB erfordert Eigenbeleg vor Buchung.');
    return { ok: false, reason: 'missing_object_id' };
  }
  if (objId && paramId && String(objId) !== paramId) {
    console.warn(
      `bookReserve: investmentId (${paramId}) weicht von parseInvestment.id (${objId}) ab — nutze ${resolvedId}`,
    );
  }

  if (await hasEscrowLeg(resolvedId, 'reserve')) {
    return { ok: true, skipped: 'already_booked' };
  }

  if (!parseInvestment || typeof parseInvestment.get !== 'function') {
    console.error(
      `❌ bookReserve abgebrochen (${resolvedId}): parseInvestment fehlt — GoB erfordert Eigenbeleg vor Buchung.`,
    );
    return { ok: false, reason: 'missing_parse_investment' };
  }

  let doc;
  try {
    doc = await createInvestmentReservationEigenbelegDocument(parseInvestment);
  } catch (err) {
    console.error(`❌ Eigenbeleg Reservierung fehlgeschlagen, Buchung unterbleibt ${resolvedId}:`, err.message);
    return { ok: false, reason: 'eigenbeleg_failed', detail: err.message };
  }
  if (!doc) {
    console.error(`❌ Eigenbeleg Reservierung nicht erstellbar, Buchung unterbleibt ${resolvedId}`);
    return { ok: false, reason: 'eigenbeleg_null' };
  }

  const desc = `Kundenguthaben reserviert${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${resolvedId}`;
  const docNum = String(doc.get('accountingDocumentNumber') || doc.get('documentNumber') || '').trim();
  const bcReserve = String(parseInvestment.get('businessCaseId') || '').trim();
  await savePair(
    'CLT-LIAB-AVA',
    'CLT-LIAB-RSV',
    amt,
    baseFields(investorId, resolvedId, 'reserve', desc, {
      investmentNumber: investmentNumber || '',
      referenceDocumentId: doc.id,
      referenceDocumentNumber: docNum,
      businessReference: docNum ? `Beleg ${docNum}` : '',
      ...(bcReserve ? { businessCaseId: bcReserve } : {}),
    }),
  );
  return { ok: true };
}

/**
 * reserved → active: RSV → TRD (Pool) optional mit Teilbetrag; Differenz zum
 * Reservierungs-Nominal (Investment.amount) geht RSV → AVA (Rest nach Zuteilung).
 *
 * @param {object} opts
 * @param {string} opts.investorId
 * @param {number} opts.amount – Betrag RSV→TRD (effektiv „Investment − Rest“ / Zuteilung)
 * @param {number} [opts.reservedNominal] – volles reserviertes Nominal; default = amount (nur RSV→TRD)
 * @param {string} opts.investmentId
 * @param {string} [opts.investmentNumber]
 * @param {string} [opts.businessCaseId]
 */
async function bookDeployToTrading({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  businessCaseId,
  reservedNominal,
}) {
  const deployPrincipal = round2(Number(amount) || 0);
  const nominal = round2(
    reservedNominal !== undefined && reservedNominal !== null
      ? Number(reservedNominal)
      : deployPrincipal,
  );
  if (nominal <= 0) return;
  if (await hasEscrowLeg(investmentId, 'deploy')) return;

  const deployToTrd = round2(Math.min(nominal, Math.max(0, deployPrincipal)));
  const residualToAva = round2(Math.max(0, nominal - deployToTrd));

  if (deployToTrd <= 0) {
    if (residualToAva > 0) {
      console.error(
        `❌ bookDeployToTrading: Zuteilungsbetrag <= 0 bei positivem Nominal; keine Buchung (${investmentId})`,
      );
    }
    return;
  }

  const invNum = investmentNumber || '';
  const descTrd = `Kundenguthaben Handel/Pool${invNum ? ` (${invNum})` : ''} – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  const commonMeta = {
    investmentNumber: invNum,
    ...eigenbelegRef,
    ...(bc ? { businessCaseId: bc } : {}),
  };

  const rows = buildPairedLedgerEntries(
    'CLT-LIAB-RSV',
    CLT_LIAB_PTR,
    deployToTrd,
    baseFields(investorId, investmentId, 'deploy', descTrd, commonMeta),
  );
  if (residualToAva > 0) {
    const descAva = `Kundenguthaben Rest nach Pool-Zuteilung${invNum ? ` (${invNum})` : ''} – Investment ${investmentId}`;
    rows.push(...buildPairedLedgerEntries(
      'CLT-LIAB-RSV',
      'CLT-LIAB-AVA',
      residualToAva,
      baseFields(investorId, investmentId, 'deployResidualToAvailable', descAva, commonMeta),
    ));
  }
  await Parse.Object.saveAll(rows, { useMasterKey: true });
}

/**
 * Nach Erstellung einer PoolTradeParticipation: RSV→TRD = Zuteilung,
 * Rest des Nominals RSV→AVA (siehe `reservedNominal` in bookDeployToTrading).
 */
async function bookDeployForPoolParticipation(investment, allocatedAmount) {
  const nominal = round2(Number(investment.get('amount') || 0));
  const alloc = round2(Number(allocatedAmount) || 0);
  if (nominal <= 0) return;
  await bookDeployToTrading({
    investorId: investment.get('investorId'),
    amount: alloc,
    reservedNominal: nominal,
    investmentId: investment.id,
    investmentNumber: investment.get('investmentNumber') || '',
    businessCaseId: String(investment.get('businessCaseId') || '').trim(),
  });
}

/**
 * reserved → cancelled (user storno): reserved → available
 */
async function bookReleaseReservation({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  businessCaseId,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'releaseReserve')) return;
  const desc = `Reservierung aufgelöst${investmentNumber ? ` (${investmentNumber})` : ''} – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, 'releaseReserve', desc, {
      investmentNumber: investmentNumber || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

/**
 * Entfernt fehlerhafte `releaseTradingResidualCorrection`-Zeilen (Haben TRD +2,31).
 * Nur Alt-Bestand nach fehlgeschlagenem Backfill; neue Flows buchen diese Leg nicht.
 */
async function purgeEscrowLegEntries(investmentId, leg, tradeId) {
  const tradeKey = tradeId != null ? String(tradeId).trim() : '';
  const q = new Parse.Query('AppLedgerEntry');
  q.equalTo('referenceId', investmentId);
  q.containedIn('referenceType', [REFERENCE_TYPE, REFERENCE_TYPE.toLowerCase()]);
  q.equalTo('transactionType', TRANSACTION_TYPE);
  q.limit(500);
  const rows = await q.find({ useMasterKey: true });
  const toDestroy = rows.filter((e) => {
    const m = e.get('metadata') || {};
    if (m.leg !== leg) return false;
    if (tradeKey && String(m.tradeId || '').trim() !== tradeKey) return false;
    return true;
  });
  if (toDestroy.length === 0) return 0;
  await Parse.Object.destroyAll(toDestroy, { useMasterKey: true });
  return toDestroy.length;
}

async function purgeReleaseTradingResidualCorrectionLeg(investmentId, tradeId) {
  return purgeEscrowLegEntries(investmentId, 'releaseTradingResidualCorrection', tradeId);
}

async function purgeTradingResidualReturnLeg(investmentId, tradeId) {
  return purgeEscrowLegEntries(investmentId, 'tradingResidualReturn', tradeId);
}

async function purgeReserveCapitalTradeSplitLeg(investmentId, tradeId) {
  return purgeEscrowLegEntries(investmentId, 'reserveCapitalTradeSplit', tradeId);
}

async function purgeDeployReversalForCapitalSplitLeg(investmentId, tradeId) {
  return purgeEscrowLegEntries(investmentId, 'deployReversalForCapitalSplit', tradeId);
}

/**
 * Storno vorheriger RSV→TRD-Deploy (volles Nominal), damit der Split aus RSV gebucht werden kann.
 */
async function bookDeployReversalForCapitalSplit({
  investorId,
  nominal,
  investmentId,
  investmentNumber,
  tradeId,
  businessCaseId,
}) {
  const nom = round2(nominal);
  if (nom <= 0) return;
  if (!(await hasEscrowLeg(investmentId, 'deploy'))) return;
  const leg = 'deployReversalForCapitalSplit';
  if (await hasEscrowLeg(investmentId, leg, { tradeId })) return;

  const invNum = investmentNumber || '';
  const desc = `Storno Pool-Zuführung vor Kapital-Split${invNum ? ` (${invNum})` : ''}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    CLT_LIAB_PTR,
    'CLT-LIAB-RSV',
    nom,
    baseFields(investorId, investmentId, leg, desc, {
      investmentNumber: invNum,
      tradeId: tradeId || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

/**
 * GoB-Split aus Reservierung (1591) bei bekanntem Restbetrag:
 *   Soll CLT-LIAB-RSV (Nominal)
 *   Haben CLT_LIAB_PTR (Anschaffung / im Handel)
 *   Haben CLT-LIAB-AVA (Kunde Cash / Rest)
 * Idempotent pro investmentId + tradeId. Parallel: AccountStatement `residual_return`.
 */
async function bookReserveCapitalTradeSplit({
  investorId,
  nominal,
  tradingAmount,
  availableAmount,
  investmentId,
  investmentNumber,
  tradeId,
  tradeNumber,
  businessCaseId,
}) {
  const nom = round2(nominal);
  const trdAmt = round2(tradingAmount);
  const avaAmt = round2(availableAmount);
  if (nom <= 0) return;
  if (round2(trdAmt + avaAmt) !== nom) {
    audit.error('escrow.split.imbalance', {
      investmentId,
      tradeId: tradeId || null,
      tradeNumber: tradeNumber || null,
      businessCaseId,
      nominal: nom,
      tradingAmount: trdAmt,
      availableAmount: avaAmt,
      message: '❌ bookReserveCapitalTradeSplit: trading+available ≠ nominal',
    });
    return;
  }

  const leg = 'reserveCapitalTradeSplit';
  if (await hasEscrowLeg(investmentId, leg, { tradeId })) return;

  audit.info('escrow.split.book', {
    investmentId,
    investmentNumber: investmentNumber || null,
    tradeId: tradeId || null,
    tradeNumber: tradeNumber || null,
    businessCaseId,
    nominal: nom,
    tradingAmount: trdAmt,
    availableAmount: avaAmt,
    message: '📒 bookReserveCapitalTradeSplit: RSV Soll → PTR/AVA Haben',
  });

  const invNum = investmentNumber || '';
  const desc = `Kapital-Split Reservierung → Handel/verfügbar${invNum ? ` (${invNum})` : ''} – Trade #${tradeNumber || tradeId || ''}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  const splitGroupId = `${investmentId}:${tradeId || 'na'}:reserveCapitalTradeSplit`;

  if (avaAmt > 0 && (await hasEscrowLeg(investmentId, 'deploy'))) {
    await bookDeployReversalForCapitalSplit({
      investorId,
      nominal: nom,
      investmentId,
      investmentNumber: invNum,
      tradeId,
      businessCaseId: bc,
    });
  }

  const common = baseFields(investorId, investmentId, leg, desc, {
    investmentNumber: invNum,
    tradeId: tradeId || '',
    tradeNumber: tradeNumber || '',
    splitGroupId,
    nominal: nom,
    tradingAmount: trdAmt,
    availableAmount: avaAmt,
    ...eigenbelegRef,
    ...(bc ? { businessCaseId: bc } : {}),
  });

  if (avaAmt <= 0) {
    await savePair('CLT-LIAB-RSV', CLT_LIAB_PTR, nom, common);
    return;
  }

  const rows = [
    buildSingleLedgerEntry(CLT_LIAB_RSV, 'debit', nom, common, { splitPart: 'reserve' }),
    buildSingleLedgerEntry(CLT_LIAB_PTR, 'credit', trdAmt, common, { splitPart: 'poolCapital' }),
    buildSingleLedgerEntry(CLT_LIAB_AVA, 'credit', avaAmt, common, { splitPart: 'available' }),
  ];
  await Parse.Object.saveAll(rows, { useMasterKey: true });
}

/** @deprecated – nutzt bookReserveCapitalTradeSplit; nur für Alt-Aufrufe. */
async function bookTradingResidualReturn({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  tradeId,
  tradeNumber,
  businessCaseId,
  nominal,
}) {
  const avaAmt = round2(amount);
  if (avaAmt <= 0) return;
  const nom = round2(nominal != null ? nominal : 0);
  if (nom <= 0) {
    console.error(`❌ bookTradingResidualReturn: nominal fehlt (${investmentId})`);
    return;
  }
  await bookReserveCapitalTradeSplit({
    investorId,
    nominal: nom,
    tradingAmount: round2(nom - avaAmt),
    availableAmount: avaAmt,
    investmentId,
    investmentNumber,
    tradeId,
    tradeNumber,
    businessCaseId,
  });
}

/**
 * Trade-Settlement (Collection Bill): Pool-Kapital PTR→AVA + Investor-Gewinn P/L→AVA.
 * SSOT Überweisungsbetrag = netSellAmount − commission ≈ tradingAmount + netProfit.
 * Idempotent pro investmentId + tradeId.
 */
async function bookTradeSettlementPayout({
  investorId,
  investmentId,
  investmentNumber,
  tradeId,
  tradeNumber,
  tradingAmount,
  netProfit,
  transferAmount,
  businessCaseId,
  collectionBillRef = {},
}) {
  const poolAmt = round2(tradingAmount);
  const profitAmt = round2(netProfit);
  const payoutTotal = round2(transferAmount ?? round2(poolAmt + profitAmt));
  if (payoutTotal <= 0) return;

  const invNum = investmentNumber || '';
  const desc = `Trade-Abwicklung${invNum ? ` (${invNum})` : ''} – Trade #${tradeNumber || tradeId || ''}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  const billRef = {
    referenceDocumentId: collectionBillRef.referenceDocumentId || '',
    referenceDocumentNumber: collectionBillRef.referenceDocumentNumber || '',
  };

  const componentSum = round2(poolAmt + profitAmt);
  const roundingGap = round2(payoutTotal - componentSum);
  if (Math.abs(roundingGap) >= 0.02) {
    audit.warn('escrow.payout.gap', {
      investmentId,
      tradeId,
      tradeNumber: tradeNumber || null,
      businessCaseId,
      transferAmount: payoutTotal,
      poolAmount: poolAmt,
      profitAmount: profitAmt,
      componentSum,
      gap: roundingGap,
      message: '⚠️ bookTradeSettlementPayout: transfer ≠ pool+net',
    });
  }

  if (poolAmt > 0 && !(await hasEscrowLeg(investmentId, 'tradeSettlementPoolRelease', { tradeId }))) {
    await savePair(
      CLT_LIAB_PTR,
      CLT_LIAB_AVA,
      poolAmt,
      baseFields(investorId, investmentId, 'tradeSettlementPoolRelease', desc, {
        investmentNumber: invNum,
        tradeId: tradeId || '',
        tradeNumber: tradeNumber || '',
        transferAmount: payoutTotal,
        poolCapitalReleased: poolAmt,
        ...billRef,
        ...(bc ? { businessCaseId: bc } : {}),
      }),
    );
  }

  if (profitAmt > 0 && !(await hasEscrowLeg(investmentId, 'tradeSettlementProfitRelease', { tradeId }))) {
    await savePair(
      CLT_EQT_INV_PNL,
      CLT_LIAB_AVA,
      profitAmt,
      baseFields(investorId, investmentId, 'tradeSettlementProfitRelease', desc, {
        investmentNumber: invNum,
        tradeId: tradeId || '',
        tradeNumber: tradeNumber || '',
        transferAmount: payoutTotal,
        netProfitReleased: profitAmt,
        ...billRef,
        ...(bc ? { businessCaseId: bc } : {}),
      }),
    );
  }

  const gapToBook = round2(payoutTotal - poolAmt - profitAmt);
  if (Math.abs(gapToBook) >= 0.01
    && !(await hasEscrowLeg(investmentId, 'tradeSettlementTransferGap', { tradeId }))) {
    await savePair(
      CLT_EQT_INV_PNL,
      CLT_LIAB_AVA,
      Math.abs(gapToBook),
      baseFields(investorId, investmentId, 'tradeSettlementTransferGap', `${desc} (Ausgleich)`, {
        investmentNumber: invNum,
        tradeId: tradeId || '',
        tradeNumber: tradeNumber || '',
        transferAmount: payoutTotal,
        roundingGap: gapToBook,
        ...billRef,
        ...(bc ? { businessCaseId: bc } : {}),
      }),
    );
  }
}

async function bookReleaseTrading({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  reason,
  businessCaseId,
}) {
  const gross = round2(amount);
  if (gross <= 0) return;
  const residualReleased = await sumCapitalSplitToAvailable(investmentId);
  const amt = round2(Math.max(0, gross - residualReleased));
  if (amt <= 0) return;
  const leg = reason === 'refund' ? 'releaseTradingRefund' : 'releaseTradingComplete';
  if (await hasEscrowLeg(investmentId, leg)) return;
  const desc = reason === 'refund'
    ? `Handelsbindung Rückerstattung – Investment ${investmentId}`
    : `Handelsbindung Auflösung (Abschluss) – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    CLT_LIAB_PTR,
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, leg, desc, {
      investmentNumber: investmentNumber || '',
      reason: reason || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

/**
 * reserved → completed (no activate): reserved → available
 */
async function bookReleaseReservedOnComplete({
  investorId,
  amount,
  investmentId,
  investmentNumber,
  businessCaseId,
}) {
  const amt = round2(amount);
  if (amt <= 0) return;
  if (await hasEscrowLeg(investmentId, 'releaseReservedComplete')) return;
  const desc = `Reserviert → verfügbar (Abschluss ohne Aktivierungspfad) – Investment ${investmentId}`;
  const bc = String(businessCaseId || '').trim();
  const eigenbelegRef = await eigenbelegRefFromReserveLeg(investmentId);
  await savePair(
    'CLT-LIAB-RSV',
    'CLT-LIAB-AVA',
    amt,
    baseFields(investorId, investmentId, 'releaseReservedComplete', desc, {
      investmentNumber: investmentNumber || '',
      ...eigenbelegRef,
      ...(bc ? { businessCaseId: bc } : {}),
    }),
  );
}

/**
 * Bei Aktivierung (Pool/Trade bekannt): GoB-Split aus RSV
 *   Soll RSV (Nominal) / Haben TRD (Nominal − Rest) / Haben AVA (Rest).
 * Parallel `residual_return` auf dem Kundenkonto. Idempotent pro investmentId + tradeId.
 */
async function ensureReserveCapitalTradeSplitOnActivation(investment, trade) {
  if (!investment?.id || !trade?.id) {
    return { skipped: true, reason: 'missing_refs' };
  }

  const nominal = round2(Number(investment.get('amount') || 0));
  if (nominal <= 0) {
    return { skipped: true, reason: 'zero_nominal' };
  }

  const tradeId = trade.id;
  const tradeBuyPrice = resolveTradeBuyPrice(trade);
  if (tradeBuyPrice <= 0) {
    console.warn(
      `ensureReserveCapitalTradeSplitOnActivation: no buy price for trade ${tradeId} (${investment.id})`,
    );
    return { skipped: true, reason: 'no_buy_price' };
  }

  const investorId = investment.get('investorId');
  /**
   * GoB: `mergeInvestorFeeConfig` — zuerst `Investment.feeConfigSnapshot` (bei Reservierung),
   * sonst live `Configuration.financial`, optional `trade.feeConfig` als Override.
   */
  let liveFinancial = {};
  try {
    const globalConfig = await loadConfig();
    liveFinancial = globalConfig && globalConfig.financial ? globalConfig.financial : {};
  } catch (err) {
    console.warn(
      `ensureReserveCapitalTradeSplitOnActivation: loadConfig failed (${err.message}); fee merge uses trade overrides only`,
    );
  }
  const feeConfig = mergeInvestorFeeConfig(investment, trade, liveFinancial);
  const buyLeg = computeInvestorBuyLeg(nominal, tradeBuyPrice, feeConfig);
  const residualAmt = round2(Math.max(0, buyLeg?.residualAmount || 0));
  const tradingAmount = round2(nominal - residualAmt);
  const investmentNumber = investment.get('investmentNumber') || '';
  const tradeNumber = trade.get('tradeNumber') || trade.get('number') || '';
  const businessCaseId = await ensureBusinessCaseIdForTrade(trade);

  const splitAlreadyBooked = await hasEscrowLeg(investment.id, 'reserveCapitalTradeSplit', { tradeId });
  if (!splitAlreadyBooked) {
    await bookReserveCapitalTradeSplit({
      investorId,
      nominal,
      tradingAmount,
      availableAmount: residualAmt,
      investmentId: investment.id,
      investmentNumber,
      tradeId,
      tradeNumber,
      businessCaseId,
    });
  }

  if (residualAmt > 0) {
    const eigenbelegRef = await eigenbelegRefFromReserveLeg(investment.id);
    const canonicalUserId = await resolveCanonicalUserId(investorId);
    const existingResidualStmt = await new Parse.Query('AccountStatement')
      .equalTo('userId', canonicalUserId)
      .equalTo('investmentId', investment.id)
      .equalTo('tradeId', tradeId)
      .equalTo('entryType', 'residual_return')
      .equalTo('source', 'backend')
      .first({ useMasterKey: true });
    if (!existingResidualStmt) {
      await bookAccountStatementEntry({
        userId: canonicalUserId,
        entryType: 'residual_return',
        amount: residualAmt,
        tradeId,
        tradeNumber,
        investmentId: investment.id,
        investmentNumber,
        description: investmentNumber
          ? `Restbetrag aus Investment ${investmentNumber}`
          : `Restbetrag aus Investment (Rundungsdifferenz Stückkauf)`,
        ...eigenbelegRef,
        businessCaseId,
      });
    }
  }

  if (!splitAlreadyBooked) {
    audit.info('escrow.activation.split', {
      investmentId: investment.id,
      tradeId: tradeId || null,
      businessCaseId,
      nominal,
      tradingAmount,
      residualAmount: residualAmt,
      message: '📒 ensureReserveCapitalTradeSplitOnActivation: RSV→TRD + AVA',
    });
  }

  // Investor-App / GoB: gebuchte Kaufseite (Total Buy Cost = nominal − Rest) persistieren,
  // damit die UI nicht das Reservierungs-Nominal anzeigt, sobald die Position aktiv ist.
  try {
    const existingPool = Number(investment.get('poolTradingAmount') || 0);
    if (
      !Number.isFinite(existingPool)
      || existingPool <= 0.005
      || Math.abs(existingPool - tradingAmount) > 0.02
    ) {
      investment.set('poolTradingAmount', tradingAmount);
      await investment.save(null, { useMasterKey: true });
    }
  } catch (err) {
    audit.warn('escrow.activation.poolTradingAmount.persistFailure', {
      investmentId: investment.id,
      tradeId: tradeId || null,
      businessCaseId,
      error: err && err.message ? err.message : String(err),
      message: 'ensureReserveCapitalTradeSplitOnActivation: poolTradingAmount persist failed',
    });
  }

  return {
    skipped: splitAlreadyBooked,
    reason: splitAlreadyBooked ? 'already_booked' : undefined,
    nominal,
    tradingAmount,
    availableAmount: residualAmt,
  };
}

module.exports = {
  bookReserve,
  bookDeployToTrading,
  bookDeployForPoolParticipation,
  bookReleaseReservation,
  bookReserveCapitalTradeSplit,
  ensureReserveCapitalTradeSplitOnActivation,
  bookTradingResidualReturn,
  purgeReleaseTradingResidualCorrectionLeg,
  purgeTradingResidualReturnLeg,
  purgeReserveCapitalTradeSplitLeg,
  purgeDeployReversalForCapitalSplitLeg,
  bookTradeSettlementPayout,
  bookReleaseTrading,
  bookReleaseReservedOnComplete,
  hasEscrowLeg,
  sumCapitalSplitToAvailable,
  sumEscrowPoolTradeDebitForLeg,
  TRANSACTION_TYPE,
};
