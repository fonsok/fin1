'use strict';

const { round2 } = require('../utils/accountingHelper/shared');
const { validateInvestmentAmountAgainstLimits } = require('../utils/investmentLimitsValidation');
const { validatePoolMirrorReservationCapacity } = require('../utils/poolMirrorBuyCap');
const { findExistingInvestmentSplit } = require('../triggers/investmentDuplicateGuard');
const { resolveCanonicalUserId } = require('../utils/canonicalUserId');
const { resolveTraderParseUser } = require('../utils/resolveTraderParseUser');
const {
  markBatchPoolCapValidated,
  clearBatchPoolCapValidated,
} = require('../utils/investmentBatchContext');
const { rollbackBatchCreatedSplits } = require('../utils/investmentBatchAtomicRollback');
const {
  beginBatchNotificationDefer,
  flushBatchCreatedNotifications,
  discardDeferredBatchNotifications,
} = require('../utils/investmentBatchNotifications');
const { assertProductAccessEligible } = require('../utils/productAccessGate');

const AMOUNT_EPSILON = 0.01;

function isDuplicateKeyError(err) {
  if (!err) return false;
  const code = err.code;
  const msg = String(err.message || '').toLowerCase();
  return code === 137
    || msg.includes('duplicate')
    || msg.includes('e11000');
}

function splitResultFromInvestment(inv, idempotentReplay) {
  return {
    investmentId: inv.id,
    sequenceNumber: inv.get('sequenceNumber'),
    investmentNumber: inv.get('investmentNumber') || null,
    idempotentReplay: Boolean(idempotentReplay),
    /** `created` = new row; `replayed` = idempotent hit (client need not treat as failure). */
    status: idempotentReplay ? 'replayed' : 'created',
  };
}

function amountsMatch(existingAmount, requestedAmount) {
  return round2(Math.abs(round2(existingAmount) - round2(requestedAmount))) <= AMOUNT_EPSILON;
}

function throwBatchAtomicFailure(err) {
  const code = err instanceof Parse.Error
    ? err.code
    : (err && err.code != null ? err.code : Parse.Error.INTERNAL_SERVER_ERROR);
  const detail = String(err && err.message ? err.message : err).trim();
  throw new Parse.Error(
    code,
    detail.startsWith('Batch-Anlage fehlgeschlagen')
      ? detail
      : `Batch-Anlage fehlgeschlagen (neue Anteile zurückgenommen): ${detail}`,
  );
}

/**
 * Idempotent batch create for investment splits (one round-trip per batch).
 * Key: (investorId, batchId, sequenceNumber). Retries return existing rows.
 */
