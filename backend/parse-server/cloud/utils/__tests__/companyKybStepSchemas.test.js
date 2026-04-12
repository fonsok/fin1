'use strict';

const {
  createValidateCompanyKybStepData,
  createValidatePartialCompanyKybData,
} = require('../companyKybStepSchemas');

const validators = {
  isValidBirthDate: (v) => {
    if (!v) return false;
    const d = new Date(v);
    if (Number.isNaN(d.getTime())) return false;
    if (d > new Date()) return false;
    const age = (Date.now() - d.getTime()) / (365.25 * 24 * 60 * 60 * 1000);
    return age >= 18 && age <= 120;
  },
  isValidGermanPostalCode: (v) => typeof v === 'string' && /^\d{5}$/.test(v.trim()),
};

const validateComplete = createValidateCompanyKybStepData(validators);
const validatePartial = createValidatePartialCompanyKybData(validators);

// ---------------------------------------------------------------------------
// legal_entity
// ---------------------------------------------------------------------------
describe('legal_entity', () => {
  const minimal = {
    legalName: 'Acme GmbH',
    legalForm: 'GmbH',
    registerType: 'HRB',
    registerNumber: '123456',
    registerCourt: 'Frankfurt am Main',
    incorporationCountry: 'DE',
  };

  test('complete accepts minimal valid payload', () => {
    expect(validateComplete('legal_entity', minimal)).toEqual({ valid: true });
  });

  test('complete rejects missing legalName', () => {
    const { legalName, ...rest } = minimal;
    expect(validateComplete('legal_entity', rest).valid).toBe(false);
  });

  test('complete rejects empty legalName', () => {
    expect(validateComplete('legal_entity', { ...minimal, legalName: '' }).valid).toBe(false);
  });

  test('complete rejects invalid incorporationCountry length', () => {
    expect(validateComplete('legal_entity', { ...minimal, incorporationCountry: 'DEU' }).valid).toBe(false);
  });

  test('complete allows optional notRegisteredReason', () => {
    expect(validateComplete('legal_entity', { ...minimal, notRegisteredReason: 'In Gründung' })).toEqual({ valid: true });
  });

  test('partial allows sparse fields', () => {
    expect(validatePartial('legal_entity', { legalName: 'Partial' })).toEqual({ valid: true });
  });

  test('partial allows empty object', () => {
    expect(validatePartial('legal_entity', {})).toEqual({ valid: true });
  });
});

// ---------------------------------------------------------------------------
// registered_address
// ---------------------------------------------------------------------------
describe('registered_address', () => {
  const minimal = {
    streetAndNumber: 'Hauptstr. 1',
    postalCode: '60311',
    city: 'Frankfurt',
    country: 'DE',
  };

  test('complete accepts minimal valid payload', () => {
    expect(validateComplete('registered_address', minimal)).toEqual({ valid: true });
  });

  test('complete rejects missing city', () => {
    const { city, ...rest } = minimal;
    expect(validateComplete('registered_address', rest).valid).toBe(false);
  });

  test('complete rejects short streetAndNumber', () => {
    expect(validateComplete('registered_address', { ...minimal, streetAndNumber: 'AB' }).valid).toBe(false);
  });

  test('complete allows optional business address', () => {
    expect(validateComplete('registered_address', {
      ...minimal,
      businessStreetAndNumber: 'Nebenstr. 5',
      businessPostalCode: '10115',
      businessCity: 'Berlin',
      businessCountry: 'DE',
    })).toEqual({ valid: true });
  });

  test('partial allows sparse fields', () => {
    expect(validatePartial('registered_address', { city: 'München' })).toEqual({ valid: true });
  });
});

