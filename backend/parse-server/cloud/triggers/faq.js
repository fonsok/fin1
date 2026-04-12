'use strict';

/**
 * Hard-delete protection for FAQ content (helps avoid accidental data loss).
 * - Master-key seed/maintenance must pass an explicit context flag.
 * - Mirrors the guard pattern used for TermsContent (legal.js).
 */
Parse.Cloud.beforeDelete('FAQ', async (request) => {
  if (request.context?.allowFaqSeedDelete === true && request.master) {
    return;
  }

  const nodeEnv = String(process.env.NODE_ENV || '').toLowerCase();
  const allowInProd =
    String(process.env.ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION || '').toLowerCase() === 'true';

  const allowMaintenance =
    request.context?.allowFaqHardDelete === true &&
    request.master &&
    String(process.env.ALLOW_FAQ_HARD_DELETE || '').toLowerCase() === 'true' &&
    (nodeEnv !== 'production' || allowInProd);

  if (allowMaintenance) {
    return;
  }

  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'FAQ objects cannot be hard-deleted (use archive / isArchived). For DEV reset, set ALLOW_FAQ_HARD_DELETE=true and use devResetFAQsBaseline with explicit server support.',
  );
});

Parse.Cloud.beforeDelete('FAQCategory', async (request) => {
  if (request.context?.allowFaqSeedDelete === true && request.master) {
    return;
  }

  const nodeEnv = String(process.env.NODE_ENV || '').toLowerCase();
  const allowInProd =
    String(process.env.ALLOW_FAQ_HARD_DELETE_IN_PRODUCTION || '').toLowerCase() === 'true';

  const allowMaintenance =
    request.context?.allowFaqCategoryHardDelete === true &&
    request.master &&
    String(process.env.ALLOW_FAQ_HARD_DELETE || '').toLowerCase() === 'true' &&
    (nodeEnv !== 'production' || allowInProd);

  if (allowMaintenance) {
    return;
  }

  throw new Parse.Error(
    Parse.Error.OPERATION_FORBIDDEN,
    'FAQCategory objects cannot be hard-deleted. For DEV maintenance, use devResetFAQsBaseline (inactive categories only) with ALLOW_FAQ_HARD_DELETE=true.',
  );
});
