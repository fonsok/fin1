'use strict';

/**
 * getTraderDocumentBelegDetail — Session user reads own trader collection bill with SSOT enrichment.
 * Alt-Belege ohne `accountingSummaryText` auf Parse werden aus Trade/Invoice nachgebaut (read-only).
 */

const { documentOwnedByUser } = require('./documentAccess');
const { enrichTraderDocumentMetadata } = require('../admin/reports/documentBelegEnrichment');
const {
  projectDocumentRow,
  findSingleDocumentByExactLedgerNumber,
} = require('../admin/reports/searchDocuments');
const { projectDocumentDetail } = require('../admin/reports/documentBelegPresentation');

const TRADER_BELEG_TYPES = new Set(['traderCollectionBill', 'trade_execution_document']);

function requireSessionUser(request) {
  const user = request.user;
  if (!user) {
    throw new Parse.Error(Parse.Error.INVALID_SESSION_TOKEN, 'Login required');
  }
  return user;
}

async function loadOwnedTraderDocument({ user, objectId, referenceDocumentNumber }) {
  let doc = null;
  if (objectId) {
    try {
      doc = await new Parse.Query('Document').get(objectId, { useMasterKey: true });
    } catch {
      doc = null;
    }
  } else if (referenceDocumentNumber) {
    doc = await findSingleDocumentByExactLedgerNumber(referenceDocumentNumber);
  }

  if (!doc || !documentOwnedByUser(doc, user)) {
    throw new Parse.Error(Parse.Error.OBJECT_NOT_FOUND, 'Document not found');
  }

  const type = String(doc.get('type') || '');
  if (!TRADER_BELEG_TYPES.has(type)) {
    throw new Parse.Error(
      Parse.Error.OPERATION_FORBIDDEN,
      'getTraderDocumentBelegDetail: only trader collection bills are supported',
    );
  }

  return doc;
}

async function handleGetTraderDocumentBelegDetail(request) {
  const user = requireSessionUser(request);
  const params = request.params || {};
  const objectId = String(params.objectId || '').trim();
  const referenceDocumentNumber = String(
    params.referenceDocumentNumber || params.accountingDocumentNumber || '',
  ).trim();

  if (!objectId && !referenceDocumentNumber) {
    throw new Parse.Error(
      Parse.Error.INVALID_QUERY,
      'getTraderDocumentBelegDetail: objectId or referenceDocumentNumber required',
    );
  }

  const doc = await loadOwnedTraderDocument({ user, objectId, referenceDocumentNumber });
  const metadata = await enrichTraderDocumentMetadata(doc);

  return {
    ...projectDocumentRow(doc),
    ...projectDocumentDetail(doc, metadata),
  };
}

function registerTraderBelegDetailFunctions() {
  Parse.Cloud.define('getTraderDocumentBelegDetail', handleGetTraderDocumentBelegDetail);
}

module.exports = {
  registerTraderBelegDetailFunctions,
  handleGetTraderDocumentBelegDetail,
  documentOwnedByUser,
};
