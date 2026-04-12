'use strict';

const { FAQ_ARTICLES } = require('./data');
const { enforceSeedAccess } = require('./helpers');

function registerSeedFAQFunctions() {
  Parse.Cloud.define('seedFAQs', async (request) => {
    enforceSeedAccess(request);

    const forceReseed = request.params.forceReseed === true;
    const existingQuery = new Parse.Query('FAQ');
    const existingCount = await existingQuery.count({ useMasterKey: true });

    if (existingCount > 0 && !forceReseed) {
      return {
        success: false,
        message: `${existingCount} FAQs already exist. Use 'forceReseedFAQData' to overwrite.`,
        created: 0,
      };
    }

    const catQuery = new Parse.Query('FAQCategory');
    catQuery.limit(100);
    const allCats = await catQuery.find({ useMasterKey: true });
    const slugToId = {};
    for (const c of allCats) {
      slugToId[c.get('slug')] = c.id;
    }

    if (Object.keys(slugToId).length === 0) {
      throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'No FAQ categories found. Run seedFAQCategories first.');
    }

    const FAQ = Parse.Object.extend('FAQ');
    let created = 0;
    let updated = 0;
    const skipped = [];

    for (const item of FAQ_ARTICLES) {
      const catId = slugToId[item.categorySlug];
      if (!catId) {
        skipped.push(item.faqId);
        continue;
      }

      if (forceReseed) {
        const byFaqId = new Parse.Query('FAQ');
        byFaqId.equalTo('faqId', item.faqId);
        const existing = await byFaqId.first({ useMasterKey: true });
        if (existing) {
          existing.set('question', item.question);
          existing.set('answer', item.answer);
          existing.set('categoryId', catId);
          existing.set('sortOrder', item.sortOrder);
          existing.set('isPublished', item.isPublished);
          existing.set('isArchived', false);
          existing.set('isPublic', item.isPublic);
          existing.set('isUserVisible', item.isUserVisible);
          if (item.targetRoles) {
            existing.set('targetRoles', item.targetRoles);
          } else {
            existing.unset('targetRoles');
          }
          await existing.save(null, { useMasterKey: true });
          updated += 1;
          continue;
        }
      }

      const faq = new FAQ();
      faq.set('faqId', item.faqId);
      faq.set('question', item.question);
      faq.set('answer', item.answer);
      faq.set('categoryId', catId);
      faq.set('sortOrder', item.sortOrder);
      faq.set('isPublished', item.isPublished);
      faq.set('isArchived', false);
      faq.set('isPublic', item.isPublic);
      faq.set('isUserVisible', item.isUserVisible);
      if (item.targetRoles) {
        faq.set('targetRoles', item.targetRoles);
      }
      await faq.save(null, { useMasterKey: true });
      created += 1;
    }

    console.log(`[FAQ] Seeded FAQ articles: ${created} created, ${updated} updated` + (skipped.length ? ` (skipped ${skipped.length}: ${skipped.join(', ')})` : ''));
    return { success: true, message: `Created ${created}, updated ${updated} FAQ articles`, created, updated, skipped };
  });
}

module.exports = { registerSeedFAQFunctions };
