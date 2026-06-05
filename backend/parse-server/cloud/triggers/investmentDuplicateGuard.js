'use strict';

/**
 * Prevents duplicate split rows for the same logical investment position.
 *
 * Guard key:
 *   (investorId, batchId, sequenceNumber)
 *
 * Rationale:
 * - A split is uniquely identified by its batch and sequence for one investor.
 * - Duplicates lead to double display (reserved + active) and can cascade into
 *   duplicate downstream accounting side effects.
 *
 * @param {Parse.Object} investment
 * @param {typeof Parse} Parse
 */
/**
 * @param {{ investorId: string, batchId: string, sequenceNumber: number, excludeObjectId?: string }} key
 * @param {typeof Parse} Parse
 * @returns {Promise<Parse.Object|null>}
 */
async function findExistingInvestmentSplit(key, Parse) {
  const investorId = String(key.investorId || '').trim();
  const batchId = String(key.batchId || '').trim();
  const sequenceNumber = Number(key.sequenceNumber);
  if (!batchId || !investorId || !Number.isFinite(sequenceNumber) || sequenceNumber <= 0) {
    return null;
  }

  const query = new Parse.Query('Investment');
  query.equalTo('investorId', investorId);
  query.equalTo('batchId', batchId);
  query.equalTo('sequenceNumber', sequenceNumber);
  const excludeObjectId = String(key.excludeObjectId || '').trim();
  if (excludeObjectId) {
    query.notEqualTo('objectId', excludeObjectId);
  }
  return query.first({ useMasterKey: true });
}

async function assertNoDuplicateInvestmentSplit(investment, Parse) {
  const rawBatchId = investment.get('batchId');
  const sequenceNumber = Number(investment.get('sequenceNumber'));
  const investorId = String(investment.get('investorId') || '').trim();

  if (rawBatchId == null || typeof rawBatchId !== 'string') {
    return;
  }
  const batchId = rawBatchId.trim();
  if (!batchId || !Number.isFinite(sequenceNumber) || sequenceNumber <= 0 || !investorId) {
    return;
  }

  const duplicate = await findExistingInvestmentSplit(
    { investorId, batchId, sequenceNumber, excludeObjectId: investment.id },
    Parse,
  );
  if (duplicate) {
    throw new Parse.Error(
      Parse.Error.DUPLICATE_VALUE,
      'Dieser Investment-Anteil wurde bereits angelegt. Bitte die Investitionsliste aktualisieren.',
    );
  }
}

module.exports = {
  assertNoDuplicateInvestmentSplit,
  findExistingInvestmentSplit,
};
