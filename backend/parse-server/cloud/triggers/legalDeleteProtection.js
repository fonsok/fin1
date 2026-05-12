'use strict';

const { envTrue, isDevTradingDataResetDestroyActive } = require('../functions/admin/devHelpers/shared');

Parse.Cloud.beforeDelete('LegalDocumentDeliveryLog', async () => {
  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'LegalDocumentDeliveryLog cannot be deleted (audit compliance).',
  );
});

Parse.Cloud.beforeDelete('LegalConsent', async () => {
  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'LegalConsent cannot be deleted (audit compliance).',
  );
});

Parse.Cloud.beforeDelete('ComplianceEvent', async () => {
  const nodeEnv = String(process.env.NODE_ENV || '').toLowerCase();
  const resetEnabled = envTrue('ALLOW_DEV_TRADING_RESET');
  const resetInProd = envTrue('ALLOW_DEV_TRADING_RESET_IN_PRODUCTION');
  if (
    isDevTradingDataResetDestroyActive() &&
    resetEnabled &&
    (nodeEnv !== 'production' || resetInProd)
  ) {
    return;
  }
  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'ComplianceEvent cannot be deleted (audit compliance).',
  );
});

Parse.Cloud.beforeDelete('AuditLog', async () => {
  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'AuditLog cannot be deleted (GoB: Aufbewahrungspflicht).',
  );
});

Parse.Cloud.beforeDelete('FourEyesRequest', async () => {
  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'FourEyesRequest cannot be deleted (GoB: Belegprinzip).',
  );
});
