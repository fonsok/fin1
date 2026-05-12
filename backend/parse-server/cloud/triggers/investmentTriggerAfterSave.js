'use strict';

const { handleInvestmentAfterSaveCreated } = require('./investmentTriggerAfterSaveCreated');
const { handleInvestmentAfterSaveActivated } = require('./investmentTriggerAfterSaveActivate');
const { handleInvestmentAfterSaveCompleted } = require('./investmentTriggerAfterSaveComplete');
const { handleInvestmentAfterSaveCancelled } = require('./investmentTriggerAfterSaveCancel');
const { logInvestmentAudit } = require('./investmentTriggerHelpers');

Parse.Cloud.afterSave('Investment', async (request) => {
  const investment = request.object;
  const isNew = !request.original;

  if (isNew) {
    await handleInvestmentAfterSaveCreated(investment);
  }

  if (request.original) {
    const oldStatus = request.original.get('status');
    const newStatus = investment.get('status');

    if (oldStatus !== newStatus) {
      await logInvestmentAudit(investment.id,
        newStatus === 'active' ? 'activated'
          : newStatus === 'completed' ? 'completed'
            : newStatus === 'cancelled' ? 'cancelled' : 'status_change',
        oldStatus, newStatus);

      if (newStatus === 'active') {
        await handleInvestmentAfterSaveActivated(investment);
      } else if (newStatus === 'completed') {
        await handleInvestmentAfterSaveCompleted(investment, oldStatus);
      } else if (newStatus === 'cancelled') {
        await handleInvestmentAfterSaveCancelled(investment, oldStatus, investment.get('amount'));
      }
    }
  }
});
