'use strict';

/**
 * @returns {{ backup: object, documents: unknown[] }}
 */
function resolveBackupFromRequest(request) {
  let backup = request.params.backup;
  if (!backup && typeof request.params.backupJson === 'string') {
    try {
      backup = JSON.parse(request.params.backupJson);
    } catch (e) {
      throw new Parse.Error(Parse.Error.INVALID_JSON, 'backupJson is not valid JSON');
    }
  }

  if (!backup || typeof backup !== 'object') {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'backup (object) or backupJson (string) is required');
  }

  const documents = Array.isArray(backup.documents) ? backup.documents : null;
  if (!documents || documents.length === 0) {
    throw new Parse.Error(Parse.Error.INVALID_VALUE, 'backup.documents must be a non-empty array');
  }

  return { backup, documents };
}

module.exports = {
  resolveBackupFromRequest,
};
