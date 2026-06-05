'use strict';

const { TAX_COLLECTION_MODES, normalizeTaxCollectionMode } = require('./taxCollectionMode');

/** Canonical Abgeltungssteuer-Hinweis when the customer files taxes (Selbstabführung). */
const CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_DE =
  'Allgemein: Grundsätzlich wird Abgeltungssteuer nicht an Finanzamt überwiesen.';

const CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_EN =
  'General: As a rule, capital gains tax (Abgeltungsteuer) is not transferred to the tax office.';

const CAPITAL_GAINS_TAX_NOTE_SECTION_IDS = Object.freeze([
  'doc_tax_note_sell',
  'doc_tax_note_buy',
]);

const CUSTOMER_SELF_REPORTS_SNIPPET_ID = 'doc_tax_note_customer_self_reports';

function resolveCustomerSelfReportsCapitalGainsNote(sections, language) {
  const fromSnippet = (sections || []).find((section) => section.id === CUSTOMER_SELF_REPORTS_SNIPPET_ID);
  const content = typeof fromSnippet?.content === 'string' ? fromSnippet.content.trim() : '';
  if (content) return content;
  return language === 'en'
    ? CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_EN
    : CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_DE;
}

/**
 * When tax is self-reported, capital-gains document snippets must not imply platform withholding.
 * @param {Array<{id: string, title?: string, content?: string}>} sections
 * @param {string} taxCollectionMode
 * @param {string} [language]
 */
function applyCapitalGainsTaxNotesForCollectionMode(sections, taxCollectionMode, language = 'de') {
  if (!Array.isArray(sections)) return sections;
  if (normalizeTaxCollectionMode(taxCollectionMode) !== TAX_COLLECTION_MODES.CUSTOMER_SELF_REPORTS) {
    return sections;
  }

  const replacementContent = resolveCustomerSelfReportsCapitalGainsNote(sections, language);
  return sections.map((section) => {
    if (!CAPITAL_GAINS_TAX_NOTE_SECTION_IDS.includes(section.id)) {
      return section;
    }
    return {
      ...section,
      content: replacementContent,
    };
  });
}

module.exports = {
  CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_DE,
  CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_EN,
  CAPITAL_GAINS_TAX_NOTE_SECTION_IDS,
  CUSTOMER_SELF_REPORTS_SNIPPET_ID,
  resolveCustomerSelfReportsCapitalGainsNote,
  applyCapitalGainsTaxNotesForCollectionMode,
};
