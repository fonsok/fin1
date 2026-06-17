'use strict';

const { audit } = require('../../utils/structuredLogger');
const {
  inspectAccountStatementCentAlignment,
} = require('../../utils/accountingHelper/accountStatementCentAlignmentInspect');

/**
 * Admin: inspect recent AccountStatement rows for cent-aligned monetary fields.
 */
async function handleInspectAccountStatementCentAlignment(request) {
  const params = request.params || {};
  const report = await inspectAccountStatementCentAlignment(params);

  audit.info('admin.accountStatement.centAlignmentInspect', {
    examined: report.examined,
    alignedRows: report.alignedRows,
    violationRows: report.violationRows,
    healthy: report.healthy,
    message: 'checkAccountStatementCentAlignment completed',
  });

  return report;
}

module.exports = {
  handleInspectAccountStatementCentAlignment,
};
