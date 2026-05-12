'use strict';

Parse.Cloud.beforeSave('LegalDocumentDeliveryLog', async (request) => {
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Delivery logs are server-managed');
  }
});

Parse.Cloud.beforeSave('LegalConsent', async (request) => {
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Consent logs are server-managed');
  }
});