async function handleCreateInvestmentSplits(request) {
  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Anmeldung erforderlich.');
  }
  await assertProductAccessEligible(user);

  const {
    batchId: rawBatchId,
    traderId: rawTraderId,
    specialization,
    investorName,
    traderName,
    traderUsername,
    splits,
  } = request.params || {};

  const batchId = String(rawBatchId || '').trim();
  const traderId = String(rawTraderId || '').trim();
  const usernameParam = String(traderUsername || '').trim();
  if (!batchId) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'batchId erforderlich.');
  }
  if (!traderId && !usernameParam) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Trader-ID oder traderUsername erforderlich.');
  }
  if (!Array.isArray(splits) || splits.length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Mindestens ein Split erforderlich.');
  }
  if (splits.length > 50) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Zu viele Splits in einer Anfrage (max. 50).');
  }

  const investorId = await resolveCanonicalUserId(user.id);

  const trader = await resolveTraderParseUser(
    {
      traderId,
      traderUsername: usernameParam,
      traderDisplayName: String(traderName || '').trim(),
    },
    Parse,
  );
  if (!trader) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Trader nicht gefunden oder nicht aktiv.');
  }
  const canonicalTraderId = await resolveCanonicalUserId(trader.id);
  const resolvedTraderUsername = usernameParam
    || String(trader.get('username') || '').trim().toLowerCase();

  const normalizedSplits = splits.map((raw, index) => {
    const sequenceNumber = Number(raw && raw.sequenceNumber);
    const amount = round2(Number(raw && raw.amount));
    if (!Number.isFinite(sequenceNumber) || sequenceNumber <= 0) {
      throw new Parse.Error(
        Parse.Error.INVALID_VALUE,
        `Ungültige sequenceNumber für Split ${index + 1}.`,
      );
    }
    return { sequenceNumber, amount };
  });

  const seenSeq = new Set();
  for (const s of normalizedSplits) {
    if (seenSeq.has(s.sequenceNumber)) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Doppelte sequenceNumber in der Anfrage.');
    }
    seenSeq.add(s.sequenceNumber);
  }

  let newAmountTotal = 0;
  for (const split of normalizedSplits) {
    const limitCheck = await validateInvestmentAmountAgainstLimits(split.amount);
    if (!limitCheck.valid) {
      throw new Parse.Error(Parse.Error.INVALID_VALUE, limitCheck.error);
    }
    const existing = await findExistingInvestmentSplit(
      { investorId, batchId, sequenceNumber: split.sequenceNumber },
      Parse,
    );
    if (!existing) {
      newAmountTotal = round2(newAmountTotal + split.amount);
    } else if (!amountsMatch(existing.get('amount'), split.amount)) {
      throw new Parse.Error(
        Parse.Error.DUPLICATE_VALUE,
        `Investment-Anteil ${split.sequenceNumber} existiert bereits mit abweichendem Betrag.`,
      );
    }
  }

  if (newAmountTotal > 0) {
    const poolCapCheck = await validatePoolMirrorReservationCapacity(canonicalTraderId, newAmountTotal);
    if (!poolCapCheck.valid) {
      throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, poolCapCheck.error);
    }
    markBatchPoolCapValidated(investorId, batchId);
  }

  const createdInRequest = [];
  const results = [];

  beginBatchNotificationDefer(investorId, batchId, canonicalTraderId);

  try {
    for (const split of normalizedSplits.sort((a, b) => a.sequenceNumber - b.sequenceNumber)) {
      const existing = await findExistingInvestmentSplit(
        { investorId, batchId, sequenceNumber: split.sequenceNumber },
        Parse,
      );
      if (existing) {
        results.push(splitResultFromInvestment(existing, true));
        continue;
      }

      const Investment = Parse.Object.extend('Investment');
      const investment = new Investment();
      investment.set('investorId', investorId);
      investment.set('traderId', canonicalTraderId);
      investment.set('batchId', batchId);
      investment.set('sequenceNumber', split.sequenceNumber);
      investment.set('amount', split.amount);
      if (specialization) investment.set('specialization', String(specialization));
      if (investorName) investment.set('investorName', String(investorName));
      if (traderName) investment.set('traderName', String(traderName));
      if (resolvedTraderUsername) {
        investment.set('traderUsername', resolvedTraderUsername);
      }

      try {
        await investment.save(null, { useMasterKey: true });
        createdInRequest.push(investment.id);
        results.push(splitResultFromInvestment(investment, false));
      } catch (err) {
        if (isDuplicateKeyError(err)) {
          const replay = await findExistingInvestmentSplit(
            { investorId, batchId, sequenceNumber: split.sequenceNumber },
            Parse,
          );
          if (replay && amountsMatch(replay.get('amount'), split.amount)) {
            results.push(splitResultFromInvestment(replay, true));
            continue;
          }
          const dupNum = err && err.underlyingError && err.underlyingError.keyValue
            ? err.underlyingError.keyValue.investmentNumber
            : null;
          if (dupNum && err.underlyingError && err.underlyingError.keyPattern
            && err.underlyingError.keyPattern.investmentNumber) {
            const byNum = new Parse.Query('Investment');
            byNum.equalTo('investorId', investorId);
            byNum.equalTo('investmentNumber', dupNum);
            const sameInvestorRow = await byNum.first({ useMasterKey: true });
            if (sameInvestorRow
              && sameInvestorRow.get('batchId') === batchId
              && sameInvestorRow.get('sequenceNumber') === split.sequenceNumber
              && amountsMatch(sameInvestorRow.get('amount'), split.amount)) {
              results.push(splitResultFromInvestment(sameInvestorRow, true));
              continue;
            }
          }
        }
        const msg = err && err.message ? String(err.message) : '';
        if (msg.toLowerCase().includes('duplicate')) {
          throw new Parse.Error(
            Parse.Error.DUPLICATE_VALUE,
            'Investment-Nummer kollidiert (Index). Bitte erneut versuchen oder Support kontaktieren.',
          );
        }
        throw err;
      }
    }
  } catch (err) {
    discardDeferredBatchNotifications(investorId, batchId);
    if (createdInRequest.length > 0) {
      await rollbackBatchCreatedSplits(
        createdInRequest,
        err && err.message ? err.message : String(err),
      );
    }
    throwBatchAtomicFailure(err);
  } finally {
    clearBatchPoolCapValidated(investorId, batchId);
  }

  await flushBatchCreatedNotifications(investorId, batchId);

  const allReplayed = results.length > 0 && results.every((r) => r.status === 'replayed');
  return {
    batchId,
    resolvedTraderId: canonicalTraderId,
    batchStatus: allReplayed ? 'replayed' : 'committed',
    splits: results,
  };
}

module.exports = {
  handleCreateInvestmentSplits,
  splitResultFromInvestment,
  amountsMatch,
  isDuplicateKeyError,
};
