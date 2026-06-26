'use strict';

const { normalizeString } = require('./shared');
const { resolveRequiredReConsents } = require('./legalConsentUserSync');

function registerRequiredReConsentsFunctions() {
  Parse.Cloud.define('getRequiredReConsents', async (request) => {
    const user = request.user;
    if (!user) {
      throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
    }

    const language = normalizeString(request.params?.language || 'de') || 'de';
    return resolveRequiredReConsents(user, { language });
  });
}

module.exports = {
  registerRequiredReConsentsFunctions,
};
