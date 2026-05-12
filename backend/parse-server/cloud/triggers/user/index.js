// ============================================================================
// Parse Cloud Code — _User triggers (beforeSave / afterSave / beforeDelete)
// Einstieg: triggers/user/index.js
// ============================================================================

'use strict';

const { userBeforeSave } = require('./userTriggerBeforeSave');
const { userAfterSave } = require('./userTriggerAfterSave');
const { userBeforeDelete } = require('./userTriggerBeforeDelete');

Parse.Cloud.beforeSave(Parse.User, userBeforeSave);
Parse.Cloud.afterSave(Parse.User, userAfterSave);
Parse.Cloud.beforeDelete(Parse.User, userBeforeDelete);