// ---------------------------------------------------------------------------
// tax_compliance
// ---------------------------------------------------------------------------
describe('tax_compliance', () => {
  test('complete rejects empty identifiers', () => {
    expect(validateComplete('tax_compliance', {}).valid).toBe(false);
  });

  test('complete accepts vatId', () => {
    expect(validateComplete('tax_compliance', { vatId: 'DE123456789' })).toEqual({ valid: true });
  });

  test('complete accepts nationalTaxNumber', () => {
    expect(validateComplete('tax_compliance', { nationalTaxNumber: '12/345/67890' })).toEqual({ valid: true });
  });

  test('complete accepts noVatIdDeclared', () => {
    expect(validateComplete('tax_compliance', { noVatIdDeclared: true })).toEqual({ valid: true });
  });

  test('complete rejects only whitespace vatId without alternative', () => {
    expect(validateComplete('tax_compliance', { vatId: '   ' }).valid).toBe(false);
  });

  test('complete allows economicIdentificationNumber', () => {
    expect(validateComplete('tax_compliance', { vatId: 'DE123', economicIdentificationNumber: 'W-ID-001' })).toEqual({ valid: true });
  });

  test('partial allows empty object', () => {
    expect(validatePartial('tax_compliance', {})).toEqual({ valid: true });
  });
});

// ---------------------------------------------------------------------------
// beneficial_owners
// ---------------------------------------------------------------------------
describe('beneficial_owners', () => {
  const validUbo = {
    fullName: 'Max Mustermann',
    dateOfBirth: '1980-05-15',
    nationality: 'DE',
  };

  test('complete accepts noUboOver25Percent', () => {
    expect(validateComplete('beneficial_owners', { noUboOver25Percent: true })).toEqual({ valid: true });
  });

  test('complete accepts valid UBO array', () => {
    expect(validateComplete('beneficial_owners', { ubos: [validUbo] })).toEqual({ valid: true });
  });

  test('complete accepts UBO with optional fields', () => {
    expect(validateComplete('beneficial_owners', {
      ubos: [{ ...validUbo, ownershipPercent: 51, directOrIndirect: 'direct' }],
    })).toEqual({ valid: true });
  });

  test('complete rejects neither ubos nor noUboOver25Percent', () => {
    expect(validateComplete('beneficial_owners', {}).valid).toBe(false);
  });

  test('complete rejects empty ubos array without flag', () => {
    expect(validateComplete('beneficial_owners', { ubos: [] }).valid).toBe(false);
  });

  test('complete rejects UBO without fullName', () => {
    const { fullName, ...rest } = validUbo;
    expect(validateComplete('beneficial_owners', { ubos: [rest] }).valid).toBe(false);
  });

  test('complete rejects UBO with underage dateOfBirth', () => {
    const recentDate = new Date();
    recentDate.setFullYear(recentDate.getFullYear() - 10);
    expect(validateComplete('beneficial_owners', {
      ubos: [{ ...validUbo, dateOfBirth: recentDate.toISOString().slice(0, 10) }],
    }).valid).toBe(false);
  });

  test('complete rejects invalid directOrIndirect value', () => {
    expect(validateComplete('beneficial_owners', {
      ubos: [{ ...validUbo, directOrIndirect: 'maybe' }],
    }).valid).toBe(false);
  });

  test('partial allows sparse UBO data', () => {
    expect(validatePartial('beneficial_owners', { ubos: [{ fullName: 'Test' }] })).toEqual({ valid: true });
  });
});

// ---------------------------------------------------------------------------
// authorized_representatives
// ---------------------------------------------------------------------------
describe('authorized_representatives', () => {
  const validRep = {
    fullName: 'Anna Vertreterin',
    roleTitle: 'Geschäftsführerin',
    signingAuthority: true,
  };

  test('complete accepts valid representative', () => {
    expect(validateComplete('authorized_representatives', {
      representatives: [validRep],
    })).toEqual({ valid: true });
  });

  test('complete accepts with appAccountHolderIsRepresentative', () => {
    expect(validateComplete('authorized_representatives', {
      representatives: [validRep],
      appAccountHolderIsRepresentative: true,
    })).toEqual({ valid: true });
  });

  test('complete rejects missing representatives', () => {
    expect(validateComplete('authorized_representatives', {}).valid).toBe(false);
  });

  test('complete rejects empty representatives array', () => {
    expect(validateComplete('authorized_representatives', { representatives: [] }).valid).toBe(false);
  });

  test('complete rejects representative without fullName', () => {
    const { fullName, ...rest } = validRep;
    expect(validateComplete('authorized_representatives', { representatives: [rest] }).valid).toBe(false);
  });

  test('partial allows sparse data', () => {
    expect(validatePartial('authorized_representatives', {
      representatives: [{ fullName: 'Partial' }],
    })).toEqual({ valid: true });
  });
});

