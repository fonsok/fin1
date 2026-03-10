'use strict';

const { requireAdminRole } = require('../../utils/permissions');

// ============================================================================
// FAQ Data Seeding (FAQCategory + FAQ Parse classes)
// Populates the Parse classes queried by getFAQCategories / getFAQs cloud
// functions. The raw PostgreSQL tables (faq_categories, faqs) created by the
// SQL schema are separate from Parse-managed storage.
// ============================================================================

/**
 * Seed FAQ categories into Parse FAQCategory class.
 * Matches the SQL schema categories from 008_schema_faq.sql.
 */
Parse.Cloud.define('seedFAQCategories', async (request) => {
  const allowMaster = request.master || request.params.runWithMasterKey === true;
  if (!allowMaster) {
    requireAdminRole(request);
  }

  const forceReseed = request.params.forceReseed === true;
  const existingQuery = new Parse.Query('FAQCategory');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0 && !forceReseed) {
    return {
      success: false,
      message: `${existingCount} FAQ categories already exist. Use 'forceReseedFAQData' to overwrite.`,
      created: 0
    };
  }

  // targetRoles: null/[] = visible to all roles
  const categories = [
    // Landing Page categories (no role restriction – public)
    { slug: 'platform_overview', title: 'Plattform-Übersicht', displayName: 'Plattform-Übersicht', icon: 'info.circle', showOnLanding: true, showInHelpCenter: false, showInCSR: true, sortOrder: 1, targetRoles: null },
    { slug: 'getting_started', title: 'Erste Schritte', displayName: 'Erste Schritte', icon: 'play.circle', showOnLanding: true, showInHelpCenter: false, showInCSR: true, sortOrder: 2, targetRoles: null },

    // Help Center: investor-specific
    { slug: 'investments', title: 'Investitionen', displayName: 'Investitionen', icon: 'chart.line.uptrend.xyaxis', showOnLanding: true, showInHelpCenter: true, showInCSR: true, sortOrder: 3, targetRoles: ['investor'] },
    { slug: 'investor_portfolio', title: 'Mein Portfolio', displayName: 'Mein Portfolio', icon: 'chart.pie', showOnLanding: false, showInHelpCenter: true, showInCSR: true, sortOrder: 4, targetRoles: ['investor'] },

    // Help Center: trader-specific
    { slug: 'trading', title: 'Trading', displayName: 'Trading', icon: 'arrow.left.arrow.right', showOnLanding: false, showInHelpCenter: true, showInCSR: true, sortOrder: 5, targetRoles: ['trader'] },
    { slug: 'trader_pools', title: 'Investment-Pools verwalten', displayName: 'Investment-Pools verwalten', icon: 'person.2.circle', showOnLanding: false, showInHelpCenter: true, showInCSR: true, sortOrder: 6, targetRoles: ['trader'] },
    { slug: 'invoices', title: 'Rechnungen & Auszüge', displayName: 'Rechnungen & Auszüge', icon: 'doc.text', showOnLanding: false, showInHelpCenter: true, showInCSR: true, sortOrder: 7, targetRoles: ['trader'] },

    // Help Center: shared (both roles)
    { slug: 'security', title: 'Sicherheit & Authentifizierung', displayName: 'Sicherheit & Authentifizierung', icon: 'lock.shield', showOnLanding: false, showInHelpCenter: true, showInCSR: true, sortOrder: 10, targetRoles: null },
    { slug: 'notifications', title: 'Benachrichtigungen', displayName: 'Benachrichtigungen', icon: 'bell', showOnLanding: false, showInHelpCenter: true, showInCSR: true, sortOrder: 11, targetRoles: null },
    { slug: 'technical', title: 'Technischer Support', displayName: 'Technischer Support', icon: 'wrench.and.screwdriver', showOnLanding: false, showInHelpCenter: true, showInCSR: true, sortOrder: 12, targetRoles: null },
  ];

  const FAQCategory = Parse.Object.extend('FAQCategory');
  let created = 0;
  let updated = 0;

  for (const catData of categories) {
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
        updated++;
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
    created++;
  }

  console.log(`[FAQ] Seeded FAQ categories: ${created} created, ${updated} updated`);
  return { success: true, message: `Created ${created}, updated ${updated} FAQ categories`, created, updated };
});

/**
 * Seed FAQ articles into Parse FAQ class.
 * Requires FAQCategory objects to exist (run seedFAQCategories first).
 */
