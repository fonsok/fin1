// ============================================================================
// Parse Cloud Code — Invoice triggers
//   1) Service-Charge invoices  → BankContraPosting + AppLedger triple
//   2) Order invoices           → AppLedger order-fee pairs (ADR-010 / PR4)
// Einstieg: triggers/invoice/index.js
// ============================================================================

'use strict';

const { invoiceBeforeSave } = require('./invoiceTriggerBeforeSave');
const { invoiceAfterSave } = require('./invoiceTriggerAfterSave');

Parse.Cloud.beforeSave('Invoice', invoiceBeforeSave);
Parse.Cloud.afterSave('Invoice', invoiceAfterSave);
