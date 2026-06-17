'use strict';

/** SSOT for leveraged-products knowledge-test questions (mirrors iOS `LeveragedProductsKnowledgeTest`). */
const KNOWLEDGE_TEST_VERSION = '1.2';

const VALID_OPTION_IDS = ['A', 'B', 'C', 'D'];

const CORRECT_ANSWERS = {
  put_dow_jones_falling: 'A',
};

function hasAllKnowledgeTestAnswers(answers) {
  if (!answers || typeof answers !== 'object') {
    return { valid: false, message: 'Knowledge test answers are required' };
  }

  for (const questionId of Object.keys(CORRECT_ANSWERS)) {
    const answer = answers[questionId];
    if (!answer || !VALID_OPTION_IDS.includes(answer)) {
      return {
        valid: false,
        message: `Knowledge test answer for "${questionId}" is missing`,
      };
    }
  }

  return { valid: true };
}

function evaluateKnowledgeTestPassed(answers) {
  if (!hasAllKnowledgeTestAnswers(answers).valid) {
    return false;
  }
  return Object.entries(CORRECT_ANSWERS).every(([questionId, expected]) => answers[questionId] === expected);
}

/** @deprecated use hasAllKnowledgeTestAnswers — kept for older imports */
function validateLeveragedProductsKnowledgeTest(answers) {
  return hasAllKnowledgeTestAnswers(answers);
}

module.exports = {
  KNOWLEDGE_TEST_VERSION,
  VALID_OPTION_IDS,
  CORRECT_ANSWERS,
  hasAllKnowledgeTestAnswers,
  evaluateKnowledgeTestPassed,
  validateLeveragedProductsKnowledgeTest,
};
