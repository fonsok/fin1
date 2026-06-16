'use strict';

/**
 * Parse aggregate rows expose Mongo `$group._id` as `objectId`.
 * Keep this mapping in one place to avoid accidental `_id`/`objectId` mixups.
 */

/** Raw `$group._id` payload (scalar or compound object). */
function readAggregateGroupPayload(row) {
  if (!row || typeof row !== 'object') return null;
  if (row.objectId != null) return row.objectId;
  if (row._id != null) return row._id;
  return null;
}

/** Scalar group key (e.g. tradeId string). */
function readAggregateGroupKey(row) {
  const payload = readAggregateGroupPayload(row);
  return payload == null ? '' : String(payload);
}

module.exports = {
  readAggregateGroupPayload,
  readAggregateGroupKey,
};
