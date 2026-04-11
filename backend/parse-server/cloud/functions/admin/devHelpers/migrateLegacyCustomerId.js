'use strict';

const { requireAdminRole } = require('../../../utils/permissions');
const { writeDevMaintenanceAudit } = require('./shared');

/**
 * One-time / maintenance: copy legacy `customerId` → `userId` and remove `customerId`
 * on SupportTicket and SatisfactionSurvey (same rules as triggers/support.js beforeSave).
 * Admin-only; idempotent for already-migrated rows.
 */
function registerMigrateLegacyCustomerIdFunctions() {
  Parse.Cloud.define('migrateLegacyCustomerIdToUserId', async (request) => {
    requireAdminRole(request);

    const batchSize = Math.min(
      Math.max(Number(request.params?.batchSize) || 100, 1),
      500,
    );
    const dryRun = request.params?.dryRun === true;

    const classes = [
      { name: 'SupportTicket', label: 'SupportTicket' },
      { name: 'SatisfactionSurvey', label: 'SatisfactionSurvey' },
    ];

    const summary = [];

    for (const { name, label } of classes) {
      const q = new Parse.Query(name);
      q.exists('customerId');
      q.limit(batchSize);
      const rows = await q.find({ useMasterKey: true });

      let updated = 0;
      const sampleIds = [];

      if (!dryRun) {
        for (const row of rows) {
          const legacy = row.get('customerId');
          const uid = row.get('userId');
          if (legacy && !uid) {
            row.set('userId', legacy);
          }
          if (legacy !== undefined) {
            row.unset('customerId');
          }
          await row.save(null, { useMasterKey: true });
          updated += 1;
          if (sampleIds.length < 5) sampleIds.push(row.id);
        }
      }

      const remainingQ = new Parse.Query(name);
      remainingQ.exists('customerId');
      const remaining = await remainingQ.count({ useMasterKey: true });

      summary.push({
        className: label,
        batchExamined: rows.length,
        updatedInThisCall: dryRun ? 0 : updated,
        remainingWithCustomerId: remaining,
        dryRun,
        sampleObjectIds: dryRun ? rows.slice(0, 5).map((r) => r.id) : sampleIds,
      });
    }

    await writeDevMaintenanceAudit({
      action: 'migrateLegacyCustomerIdToUserId',
      request,
      payload: { batchSize, dryRun, summary },
    });

    return {
      success: true,
      batchSize,
      dryRun,
      summary,
      hint: dryRun
        ? 'Call again with dryRun=false to apply. Re-run until remainingWithCustomerId is 0 for each class.'
        : 'Re-run with same batchSize until remainingWithCustomerId is 0.',
    };
  });
}

module.exports = { registerMigrateLegacyCustomerIdFunctions };
