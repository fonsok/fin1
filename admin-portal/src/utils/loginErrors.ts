/**
 * Maps Parse / Admin-Portal auth error strings to short German UX copy.
 * Parse Server often returns English (e.g. AccountLockout, REST errors).
 */

/** Normalize thrown values from `login()` / `fetch` before mapping. */
export function loginFailureRawMessage(err: unknown): string {
  if (err instanceof Error) return err.message;
  if (typeof err === 'string' && err.trim().length > 0) return err;
  return 'Anmeldung fehlgeschlagen';
}

/**
 * Short user-facing message so failed attempts show a clear cause
 * (wrong credentials vs lockout vs network vs 2FA).
 */
export function mapLoginErrorMessage(rawMessage: string): string {
  const trimmed = rawMessage.trim();
  const msg = trimmed.toLowerCase();

  if (
    msg.includes('locked due to multiple failed login attempts') ||
    msg.includes('account is locked') ||
    msg.includes('try again after')
  ) {
    return 'Zu viele Fehlversuche — Konto kurz gesperrt. Bitte in einigen Minuten erneut versuchen.';
  }

  if (
    msg.includes('invalid username/password') ||
    msg.includes('invalid credentials') ||
    msg.includes('code 101')
  ) {
    return 'E-Mail oder Passwort ist nicht korrekt.';
  }

  if (/[äöüßÄÖÜ]/.test(trimmed) && trimmed.length <= 220) {
    return trimmed;
  }

  if (
    msg.includes('invalid verification') ||
    msg.includes('verification code') ||
    msg.includes('two-factor') ||
    msg.includes('two factor') ||
    msg.includes('2fa') ||
    msg.includes('totp') ||
    (msg.includes('invalid') && msg.includes('code') && !msg.includes('username'))
  ) {
    return 'Sicherheitscode ungültig oder abgelaufen.';
  }

  if (
    (msg.includes('account') && (msg.includes('disabled') || msg.includes('deactivated'))) ||
    msg.includes('user is disabled')
  ) {
    return 'Dieses Konto ist deaktiviert.';
  }

  if (
    msg.includes('invalid session') ||
    msg.includes('session token') ||
    msg.includes('code 209') ||
    msg.includes('must be logged in')
  ) {
    return 'Sitzung ungültig. Bitte erneut anmelden.';
  }

  if (
    msg.includes('failed to fetch') ||
    msg.includes('networkerror') ||
    msg.includes('load failed') ||
    msg.includes('netzwerk') ||
    msg.includes('network')
  ) {
    return 'Keine Verbindung zum Server. Bitte Netzwerk prüfen.';
  }

  if (msg.startsWith('http ') && (msg.includes(' 5') || msg.includes(' 502') || msg.includes(' 503'))) {
    return 'Server vorübergehend nicht erreichbar. Bitte später erneut versuchen.';
  }

  if (msg.startsWith('http ') && msg.includes(' 4')) {
    return 'Anfrage wurde abgelehnt. Bitte erneut versuchen.';
  }

  return 'Anmeldung fehlgeschlagen. Bitte erneut versuchen.';
}
