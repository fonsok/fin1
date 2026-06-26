'use strict';

const { requireAdminRole } = require('../../../utils/permissions');
const { sanitizeOnboardingSavedData } = require('../../../utils/onboardingLegacyPickerDefaults');
const { writeDevMaintenanceAudit } = require('./shared');

/**
 * Maintenance: strip legacy step-15/16 picker defaults from stored OnboardingProgress blobs.
 * Idempotent; safe to re-run in batches until remainingCandidates is 0.
 */
function registerMigrateOnboardingLegacyPickerDefaultsFunctions() {
  Parse.Cloud.define('migrateOnboardingLegacyPickerDefaults', async (request) => {
    requireAdminRole(request);

    const batchSize = Math.min(
      Math.max(Number(request.params?.batchSize) || 100, 1),
      500,
    );
    const dryRun = request.params?.dryRun === true;

    const query = new Parse.Query('OnboardingProgress');
    query.exists('data');
    query.ascending('updatedAt');
    query.limit(batchSize);
    const rows = await query.find({ useMasterKey: true });

    const userIds = [...new Set(rows.map((row) => row.get('userId')).filter(Boolean))];
    const usersById = new Map();
    if (userIds.length) {
      const users = await new Parse.Query(Parse.User)
        .containedIn('objectId', userIds)
        .limit(userIds.length)
        .find({ useMasterKey: true });
      for (const user of users) {
        usersById.set(user.id, user);
      }
    }

    let updatedInThisCall = 0;
    const sampleObjectIds = [];

    for (const row of rows) {
      const savedData = row.get('data');
      if (!savedData || typeof savedData !== 'object') continue;

      const user = usersById.get(row.get('userId'));
      const currentStep = user?.get('onboardingStep') || null;
      const progressStep = row.get('step') || null;
      const { data, changed } = sanitizeOnboardingSavedData(savedData, {
        currentStep,
        progressStep,
      });

      if (!changed) continue;

      if (dryRun) {
        if (sampleObjectIds.length < 5) sampleObjectIds.push(row.id);
        updatedInThisCall += 1;
        continue;
      }

      row.set('data', data);
      await row.save(null, { useMasterKey: true });
      updatedInThisCall += 1;
      if (sampleObjectIds.length < 5) sampleObjectIds.push(row.id);
    }

    const remainingQuery = new Parse.Query('OnboardingProgress');
    remainingQuery.exists('data');
    const remainingCandidates = await remainingQuery.count({ useMasterKey: true });

    await writeDevMaintenanceAudit({
      action: 'migrateOnboardingLegacyPickerDefaults',
      request,
      payload: {
        batchSize,
        dryRun,
        batchExamined: rows.length,
        updatedInThisCall,
        remainingCandidates,
        sampleObjectIds,
      },
    });

    return {
      success: true,
      batchSize,
      dryRun,
      batchExamined: rows.length,
      updatedInThisCall,
      remainingCandidates,
      sampleObjectIds,
      hint: dryRun
        ? 'Call again with dryRun=false to apply. Re-run until batches return updatedInThisCall=0.'
        : 'Re-run with the same batchSize until updatedInThisCall is 0.',
    };
  });
}

module.exports = { registerMigrateOnboardingLegacyPickerDefaultsFunctions };
