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

  const query = new Parse.Query('Investment');
  query.equalTo('investorId', investorId);
  query.equalTo('batchId', batchId);
  query.equalTo('sequenceNumber', sequenceNumber);
  const currentId = investment.id;
  if (currentId) {
    query.notEqualTo('objectId', currentId);
  }

  const duplicate = await query.first({ useMasterKey: true });
  if (duplicate) {
    throw new Parse.Error(
      Parse.Error.DUPLICATE_VALUE,
      `Investment split already exists for investorId=${investorId}, batchId=${batchId}, sequenceNumber=${sequenceNumber}.`
    );
  }
}

module.exports = { assertNoDuplicateInvestmentSplit };
