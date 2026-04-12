'use strict';

const { invalidateCache, TRANSACTION_LIMIT_SNAKE_TO_CAMEL } = require('../../utils/configHelper/index.js');

function formatValue(value) {
  if (typeof value === 'number') {
    if (value < 1) {
      return `${(value * 100).toFixed(1)}%`;
    }
    return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(value);
  }
  return String(value);
}

function getOldValueFromConfig(config, parameterName) {
  const limitCamel = TRANSACTION_LIMIT_SNAKE_TO_CAMEL[parameterName];
  if (limitCamel) {
    return config.limits[limitCamel]
      ?? config.limits[parameterName]
      ?? config.financial[parameterName];
  }
  return config.financial[parameterName]
    ?? config.limits[parameterName]
    ?? config.display[parameterName];
}

function buildDisplay(config) {
  return {
    showCommissionBreakdownInCreditNote: config.display?.showCommissionBreakdownInCreditNote ?? true,
    maximumRiskExposurePercent: config.display?.maximumRiskExposurePercent ?? 2.0,
    walletFeatureEnabled: config.display?.walletFeatureEnabled ?? false,
  };
}

async function applyConfigurationChange(parameterName, newValue, userId) {
  const Configuration = Parse.Object.extend('Configuration');
  const query = new Parse.Query(Configuration);
  query.equalTo('isActive', true);

  let config = await query.first({ useMasterKey: true });
  if (!config) {
    config = new Configuration();
    config.set('isActive', true);
  }

  const limitCamel = TRANSACTION_LIMIT_SNAKE_TO_CAMEL[parameterName];
  if (limitCamel) {
    const nextLimits = { ...(config.get('limits') || {}), [limitCamel]: newValue };
    config.set('limits', nextLimits);
  } else {
    config.set(parameterName, newValue);
  }

  config.set('updatedBy', userId);
  config.set('updatedAt', new Date());

  await config.save(null, { useMasterKey: true });
  invalidateCache();

  console.log(`✅ Configuration '${parameterName}' updated to ${newValue} by ${userId}`);
}

module.exports = {
  formatValue,
  getOldValueFromConfig,
  buildDisplay,
  applyConfigurationChange,
};
