'use strict';

function round2(n) {
  return Math.round(Number(n || 0) * 100) / 100;
}

function statementSumKey({ userId, investmentId, entryType }) {
  return `${userId || ''}::${investmentId || ''}::${entryType || ''}`;
}

module.exports = {
  round2,
  statementSumKey,
};
