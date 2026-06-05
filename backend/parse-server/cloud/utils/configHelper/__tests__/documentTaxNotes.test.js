'use strict';

const {
  CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_DE,
  applyCapitalGainsTaxNotesForCollectionMode,
} = require('../documentTaxNotes');

describe('documentTaxNotes', () => {
  const sections = [
    { id: 'doc_tax_note_sell', title: 'Sell', content: 'Platform withholds on sell.' },
    { id: 'doc_tax_note_buy', title: 'Buy', content: 'Platform note on buy.' },
    { id: 'doc_tax_note_service_charge', title: 'VAT', content: 'VAT note unchanged.' },
  ];

  test('leaves sections unchanged for platform_withholds', () => {
    const out = applyCapitalGainsTaxNotesForCollectionMode(sections, 'platform_withholds', 'de');
    expect(out).toEqual(sections);
  });

  test('replaces capital gains tax notes for customer_self_reports', () => {
    const out = applyCapitalGainsTaxNotesForCollectionMode(sections, 'customer_self_reports', 'de');
    expect(out.find((s) => s.id === 'doc_tax_note_sell').content).toBe(
      CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_DE,
    );
    expect(out.find((s) => s.id === 'doc_tax_note_buy').content).toBe(
      CUSTOMER_SELF_REPORTS_CAPITAL_GAINS_NOTE_DE,
    );
    expect(out.find((s) => s.id === 'doc_tax_note_service_charge').content).toBe('VAT note unchanged.');
  });

  test('uses admin snippet doc_tax_note_customer_self_reports when present', () => {
    const withSnippet = [
      ...sections,
      {
        id: 'doc_tax_note_customer_self_reports',
        title: 'Custom',
        content: 'Admin-custom Selbstabführungstext.',
      },
    ];
    const out = applyCapitalGainsTaxNotesForCollectionMode(withSnippet, 'customer_self_reports', 'de');
    expect(out.find((s) => s.id === 'doc_tax_note_sell').content).toBe('Admin-custom Selbstabführungstext.');
  });
});