// ---------------------------------------------------------------------------
// documents
// ---------------------------------------------------------------------------
describe('documents', () => {
  test('complete accepts documentsAcknowledged true', () => {
    expect(validateComplete('documents', { documentsAcknowledged: true })).toEqual({ valid: true });
  });

  test('complete rejects documentsAcknowledged false', () => {
    expect(validateComplete('documents', { documentsAcknowledged: false }).valid).toBe(false);
  });

  test('complete rejects missing documentsAcknowledged', () => {
    expect(validateComplete('documents', {}).valid).toBe(false);
  });

  test('complete accepts with manifest', () => {
    expect(validateComplete('documents', {
      documentsAcknowledged: true,
      tradeRegisterExtractReference: 'REF-001',
      documentManifest: [
        { documentType: 'trade_register', referenceId: 'doc-abc' },
      ],
    })).toEqual({ valid: true });
  });

  test('complete rejects manifest entry without referenceId', () => {
    expect(validateComplete('documents', {
      documentsAcknowledged: true,
      documentManifest: [{ documentType: 'trade_register' }],
    }).valid).toBe(false);
  });

  test('partial allows empty object', () => {
    expect(validatePartial('documents', {})).toEqual({ valid: true });
  });
});

// ---------------------------------------------------------------------------
// declarations
// ---------------------------------------------------------------------------
describe('declarations', () => {
  const valid = {
    isPoliticallyExposed: false,
    sanctionsSelfDeclarationAccepted: true,
    accuracyDeclarationAccepted: true,
    noTrustThirdPartyDeclarationAccepted: true,
  };

  test('complete accepts all declarations', () => {
    expect(validateComplete('declarations', valid)).toEqual({ valid: true });
  });

  test('complete accepts PEP with details', () => {
    expect(validateComplete('declarations', {
      ...valid,
      isPoliticallyExposed: true,
      pepDetails: 'Mitglied des Bundestages',
    })).toEqual({ valid: true });
  });

  test('complete rejects sanctionsSelfDeclarationAccepted false', () => {
    expect(validateComplete('declarations', { ...valid, sanctionsSelfDeclarationAccepted: false }).valid).toBe(false);
  });

  test('complete rejects missing isPoliticallyExposed', () => {
    const { isPoliticallyExposed, ...rest } = valid;
    expect(validateComplete('declarations', rest).valid).toBe(false);
  });

  test('complete rejects missing accuracyDeclarationAccepted', () => {
    const { accuracyDeclarationAccepted, ...rest } = valid;
    expect(validateComplete('declarations', rest).valid).toBe(false);
  });

  test('partial allows empty object', () => {
    expect(validatePartial('declarations', {})).toEqual({ valid: true });
  });
});

// ---------------------------------------------------------------------------
// submission
// ---------------------------------------------------------------------------
describe('submission', () => {
  test('complete accepts confirmedSummary true', () => {
    expect(validateComplete('submission', { confirmedSummary: true })).toEqual({ valid: true });
  });

  test('complete accepts with fourEyesRequestId', () => {
    expect(validateComplete('submission', {
      confirmedSummary: true,
      companyFourEyesRequestId: 'req-456',
    })).toEqual({ valid: true });
  });

  test('complete rejects confirmedSummary false', () => {
    expect(validateComplete('submission', { confirmedSummary: false }).valid).toBe(false);
  });

  test('complete rejects missing confirmedSummary', () => {
    expect(validateComplete('submission', {}).valid).toBe(false);
  });

  test('partial allows empty object', () => {
    expect(validatePartial('submission', {})).toEqual({ valid: true });
  });
});

// ---------------------------------------------------------------------------
// unknown step
// ---------------------------------------------------------------------------
describe('unknown step', () => {
  test('returns valid for complete', () => {
    expect(validateComplete('unknownStep', { foo: 1 })).toEqual({ valid: true });
  });

  test('returns valid for partial', () => {
    expect(validatePartial('unknownStep', { bar: 2 })).toEqual({ valid: true });
  });
});
