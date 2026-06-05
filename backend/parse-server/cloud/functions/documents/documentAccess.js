'use strict';

/**
 * Session user may read Document rows they own (trader/investor userId variants).
 */
function documentOwnedByUser(doc, user) {
  if (!doc || !user) return false;
  const docUserId = String(doc.get('userId') || '').trim();
  if (!docUserId) return false;
  if (docUserId === user.id) return true;

  const rawEmail = String(user.get('email') || '').toLowerCase();
  const rawUsername = String(user.get('username') || '').toLowerCase();
  const emailLocalPart = rawEmail.includes('@') ? rawEmail.split('@')[0] : '';
  const stableId = user.get('stableId');
  const candidates = new Set(
    [
      rawEmail,
      rawUsername,
      emailLocalPart,
      stableId || '',
      rawEmail ? `user:${rawEmail}` : '',
      rawUsername ? `user:${rawUsername}` : '',
    ].filter(Boolean).map((v) => String(v).toLowerCase()),
  );

  return candidates.has(docUserId.toLowerCase());
}

module.exports = {
  documentOwnedByUser,
};
