'use strict';

const { handleExportLegalDocumentsBackup } = require('./legalImportExportExportFull');
const { handleExportActiveLegalDocumentsBackup } = require('./legalImportExportExportActive');
const { handleImportLegalDocumentsBackup } = require('./legalImportExportImportFull');
const { handleImportActiveLegalDocumentsBackup } = require('./legalImportExportImportActive');

function registerLegalImportExportFunctions() {
  Parse.Cloud.define('exportLegalDocumentsBackup', handleExportLegalDocumentsBackup);
  Parse.Cloud.define('exportActiveLegalDocumentsBackup', handleExportActiveLegalDocumentsBackup);
  Parse.Cloud.define('importLegalDocumentsBackup', handleImportLegalDocumentsBackup);
  Parse.Cloud.define('importActiveLegalDocumentsBackup', handleImportActiveLegalDocumentsBackup);
}

module.exports = {
  registerLegalImportExportFunctions,
};
