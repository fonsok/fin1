'use strict';

const { requireAdminRole } = require('../../../utils/permissions');

function enforceSeedAccess(request) {
  const allowMaster = request.master || request.params.runWithMasterKey === true;
  if (!allowMaster) {
    requireAdminRole(request);
  }
}

function enforceMasterOnly(request) {
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Master key required');
  }
}

async function deleteAllFAQObjects() {
  const faqQuery = new Parse.Query('FAQ');
  faqQuery.limit(2000);
  const existingFaqs = await faqQuery.find({ useMasterKey: true });
  let deletedFaqs = 0;
  for (const obj of existingFaqs) {
    try {
      await obj.destroy({ useMasterKey: true, context: { allowFaqSeedDelete: true } });
      deletedFaqs += 1;
    } catch (e) {
      if (e.code !== 101) console.warn('[FAQ] destroy FAQ failed:', e.message);
    }
  }

  const catQuery = new Parse.Query('FAQCategory');
  catQuery.limit(2000);
  const existingCats = await catQuery.find({ useMasterKey: true });
  let deletedCats = 0;
  for (const obj of existingCats) {
    try {
      await obj.destroy({ useMasterKey: true, context: { allowFaqSeedDelete: true } });
      deletedCats += 1;
    } catch (e) {
      if (e.code !== 101) console.warn('[FAQ] destroy category failed:', e.message);
    }
  }

  return { deletedFaqs, deletedCategories: deletedCats };
}

module.exports = {
  enforceSeedAccess,
  enforceMasterOnly,
  deleteAllFAQObjects,
};
