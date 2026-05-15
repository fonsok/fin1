/**
 * Portal login copy — single source (Admin + Finance Admin share this page and AuthContext).
 * Dev account matrix (emails only here; passwords): Documentation/DEV_PORTAL_LOGIN_SSOT.md.
 */

export const PORTAL_LOGIN_CARD_INTRO =
  'Technischer Admin, Finance Admin, Security, Compliance und CSR: dieselbe Anmeldung, dieselbe URL.';

export const PORTAL_LOGIN_EMAIL_PLACEHOLDER = 'name@fin1.de';

/** Canonical dev/demo mailboxes — align with scripts/create-*-admin.sh default BA_EMAIL values. */
export const PORTAL_DEV_PORTAL_ACCOUNTS = [
  { roleLabel: 'Technischer Admin', parseRole: 'admin', email: 'admin@fin1.de' },
  { roleLabel: 'Finance Admin', parseRole: 'business_admin', email: 'finance@fin1.de' },
  { roleLabel: 'Compliance (Portal)', parseRole: 'compliance', email: 'compliance@fin1.de' },
] as const;

/**
 * CSR portal logins (emails only). Passwords: single array in backend/scripts/create_csr_users.js (CSR_USERS).
 * Keep emails in sync with that file.
 */
export const PORTAL_DEV_CSR_ACCOUNTS = [
  { roleLabel: 'CSR Level 1', email: 'L1@fin1.de' },
  { roleLabel: 'CSR Level 2', email: 'L2@fin1.de' },
  { roleLabel: 'CSR Fraud', email: 'Fraud@fin1.de' },
  { roleLabel: 'CSR Compliance', email: 'Compliance@fin1.de' },
  { roleLabel: 'CSR Tech', email: 'Tech@fin1.de' },
  { roleLabel: 'CSR Lead', email: 'Lead@fin1.de' },
] as const;

export const PORTAL_DEV_PASSWORD_SOURCE =
  'Passwörter (Dev): siehe Documentation/DEV_PORTAL_LOGIN_SSOT.md — Admins: BA_PASSWORD in scripts/.env.server; CSR: backend/scripts/create_csr_users.js (CSR_USERS).';