Parse.Cloud.define('seedFAQs', async (request) => {
  const allowMaster = request.master || request.params.runWithMasterKey === true;
  if (!allowMaster) {
    requireAdminRole(request);
  }

  const forceReseed = request.params.forceReseed === true;
  const existingQuery = new Parse.Query('FAQ');
  const existingCount = await existingQuery.count({ useMasterKey: true });

  if (existingCount > 0 && !forceReseed) {
    return {
      success: false,
      message: `${existingCount} FAQs already exist. Use 'forceReseedFAQData' to overwrite.`,
      created: 0
    };
  }

  // Build slug → objectId lookup
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

  // targetRoles: null = visible to all roles
  const faqData = [
    // ══════════════════════════════════════════════════════════════
    // LANDING PAGE FAQs (public, no role restriction)
    // ══════════════════════════════════════════════════════════════

    // ── platform_overview ──
    {
      faqId: 'faq-platform-what', categorySlug: 'platform_overview',
      question: 'Was ist {{APP_NAME}}?',
      answer: '{{APP_NAME}} ist eine innovative Investmentplattform, die Investoren mit erfahrenen Tradern verbindet. Investoren können ihr Kapital in von Tradern verwaltete Pools investieren und an deren Erfolg partizipieren.',
      sortOrder: 1, isPublished: true, isPublic: true, isUserVisible: true, targetRoles: null,
    },
    {
      faqId: 'faq-pool-system', categorySlug: 'platform_overview',
      question: 'Wie funktioniert das Investment-Pool-System?',
      answer: 'Trader erstellen Investment-Pools, in die Investoren einzahlen können. Der Trader handelt mit dem gesammelten Kapital an den Finanzmärkten. Gewinne werden proportional auf alle Investoren verteilt, abzüglich einer Provision für den Trader.',
      sortOrder: 2, isPublished: true, isPublic: true, isUserVisible: true, targetRoles: null,
    },
    {
      faqId: 'faq-who-can-use', categorySlug: 'platform_overview',
      question: 'Wer kann die Plattform nutzen?',
      answer: 'Jede natürliche Person ab 18 Jahren mit Wohnsitz in Deutschland oder der EU kann sich registrieren. Für die vollständige Nutzung ist eine Identitätsprüfung (KYC) erforderlich.',
      sortOrder: 3, isPublished: true, isPublic: true, isUserVisible: true, targetRoles: null,
    },

    // ── getting_started ──
    {
      faqId: 'faq-register', categorySlug: 'getting_started',
      question: 'Wie kann ich mich registrieren?',
      answer: 'Tippen Sie auf "Get Started" und folgen Sie dem Registrierungsprozess. Sie werden Ihre persönlichen Daten eingeben, Ihre Identität verifizieren und eine Risikoklassifizierung durchlaufen.',
      sortOrder: 1, isPublished: true, isPublic: true, isUserVisible: false, targetRoles: null,
    },
    {
      faqId: 'faq-kyc-process', categorySlug: 'getting_started',
      question: 'Was ist die KYC-Verifizierung?',
      answer: 'KYC (Know Your Customer) ist eine gesetzlich vorgeschriebene Identitätsprüfung. Sie benötigen einen gültigen Personalausweis oder Reisepass. Der Prozess dauert in der Regel nur wenige Minuten.',
      sortOrder: 2, isPublished: true, isPublic: true, isUserVisible: false, targetRoles: null,
    },
    {
      faqId: 'faq-minimum-investment', categorySlug: 'getting_started',
      question: 'Was ist der Mindestanlagebetrag?',
      answer: 'Der Mindestanlagebetrag beträgt 100 €. Sie können jederzeit weitere Beträge einzahlen oder Ihre Anlage erhöhen.',
      sortOrder: 3, isPublished: true, isPublic: true, isUserVisible: false, targetRoles: null,
    },

    // ══════════════════════════════════════════════════════════════
    // INVESTOR HELP CENTER FAQs
    // ══════════════════════════════════════════════════════════════

    // ── investments (investor only) ──
    {
      faqId: 'faq-invest-trader', categorySlug: 'investments',
      question: 'Wie kann ich in einen Trader investieren?',
      answer: 'Navigieren Sie zur Trader-Übersicht, wählen Sie einen Trader aus, der zu Ihrem Risikoprofil passt, und tippen Sie auf "Investieren". Geben Sie den gewünschten Betrag ein und bestätigen Sie die Investition.',
      sortOrder: 1, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['investor'],
    },
    {
      faqId: 'faq-risk-classes', categorySlug: 'investments',
      question: 'Was bedeuten die Risikoklassen?',
      answer: 'Die Risikoklassen reichen von 1 (konservativ) bis 7 (spekulativ). Sie werden bei der Registrierung anhand Ihrer Erfahrung und finanziellen Situation eingestuft. Sie können nur in Trader investieren, deren Risikoklasse zu Ihrer passt.',
      sortOrder: 2, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['investor'],
    },
    {
      faqId: 'faq-withdraw-investment', categorySlug: 'investments',
      question: 'Wie ziehe ich meine Investition zurück?',
      answer: 'Öffnen Sie das Investment-Detail, tippen Sie auf "Auszahlen" und geben Sie den gewünschten Betrag ein. Die Auszahlung wird innerhalb von 1–3 Werktagen auf Ihr Referenzkonto überwiesen.',
      sortOrder: 3, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['investor'],
    },
    {
      faqId: 'faq-investor-fees', categorySlug: 'investments',
      question: 'Welche Gebühren fallen für Investoren an?',
      answer: 'Investoren zahlen eine Servicegebühr von 2 % p.a. auf das investierte Kapital sowie eine Gewinnbeteiligung (Performance Fee), die vom jeweiligen Trader festgelegt wird. Alle Gebühren werden transparent in der App angezeigt.',
      sortOrder: 4, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['investor'],
    },

    // ── investor_portfolio (investor only) ──
    {
      faqId: 'faq-investor-portfolio-overview', categorySlug: 'investor_portfolio',
      question: 'Wo sehe ich meine Portfolio-Performance?',
      answer: 'Auf dem Dashboard finden Sie eine Übersicht über Ihr gesamtes Portfolio, inklusive Gewinn/Verlust, aktueller Wert und Performance-Chart. Tippen Sie auf einzelne Investments für Details.',
      sortOrder: 1, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['investor'],
    },
    {
      faqId: 'faq-investor-diversification', categorySlug: 'investor_portfolio',
      question: 'Wie diversifiziere ich mein Portfolio?',
      answer: 'Sie können in mehrere Trader mit unterschiedlichen Strategien und Risikoklassen investieren. Die Plattform zeigt Ihnen eine Übersicht Ihrer Diversifizierung und gibt Hinweise, wenn Ihr Portfolio zu konzentriert ist.',
      sortOrder: 2, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['investor'],
    },
    {
      faqId: 'faq-investor-reports', categorySlug: 'investor_portfolio',
      question: 'Wo finde ich meine Steuerbescheinigung?',
      answer: 'Steuerbescheinigungen werden jährlich automatisch erstellt und stehen unter Profil → Dokumente zum Download bereit. Sie erhalten eine Benachrichtigung, sobald das Dokument verfügbar ist.',
      sortOrder: 3, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['investor'],
    },

    // ══════════════════════════════════════════════════════════════
    // TRADER HELP CENTER FAQs
    // ══════════════════════════════════════════════════════════════

    // ── trading (trader only) ──
    {
      faqId: 'faq-place-order', categorySlug: 'trading',
      question: 'Wie platziere ich eine Order?',
      answer: 'Im Trading-Bereich können Sie Wertpapiere suchen, analysieren und Orders platzieren. Wählen Sie das gewünschte Wertpapier, geben Sie die Menge ein und wählen Sie den Ordertyp (Market oder Limit).',
      sortOrder: 1, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['trader'],
    },
    {
      faqId: 'faq-order-types', categorySlug: 'trading',
      question: 'Welche Ordertypen gibt es?',
      answer: 'Es gibt Market-Orders (sofortige Ausführung zum aktuellen Kurs) und Limit-Orders (Ausführung erst bei Erreichen eines bestimmten Kurses). Limit-Orders sind 30 Tage gültig.',
      sortOrder: 2, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['trader'],
    },
    {
      faqId: 'faq-trading-hours', categorySlug: 'trading',
      question: 'Wann kann ich handeln?',
      answer: 'Der Handel ist während der Börsenöffnungszeiten möglich (Xetra: Mo–Fr 9:00–17:30 Uhr). Limit-Orders können jederzeit aufgegeben werden und werden bei Börsenöffnung ausgeführt, wenn der Kurs erreicht wird.',
      sortOrder: 3, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['trader'],
    },

    // ── trader_pools (trader only) ──
    {
      faqId: 'faq-create-pool', categorySlug: 'trader_pools',
      question: 'Wie erstelle ich einen Investment-Pool?',
      answer: 'Gehen Sie zu "Meine Pools" → "Neuen Pool erstellen". Definieren Sie Name, Strategie, Risikoklasse und Gebührenstruktur. Nach der Prüfung durch unser Compliance-Team wird der Pool für Investoren sichtbar.',
      sortOrder: 1, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['trader'],
    },
    {
      faqId: 'faq-pool-commission', categorySlug: 'trader_pools',
      question: 'Wie wird meine Provision berechnet?',
      answer: 'Ihre Provision setzt sich aus einer Verwaltungsgebühr und einer Performance Fee zusammen. Die Performance Fee wird nur auf Gewinne berechnet. Details finden Sie in Ihren Pool-Einstellungen und auf der monatlichen Abrechnung.',
      sortOrder: 2, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['trader'],
    },
    {
      faqId: 'faq-pool-investors', categorySlug: 'trader_pools',
      question: 'Wie sehe ich, wer in meinen Pool investiert hat?',
      answer: 'Unter "Meine Pools" → Pool-Detail → "Investoren" finden Sie eine anonymisierte Übersicht aller Investoren, deren Investitionsbetrag und -zeitpunkt. Aus Datenschutzgründen sind die Namen nicht sichtbar.',
      sortOrder: 3, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['trader'],
    },

    // ── invoices (trader only) ──
    {
      faqId: 'faq-trader-invoices', categorySlug: 'invoices',
      question: 'Wo finde ich meine Provisionsabrechnungen?',
      answer: 'Alle Provisionsabrechnungen und Gutschriften finden Sie unter Profil → Dokumente → Abrechnungen. Monatliche Abrechnungen werden automatisch am 5. des Folgemonats erstellt.',
      sortOrder: 1, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['trader'],
    },
    {
      faqId: 'faq-trader-payout', categorySlug: 'invoices',
      question: 'Wann erhalte ich meine Auszahlung?',
      answer: 'Provisionen werden monatlich abgerechnet. Die Auszahlung erfolgt automatisch innerhalb von 5 Werktagen nach Rechnungsstellung auf Ihr hinterlegtes Bankkonto.',
      sortOrder: 2, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: ['trader'],
    },

    // ══════════════════════════════════════════════════════════════
    // SHARED HELP CENTER FAQs (all roles)
    // ══════════════════════════════════════════════════════════════

    // ── security ──
    {
      faqId: 'faq-2fa', categorySlug: 'security',
      question: 'Wie aktiviere ich die Zwei-Faktor-Authentifizierung?',
      answer: 'Gehen Sie zu Profil → Sicherheit → Zwei-Faktor-Authentifizierung. Sie können zwischen TOTP (Authenticator-App) und biometrischer Authentifizierung (Face ID / Touch ID) wählen.',
      sortOrder: 1, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: null,
    },
    {
      faqId: 'faq-password-reset', categorySlug: 'security',
      question: 'Wie setze ich mein Passwort zurück?',
      answer: 'Tippen Sie auf dem Login-Bildschirm auf "Passwort vergessen?". Sie erhalten einen Link per E-Mail, über den Sie ein neues Passwort festlegen können. Der Link ist 24 Stunden gültig.',
      sortOrder: 2, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: null,
    },

    // ── notifications ──
    {
      faqId: 'faq-push-notifications', categorySlug: 'notifications',
      question: 'Welche Benachrichtigungen erhalte ich?',
      answer: 'Sie erhalten Push-Benachrichtigungen zu wichtigen Kontobewegungen, Sicherheitsereignissen und Statusänderungen. In den Einstellungen können Sie einzelne Kategorien aktivieren oder deaktivieren.',
      sortOrder: 1, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: null,
    },

    // ── technical ──
    {
      faqId: 'faq-app-crash', categorySlug: 'technical',
      question: 'Die App stürzt ab – was kann ich tun?',
      answer: 'Stellen Sie sicher, dass Sie die neueste App-Version verwenden (App Store → Updates). Falls das Problem weiterbesteht, löschen Sie die App und installieren Sie sie neu. Ihre Daten bleiben erhalten.',
      sortOrder: 1, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: null,
    },
    {
      faqId: 'faq-connectivity', categorySlug: 'technical',
      question: 'Verbindungsprobleme – was soll ich tun?',
      answer: 'Prüfen Sie Ihre Internetverbindung. Falls die App keine Verbindung zum Server herstellen kann, starten Sie die App neu. Bei anhaltenden Problemen kontaktieren Sie bitte unseren Support.',
      sortOrder: 2, isPublished: true, isPublic: false, isUserVisible: true, targetRoles: null,
    },
  ];

  const FAQ = Parse.Object.extend('FAQ');
  let created = 0;
  let updated = 0;
  const skipped = [];

  for (const item of faqData) {
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
        updated++;
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
    created++;
  }

  console.log(`[FAQ] Seeded FAQ articles: ${created} created, ${updated} updated` + (skipped.length ? ` (skipped ${skipped.length}: ${skipped.join(', ')})` : ''));
  return { success: true, message: `Created ${created}, updated ${updated} FAQ articles`, created, updated, skipped };
});

