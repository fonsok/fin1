/**
 * Portal login copy — single source (Admin + Finance Admin share this page and AuthContext).
 * Dev passwords & full account table: Documentation/DEV_LOGIN_ACCOUNTS.md (not committed secrets for prod).
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
  'Passwörter (Dev): siehe Documentation/DEV_LOGIN_ACCOUNTS.md — Finance Admin Standard: Finance2026! (create-business-admin.sh).';
