'use strict';

Parse.Cloud.beforeDelete('TermsContent', async (request) => {
  const nodeEnv = String(process.env.NODE_ENV || '').toLowerCase();
  const allowInProd =
    String(process.env.ALLOW_LEGAL_HARD_DELETE_IN_PRODUCTION || '').toLowerCase() === 'true';

  const hardDeleteEnabled = String(process.env.ALLOW_LEGAL_HARD_DELETE || '').toLowerCase() === 'true';
  const isNonActive = request.object && request.object.get('isActive') !== true;
  const envOk = nodeEnv !== 'production' || allowInProd;

  const allowViaContext =
    request.context?.allowLegalHardDelete === true &&
    hardDeleteEnabled &&
    envOk &&
    isNonActive;

  const allowViaMasterEnv =
    !!request.master &&
    hardDeleteEnabled &&
    String(process.env.ALLOW_LEGAL_MASTER_DELETE_NON_ACTIVE_TERMSCONTENT || '').toLowerCase() === 'true' &&
    envOk &&
    isNonActive;

  if (allowViaContext || allowViaMasterEnv) return;

  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'TermsContent cannot be deleted (audit compliance). Set isActive=false instead.',
  );
});
