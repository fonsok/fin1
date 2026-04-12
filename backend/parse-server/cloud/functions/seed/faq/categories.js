'use strict';

const { FAQ_CATEGORIES } = require('./data');
const { enforceSeedAccess } = require('./helpers');

function registerSeedFAQCategoryFunctions() {
  Parse.Cloud.define('seedFAQCategories', async (request) => {
    enforceSeedAccess(request);

    const forceReseed = request.params.forceReseed === true;
    const existingQuery = new Parse.Query('FAQCategory');
    const existingCount = await existingQuery.count({ useMasterKey: true });

    if (existingCount > 0 && !forceReseed) {
      return {
        success: false,
        message: `${existingCount} FAQ categories already exist. Use 'forceReseedFAQData' to overwrite.`,
        created: 0,
      };
    }

    const FAQCategory = Parse.Object.extend('FAQCategory');
    let created = 0;
    let updated = 0;

    for (const catData of FAQ_CATEGORIES) {
      if (forceReseed) {
        const bySlug = new Parse.Query('FAQCategory');
        bySlug.equalTo('slug', catData.slug);
        const existing = await bySlug.first({ useMasterKey: true });
        if (existing) {
          existing.set('title', catData.title);
          existing.set('displayName', catData.displayName);
          existing.set('icon', catData.icon);
          existing.set('showOnLanding', catData.showOnLanding);
          existing.set('showInHelpCenter', catData.showInHelpCenter);
          existing.set('showInCSR', catData.showInCSR);
          existing.set('sortOrder', catData.sortOrder);
          existing.set('isActive', true);
          if (catData.targetRoles) {
            existing.set('targetRoles', catData.targetRoles);
          } else {
            existing.unset('targetRoles');
          }
          await existing.save(null, { useMasterKey: true });
          updated += 1;
          continue;
        }
      }
      const cat = new FAQCategory();
      cat.set('slug', catData.slug);
      cat.set('title', catData.title);
      cat.set('displayName', catData.displayName);
      cat.set('icon', catData.icon);
      cat.set('showOnLanding', catData.showOnLanding);
      cat.set('showInHelpCenter', catData.showInHelpCenter);
      cat.set('showInCSR', catData.showInCSR);
      cat.set('sortOrder', catData.sortOrder);
      cat.set('isActive', true);
      if (catData.targetRoles) {
        cat.set('targetRoles', catData.targetRoles);
      }
      await cat.save(null, { useMasterKey: true });
      created += 1;
    }

    console.log(`[FAQ] Seeded FAQ categories: ${created} created, ${updated} updated`);
    return { success: true, message: `Created ${created}, updated ${updated} FAQ categories`, created, updated };
  });
}

module.exports = { registerSeedFAQCategoryFunctions };