/**
 * Seed both FAQ categories and FAQ articles together.
 * Can be called with Master Key or by an admin user.
 */
Parse.Cloud.define('seedFAQData', async (request) => {
  if (!request.master) {
    requireAdminRole(request);
  }

  const opts = request.master
    ? { useMasterKey: true }
    : { sessionToken: request.user.getSessionToken() };

  const results = {};

  try {
    results.categories = await Parse.Cloud.run('seedFAQCategories', {}, opts);
  } catch (e) {
    results.categories = { success: false, error: e.message };
  }

  try {
    results.faqs = await Parse.Cloud.run('seedFAQs', {}, opts);
  } catch (e) {
    results.faqs = { success: false, error: e.message };
  }

  return results;
});

/**
 * Delete all FAQ and FAQCategory objects. Master key only (no admin user required).
 * Use before re-seeding when you want a clean slate.
 */
Parse.Cloud.define('deleteAllFAQData', async (request) => {
  if (!request.master) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Master key required');
  }

  const faqQuery = new Parse.Query('FAQ');
  faqQuery.limit(2000);
  const existingFaqs = await faqQuery.find({ useMasterKey: true });
  let deletedFaqs = 0;
  for (const obj of existingFaqs) {
    try {
      await obj.destroy({ useMasterKey: true });
      deletedFaqs++;
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
      await obj.destroy({ useMasterKey: true });
      deletedCats++;
    } catch (e) {
      if (e.code !== 101) console.warn('[FAQ] destroy category failed:', e.message);
    }
  }

  return { success: true, deletedFaqs: deletedFaqs, deletedCategories: deletedCats };
});

