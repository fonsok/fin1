'use strict';

// ============================================================================
// Landing / AI positioning content (for KI-Suche, App-Store, Accessibility)
// Source of truth: 12_PRODUKT_MERKMALE_KI_FAQ.md Abschnitt 6–7
// ============================================================================

const APP_NAME = process.env.FIN1_LEGAL_APP_NAME || 'FIN1';

/** AI positioning texts – Kurzfassung (für Landing-Anzeige, Subtitle, Meta) */
const SUMMARY = {
  de: 'Investment-App für Anleger und Trader: denselben Trade wie der gewählte Trader (simultan), anteilige Gewinn- und Verlustbeteiligung. KYC, Risikoklassen, EU.',
  en: 'Investment app linking investors and traders: same trade as chosen trader (simultaneous execution), proportional returns and risks. KYC, risk classes, EU.',
};

/** Vollständige Einordnung (für Accessibility, Store-Beschreibung, RAG) */
const FULL = {
  de: `${APP_NAME} ist eine mobile Investment-App, die Privatanleger mit verifizierten Tradern verbindet: das Kapital der Anleger ist dem gewählten Trader zugeordnet; führt der Trader einen Trade aus, wird ein simultaner Trade mit dem entsprechenden Pool-Kapital ausgeführt; Gewinne und Verluste werden anteilig unter den beteiligten Investoren verteilt. KYC, Risikoklassifizierung, Nutzer in der EU.`,
  en: `${APP_NAME} is a mobile investment app that connects retail investors with verified traders: investors' capital is assigned to their chosen trader; when the trader executes a trade, a simultaneous trade is run with the corresponding pool capital; profits and losses are shared proportionally among participating investors. KYC, risk classification, users in the EU.`,
};

/** High-Risk-High-Gain-Einzeiler (Tagline) */
const HIGH_RISK_ONE_LINER = {
  de: `Die App ist eine High-Risk-High-Gain-Investment-App mit Verbindung von Anlegern und Tradern: Anleger führen denselben Trade eines gewählten Traders simultan mit (Kapital dem Trader zugeordnet), anteilige Gewinn- und Verlustbeteiligung, KYC und Risikoklassifizierung für Nutzer in der EU.`,
  en: 'The app is a high-risk-high-gain investment app that connects investors and traders: investors participate in the same trade as their chosen trader (simultaneous execution, capital assigned to trader), proportional profit and loss sharing, KYC and risk classification for users in the EU.',
};

/** Empfohlene Keywords für App-Store / Suchoptimierung */
const KEYWORDS = ['high-risk-high-gain', 'investment app', 'investors traders', 'simultaneous trade', 'proportional', 'KYC', 'EU'];

/**
 * Returns landing/AI positioning content for display, accessibility, and store listings.
 * Public (no auth required) so landing page and crawlers can use it.
 *
 * @param {Object} request.params.locale - Optional: 'de' | 'en'. If omitted, returns both.
 * @returns {Object} { summary, full, highRiskOneLiner, keywords [, byLocale: { de: {...}, en: {...} }] }
 */
Parse.Cloud.define('getLandingAIContent', async (request) => {
  const locale = (request.params.locale || '').toLowerCase();
  const singleLocale = locale === 'de' || locale === 'en';

  if (singleLocale) {
    return {
      summary: SUMMARY[locale],
      full: FULL[locale],
      highRiskOneLiner: HIGH_RISK_ONE_LINER[locale],
      keywords: KEYWORDS,
      locale,
    };
  }

  return {
    byLocale: {
      de: { summary: SUMMARY.de, full: FULL.de, highRiskOneLiner: HIGH_RISK_ONE_LINER.de },
      en: { summary: SUMMARY.en, full: FULL.en, highRiskOneLiner: HIGH_RISK_ONE_LINER.en },
    },
    keywords: KEYWORDS,
  };
});
