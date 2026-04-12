'use strict';

const { registerPendingApprovalFunctions } = require('./fourEyes/pending');
const { registerWithdrawApprovalFunctions } = require('./fourEyes/withdraw');
const { registerApproveApprovalFunctions } = require('./fourEyes/approve');
const { registerRejectApprovalFunctions } = require('./fourEyes/reject');

registerPendingApprovalFunctions();
registerWithdrawApprovalFunctions();
registerApproveApprovalFunctions();
registerRejectApprovalFunctions();
