'use strict';

const fs = require('fs');
const path = require('path');
const { SIGNUP_STEP_NUMBERS } = require('../onboardingLegacyPickerDefaults');

describe('signUpStepNumbers contract', () => {
  test('backend module matches shared/contracts/signUpStepNumbers.json', () => {
    const contractPath = path.resolve(__dirname, '../../contracts/signUpStepNumbers.json');
    const contract = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
    expect(SIGNUP_STEP_NUMBERS).toEqual(contract);
  });

  test('financial and experience steps keep stable numbers', () => {
    expect(SIGNUP_STEP_NUMBERS.financial).toBe(15);
    expect(SIGNUP_STEP_NUMBERS.experience).toBe(16);
  });
});
