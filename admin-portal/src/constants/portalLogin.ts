/**
 * Portal login copy — single source (Admin + Finance Admin share this page and AuthContext).
 * Dev account table (no passwords in UI copy): Documentation/DEV_LOGIN_ACCOUNTS.md.
 */

export const PORTAL_LOGIN_CARD_INTRO =
  'Technischer Admin, Finance Admin, Security, Compliance und CSR: dieselbe Anmeldung, dieselbe URL.';

export const PORTAL_LOGIN_EMAIL_PLACEHOLDER = 'name@fin1.de';

/** Canonical dev/demo mailboxes (align with scripts/create-business-admin.sh and admin seed docs). */
export const PORTAL_DEV_PORTAL_ACCOUNTS = [
  { roleLabel: 'Technischer Admin', parseRole: 'admin', email: 'admin@fin1.de' },
  { roleLabel: 'Finance Admin', parseRole: 'business_admin', email: 'finance@fin1.de' },
] as const;

export const PORTAL_DEV_PASSWORD_SOURCE =
  'Passwörter (Dev): nicht in der UI — siehe Documentation/DEV_LOGIN_ACCOUNTS.md und scripts/create-business-admin.sh (BA_PASSWORD).';
