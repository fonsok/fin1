'use strict';

const { loadConfig } = require('../../utils/configHelper/index.js');
const { hydrateFaqLocaleJSON } = require('./faqLocales');

// Role-based FAQ filtering: targetRoles on FAQ/FAQCategory.
// ["all"] or absent → everyone; ["trader"] / ["investor"] → role-specific.
function matchesRole(targetRoles, userRole) {
  if (!targetRoles || targetRoles.length === 0 || targetRoles.includes('all')) {
    return true;
  }
  if (!userRole) return true;
  return targetRoles.includes(userRole);
}

function formatCurrencyEUR(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return '0,00 €';
  return new Intl.NumberFormat('de-DE', {
    style: 'currency',
    currency: 'EUR',
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(num);
}

function formatPercentDE(value) {
  const num = Number(value);
  if (!Number.isFinite(num)) return '0 %';
  return `${new Intl.NumberFormat('de-DE', { maximumFractionDigits: 2 }).format(num * 100)} %`;
}

function replacePlaceholders(text, replacements) {
  if (typeof text !== 'string' || !text) return text;
  // Support both {{TOKEN}} and legacy {(TOKEN)} syntaxes.
  return text.replace(/\{\{([A-Z0-9_]+)\}\}|\{\(([A-Z0-9_]+)\)\}/g, (match, tokenA, tokenB) => {
    const token = tokenA || tokenB;
    if (Object.prototype.hasOwnProperty.call(replacements, token)) {
      return String(replacements[token]);
    }
    return match;
  });
}

/** Deduplicate Parse objects by id (Parse.Query.or may return duplicates). */
function dedupeById(rows) {
  const map = new Map();
  for (const r of rows) {
    if (r && r.id && !map.has(r.id)) map.set(r.id, r);
  }
  return Array.from(map.values());
}

function sortBySortOrder(rows) {
  return rows.slice().sort((a, b) => (a.get('sortOrder') || 0) - (b.get('sortOrder') || 0));
}

/** Retired FAQCategory slugs: hidden from Help Center, CSR category lists, and filtered client-side in admin. */
const RETIRED_FAQ_CATEGORY_SLUGS = new Set(['investor_portfolio', 'trader_pools']);

function filterRetiredFaqCategories(rows, location) {
  if (location !== 'help_center' && location !== 'csr') return rows;
  return rows.filter((c) => {
    const slug = c.get('slug');
    return typeof slug !== 'string' || !RETIRED_FAQ_CATEGORY_SLUGS.has(slug);
  });
}

Parse.Cloud.define('getFAQs', async (request) => {
  const { categorySlug, isPublic, userRole, location, context } = request.params;

  const query = new Parse.Query('FAQ');

  if (context === 'admin' && request.user) {
    const adminRoleQuery = new Parse.Query(Parse.Role);
    adminRoleQuery.equalTo('name', 'admin');
    adminRoleQuery.equalTo('users', request.user);
    const isAdmin = await adminRoleQuery.first({ useMasterKey: true });
    if (isAdmin) {
      // No visibility or publish filters for admin
    } else {
      query.equalTo('isPublished', true);
      query.equalTo('isArchived', false);
    }
  } else {
    query.equalTo('isPublished', true);
    query.equalTo('isArchived', false);

    if (location === 'help_center') {
      // Help Center = in-app Hilfe: zeige sowohl rollenbezogene (isUserVisible) als auch
      // öffentliche Landing-FAQs (isPublic), damit App-Übersicht / Erste Schritte nicht leer bleiben.
      const qPublic = new Parse.Query('FAQ');
      qPublic.equalTo('isPublished', true);
      qPublic.equalTo('isArchived', false);
      qPublic.equalTo('isPublic', true);
      const qUser = new Parse.Query('FAQ');
      qUser.equalTo('isPublished', true);
      qUser.equalTo('isArchived', false);
      qUser.equalTo('isUserVisible', true);
      const orQuery = Parse.Query.or(qPublic, qUser);
      if (categorySlug) {
        const catQuery = new Parse.Query('FAQCategory');
        catQuery.equalTo('slug', categorySlug);
        const category = await catQuery.first({ useMasterKey: true });
        if (category) {
          orQuery.equalTo('categoryId', category.id);
        }
      }
      orQuery.ascending('sortOrder');
      orQuery.limit(500);
      let faqs = await orQuery.find({ useMasterKey: true });
      faqs = sortBySortOrder(dedupeById(faqs));

      if (userRole) {
        faqs = faqs.filter(f => matchesRole(f.get('targetRoles'), userRole));
      }

      const liveConfig = await loadConfig();
      const fin = liveConfig?.financial || {};
      const serviceChargeRate =
        fin.appServiceChargeRate
        ?? fin.platformServiceChargeRate
        ?? 0.02;
      const traderCommissionRate = Number.isFinite(fin.traderCommissionRate)
        ? fin.traderCommissionRate
        : 0.1;
      const orderFeeRate = Number.isFinite(fin.orderFeeRate) ? fin.orderFeeRate : 0.005;
      const exchangeFeeRate = Number.isFinite(fin.exchangeFeeRate) ? fin.exchangeFeeRate : 0.0001;
      const replacements = {
        APP_NAME: liveConfig?.legal?.appName || 'FIN1',
        LEGAL_PLATFORM_NAME: liveConfig?.legal?.platformName || 'App',
        MIN_INVESTMENT: formatCurrencyEUR(liveConfig?.limits?.minInvestment),
        MAX_INVESTMENT: formatCurrencyEUR(liveConfig?.limits?.maxInvestment),
        APP_SERVICE_CHARGE_RATE: formatPercentDE(serviceChargeRate),
        PLATFORM_SERVICE_CHARGE_RATE: formatPercentDE(serviceChargeRate),
        PLATFORM_FEE_RATE: formatPercentDE(serviceChargeRate),
        TRADER_COMMISSION_RATE: formatPercentDE(traderCommissionRate),
        ORDER_FEE_RATE: formatPercentDE(orderFeeRate),
        EXCHANGE_FEE_RATE: formatPercentDE(exchangeFeeRate),
      };

      const hydratedFaqs = faqs.map((f) => {
        const merged = hydrateFaqLocaleJSON(f.toJSON());
        const row = {
          ...merged,
          question: replacePlaceholders(merged.question, replacements),
          answer: replacePlaceholders(merged.answer, replacements),
        };
        if (merged.questionEn) {
          row.questionEn = replacePlaceholders(merged.questionEn, replacements);
        }
        if (merged.answerEn) {
          row.answerEn = replacePlaceholders(merged.answerEn, replacements);
        }
        return row;
      });

      return { faqs: hydratedFaqs };
    } else if (isPublic) {
      query.equalTo('isPublic', true);
    } else if (request.user) {
      query.equalTo('isUserVisible', true);
    } else {
      query.equalTo('isPublic', true);
    }
  }

  if (categorySlug) {
    const catQuery = new Parse.Query('FAQCategory');
    catQuery.equalTo('slug', categorySlug);
    const category = await catQuery.first({ useMasterKey: true });
    if (category) {
      query.equalTo('categoryId', category.id);
    }
  }

  query.ascending('sortOrder');
  query.limit(500);
  let faqs = await query.find({ useMasterKey: true });

  if (userRole) {
    faqs = faqs.filter(f => matchesRole(f.get('targetRoles'), userRole));
  }

  // Resolve dynamic placeholders (e.g. {{MIN_INVESTMENT}}, {{MAX_INVESTMENT}}) from live configuration.
  const liveConfig = await loadConfig();
  const fin = liveConfig?.financial || {};
  const serviceChargeRate =
    fin.appServiceChargeRate
    ?? fin.platformServiceChargeRate
    ?? 0.02;
  const traderCommissionRate = Number.isFinite(fin.traderCommissionRate)
    ? fin.traderCommissionRate
    : 0.1;
  const orderFeeRate = Number.isFinite(fin.orderFeeRate) ? fin.orderFeeRate : 0.005;
  const exchangeFeeRate = Number.isFinite(fin.exchangeFeeRate) ? fin.exchangeFeeRate : 0.0001;
  const replacements = {
    APP_NAME: liveConfig?.legal?.appName || 'FIN1',
    LEGAL_PLATFORM_NAME: liveConfig?.legal?.platformName || 'App',
    MIN_INVESTMENT: formatCurrencyEUR(liveConfig?.limits?.minInvestment),
    MAX_INVESTMENT: formatCurrencyEUR(liveConfig?.limits?.maxInvestment),
    APP_SERVICE_CHARGE_RATE: formatPercentDE(serviceChargeRate),
    PLATFORM_SERVICE_CHARGE_RATE: formatPercentDE(serviceChargeRate),
    PLATFORM_FEE_RATE: formatPercentDE(serviceChargeRate),
    TRADER_COMMISSION_RATE: formatPercentDE(traderCommissionRate),
    ORDER_FEE_RATE: formatPercentDE(orderFeeRate),
    EXCHANGE_FEE_RATE: formatPercentDE(exchangeFeeRate),
  };

  const hydratedFaqs = faqs.map((f) => {
    const merged = hydrateFaqLocaleJSON(f.toJSON());
    const row = {
      ...merged,
      question: replacePlaceholders(merged.question, replacements),
      answer: replacePlaceholders(merged.answer, replacements),
    };
    if (merged.questionEn) {
      row.questionEn = replacePlaceholders(merged.questionEn, replacements);
    }
    if (merged.answerEn) {
      row.answerEn = replacePlaceholders(merged.answerEn, replacements);
    }
    return row;
  });

  return { faqs: hydratedFaqs };
});

Parse.Cloud.define('getFAQCategories', async (request) => {
  const { location, userRole } = request.params;

  let categories;

  if (location === 'help_center') {
    // Union: Landing-Kategorien + explizite Help-Center-Kategorien (iOS filtert FAQs ohnehin nach erlaubten categoryIds).
    const qLanding = new Parse.Query('FAQCategory');
    qLanding.equalTo('isActive', true);
    qLanding.equalTo('showOnLanding', true);
    const qHelp = new Parse.Query('FAQCategory');
    qHelp.equalTo('isActive', true);
    qHelp.equalTo('showInHelpCenter', true);
    const combined = Parse.Query.or(qLanding, qHelp);
    combined.ascending('sortOrder');
    categories = await combined.find({ useMasterKey: true });
    categories = sortBySortOrder(dedupeById(categories));
  } else {
    const query = new Parse.Query('FAQCategory');
    query.equalTo('isActive', true);

    if (location === 'landing') {
      query.equalTo('showOnLanding', true);
    } else if (location === 'csr') {
      query.equalTo('showInCSR', true);
    }

    query.ascending('sortOrder');
    categories = await query.find({ useMasterKey: true });
  }

  if (userRole) {
    categories = categories.filter(c => matchesRole(c.get('targetRoles'), userRole));
  }

  categories = filterRetiredFaqCategories(categories, location);

  return { categories: categories.map(c => c.toJSON()) };
});
