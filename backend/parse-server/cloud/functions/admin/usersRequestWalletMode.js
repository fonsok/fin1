'use strict';

const { normalizeWalletActionMode, USER_WALLET_ACTION_MODES } = require('./usersConstants');

async function handleRequestUserWalletActionModeChange(request) {
  const { userId, newMode, reason } = request.params || {};
  if (!userId || !newMode || !reason) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'userId, newMode and reason are required');
  }
  if (!USER_WALLET_ACTION_MODES.has(newMode)) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Invalid wallet action mode');
  }

  const targetUser = await new Parse.Query(Parse.User).get(userId, { useMasterKey: true });
  const oldMode = normalizeWalletActionMode(targetUser.get('walletActionModeOverride'));
  if (oldMode === newMode) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'Mode is already set for this user');
  }

  const FourEyesRequest = Parse.Object.extend('FourEyesRequest');
  const fourEyesReq = new FourEyesRequest();
  fourEyesReq.set('requestType', 'user_wallet_action_mode_change');
  fourEyesReq.set('requesterId', request.user.id);
  fourEyesReq.set('requesterRole', request.user.get('role'));
  fourEyesReq.set('requesterEmail', request.user.get('email'));
  fourEyesReq.set('status', 'pending');
  fourEyesReq.set('expiresAt', new Date(Date.now() + 7 * 24 * 60 * 60 * 1000));
  fourEyesReq.set('metadata', {
    targetUserId: userId,
    targetUserEmail: targetUser.get('email') || null,
    oldMode: oldMode || null,
    newMode,
    reason,
    isCritical: true,
  });
  await fourEyesReq.save(null, { useMasterKey: true });

  return {
    success: true,
    requiresApproval: true,
    fourEyesRequestId: fourEyesReq.id,
    message: `User wallet action mode change requires 4-eyes approval. Request ID: ${fourEyesReq.id}`,
  };
}

module.exports = {
  handleRequestUserWalletActionModeChange,
};
