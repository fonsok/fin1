'use strict';

const { round2 } = require('./shared');
const { normalizeTaxCollectionMode } = require('../configHelper/taxCollectionMode');

const CHURCH_TAX_RELIGIONS = new Set([
  'katholisch',
  'evangelisch',
  'roman_catholic',
  'catholic',
  'protestant',
  'evangelical',
]);

const EIGHT_PERCENT_STATES = new Set(['baden-wurttemberg', 'baden wuerttemberg', 'bayern']);

function normalizeString(value) {
  if (typeof value !== 'string') return '';
  return value.trim().toLowerCase();
}

function normalizeState(state) {
  return normalizeString(state)
    .replace(/ä/g, 'a')
    .replace(/ö/g, 'o')
    .replace(/ü/g, 'u')
    .replace(/ß/g, 'ss');
}

function resolveChurchTaxRate({ religion, state, country }) {
  const normReligion = normalizeString(religion);
  if (!CHURCH_TAX_RELIGIONS.has(normReligion)) return 0;

  const normCountry = normalizeString(country);
  if (normCountry && normCountry !== 'deutschland' && normCountry !== 'de' && normCountry !== 'germany') {
    return 0;
  }

  const normState = normalizeState(state);
  if (!normState) return 0;

  return EIGHT_PERCENT_STATES.has(normState) ? 0.08 : 0.09;
}

async function resolveUserTaxProfile(userId) {
  if (!userId) return null;

  const User = Parse.User;
  const candidates = [];
  const asString = String(userId);

  if (asString.startsWith('user:')) {
    const email = asString.replace('user:', '').trim().toLowerCase();
    if (email) {
      const byEmail = new Parse.Query(User);
      byEmail.equalTo('email', email);
      candidates.push(byEmail.first({ useMasterKey: true }));
    }
  }

  const byStableId = new Parse.Query(User);
  byStableId.equalTo('stableId', asString);
  candidates.push(byStableId.first({ useMasterKey: true }));

  if (!asString.startsWith('user:')) {
    const byObjectId = new Parse.Query(User);
    candidates.push(byObjectId.get(asString, { useMasterKey: true }).catch(() => null));
  }

  const resolved = await Promise.all(candidates);
  return resolved.find(Boolean) || null;
}

function calculateWithholdingBundle({ taxableAmount, taxConfig, userProfile }) {
  const taxableBase = round2(Math.max(0, Number(taxableAmount) || 0));
  if (taxableBase <= 0) {
    return {
      taxableBase: 0,
      withholdingTax: 0,
      solidaritySurcharge: 0,
      churchTax: 0,
      totalTax: 0,
      churchTaxRate: 0,
      taxCollectionMode: normalizeTaxCollectionMode(taxConfig?.taxCollectionMode),
    };
  }

  const taxCollectionMode = normalizeTaxCollectionMode(taxConfig?.taxCollectionMode);
  if (taxCollectionMode !== 'platform_withholds') {
    return {
      taxableBase,
      withholdingTax: 0,
      solidaritySurcharge: 0,
      churchTax: 0,
      totalTax: 0,
      churchTaxRate: 0,
      taxCollectionMode,
    };
  }

  const withholdingRate = Number(taxConfig?.withholdingTaxRate);
  const solidarityRate = Number(taxConfig?.solidaritySurchargeRate);
  const withholdingTax = round2(taxableBase * (Number.isFinite(withholdingRate) ? withholdingRate : 0.25));
  const solidaritySurcharge = round2(withholdingTax * (Number.isFinite(solidarityRate) ? solidarityRate : 0.055));

  const churchTaxRate = resolveChurchTaxRate({
    religion:
      userProfile?.get('religion')
      || userProfile?.get('religiousAffiliation')
      || userProfile?.get('confession')
      || '',
    state: userProfile?.get('state') || '',
    country: userProfile?.get('country') || 'Deutschland',
  });
  const churchTax = round2(withholdingTax * churchTaxRate);
  const totalTax = round2(withholdingTax + solidaritySurcharge + churchTax);

  return {
    taxableBase,
    withholdingTax,
    solidaritySurcharge,
    churchTax,
    totalTax,
    churchTaxRate,
    taxCollectionMode,
  };
}

module.exports = {
  calculateWithholdingBundle,
  resolveUserTaxProfile,
};
