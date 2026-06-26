'use strict';

const GATE_CONTRACT = require('../contracts/riskClass5DerivativesGate.json');

function fieldInList(value, allowed) {
  return value != null && allowed.includes(value);
}

function meetsTraderRiskClass5DerivativesExperienceCriteria(data) {
  if (!data) return false;
  return (
    fieldInList(data.derivativesTransactionsCount, GATE_CONTRACT.trader.derivativesTransactionsCount)
    && fieldInList(data.derivativesInvestmentAmount, GATE_CONTRACT.trader.derivativesInvestmentAmount)
    && fieldInList(data.derivativesHoldingPeriod, GATE_CONTRACT.trader.derivativesHoldingPeriod)
  );
}

function meetsInvestorRiskClass5DerivativesExperienceCriteria(data) {
  if (!data) return false;
  return (
    fieldInList(data.derivativesTransactionsCount, GATE_CONTRACT.investor.derivativesTransactionsCount)
    && fieldInList(data.derivativesInvestmentAmount, GATE_CONTRACT.investor.derivativesInvestmentAmount)
    && fieldInList(data.derivativesHoldingPeriod, GATE_CONTRACT.investor.derivativesHoldingPeriod)
  );
}

function meetsRiskClass5DerivativesExperienceCriteria(data) {
  if (!data) return false;
  if (data.userRole === 'trader') {
    return meetsTraderRiskClass5DerivativesExperienceCriteria(data);
  }
  return meetsInvestorRiskClass5DerivativesExperienceCriteria(data);
}

function cappedForRiskClass5DerivativesGate(riskClass, data) {
  const numericClass = Number(riskClass);
  if (numericClass === 5 && !meetsRiskClass5DerivativesExperienceCriteria(data)) {
    return 4;
  }
  return numericClass;
}

/**
 * Server-side mirror of iOS gate: RC 5 without step-16c profile becomes RC 4.
 * Runs once on onboarding completion (not per trade). O(1), no DB access.
 */
function enforceRiskClass5DerivativesGateOnOnboardingData(data) {
  if (!data) return data;

  let calculatedRiskClass = data.calculatedRiskClass;
  let finalRiskClass = data.finalRiskClass;
  let changed = false;

  if (calculatedRiskClass === 5) {
    const capped = cappedForRiskClass5DerivativesGate(5, data);
    if (capped !== calculatedRiskClass) {
      calculatedRiskClass = capped;
      changed = true;
    }
  }

  if (finalRiskClass === 5) {
    const capped = cappedForRiskClass5DerivativesGate(5, data);
    if (capped !== finalRiskClass) {
      finalRiskClass = capped;
      changed = true;
    }
  }

  if (!changed) return data;

  return {
    ...data,
    calculatedRiskClass,
    finalRiskClass,
  };
}

module.exports = {
  GATE_CONTRACT,
  meetsTraderRiskClass5DerivativesExperienceCriteria,
  meetsInvestorRiskClass5DerivativesExperienceCriteria,
  meetsRiskClass5DerivativesExperienceCriteria,
  cappedForRiskClass5DerivativesGate,
  enforceRiskClass5DerivativesGateOnOnboardingData,
};