/**
 * Force-reseed FAQ data (deletes existing FAQCategory + FAQ objects first).
 * Call with master key, or as admin user. When using master key, nested seed runs with runWithMasterKey param.
 */
Parse.Cloud.define('forceReseedFAQData', async (request) => {
  const allowed = request.master || (request.user && request.user.get('role') === 'admin');
  if (!allowed) {
    throw new Parse.Error(Parse.Error.OPERATION_FORBIDDEN, 'Master key or admin role required');
  }

  // Delete existing FAQs first, then categories. Destroy one-by-one to avoid
  // destroyAll throwing "Object not found" (101) for some stored objects.
  const faqQuery = new Parse.Query('FAQ');
  faqQuery.limit(2000);
  const existingFaqs = await faqQuery.find({ useMasterKey: true });
  for (const obj of existingFaqs) {
    try {
      await obj.destroy({ useMasterKey: true });
    } catch (e) {
      // Log but continue; 101 can occur for legacy/different schema objects
      if (e.code !== 101) console.warn('[FAQ] destroy FAQ failed:', e.message);
    }
  }
  const catQuery = new Parse.Query('FAQCategory');
  catQuery.limit(2000);
  const existingCats = await catQuery.find({ useMasterKey: true });
  for (const obj of existingCats) {
    try {
      await obj.destroy({ useMasterKey: true });
    } catch (e) {
      if (e.code !== 101) console.warn('[FAQ] destroy category failed:', e.message);
    }
  }

  const opts = request.master
    ? { useMasterKey: true }
    : { sessionToken: request.user.getSessionToken() };
  const seedParams = request.master ? { runWithMasterKey: true, forceReseed: true } : { forceReseed: true };

  const results = {};
  try {
    results.categories = await Parse.Cloud.run('seedFAQCategories', seedParams, opts);
  } catch (e) {
    results.categories = { success: false, error: e.message };
  }
  try {
    results.faqs = await Parse.Cloud.run('seedFAQs', seedParams, opts);
  } catch (e) {
    results.faqs = { success: false, error: e.message };
  }
  return results;
});

/**
 * Seed all mock data at once
