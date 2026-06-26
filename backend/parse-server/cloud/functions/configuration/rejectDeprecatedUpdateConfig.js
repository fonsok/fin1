'use strict';

const DEPRECATED_UPDATE_CONFIG_MESSAGE =
  'updateConfig is deprecated: use the Admin Web Portal (requestConfigurationChange / 4-eyes) '
  + 'for display flags such as showCommissionBreakdownInCreditNote, '
  + 'showDocumentReferenceLinksInAccountStatement, and maximumRiskExposurePercent.';

/**
 * Legacy iOS admin write path — blocked to enforce Configuration-class SSOT.
 *
 * @param {{ user?: { id: string } }} request
 */
function rejectDeprecatedUpdateConfig(request) {
  if (!request.user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }
  throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, DEPRECATED_UPDATE_CONFIG_MESSAGE);
}

module.exports = {
  DEPRECATED_UPDATE_CONFIG_MESSAGE,
  rejectDeprecatedUpdateConfig,
};
