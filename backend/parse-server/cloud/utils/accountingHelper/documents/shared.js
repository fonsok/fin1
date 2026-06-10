'use strict';

const { round2 } = require('../shared');

function applyBusinessCaseIdToDocument(doc, businessCaseId) {
  const bc = String(businessCaseId || '').trim();
  if (!bc) return;
  doc.set('businessCaseId', bc);
  const meta = doc.get('metadata') || {};
  doc.set('metadata', Object.assign({}, meta, { businessCaseId: bc }));
}

function formatEuroDe(amount) {
  const n = round2(Math.abs(Number(amount) || 0));
  return new Intl.NumberFormat('de-DE', { style: 'currency', currency: 'EUR' }).format(n);
}

function formatDateTimeDe(d) {
  try {
    return new Intl.DateTimeFormat('de-DE', {
      dateStyle: 'long',
      timeStyle: 'short',
    }).format(d instanceof Date ? d : new Date(d));
  } catch {
    return String(d);
  }
}

module.exports = {
  applyBusinessCaseIdToDocument,
  formatEuroDe,
  formatDateTimeDe,
};
