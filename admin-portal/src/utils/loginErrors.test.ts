import { describe, it, expect } from 'vitest';
import { loginFailureRawMessage, mapLoginErrorMessage } from './loginErrors';

describe('loginFailureRawMessage', () => {
  it('reads Error.message', () => {
    expect(loginFailureRawMessage(new Error('x'))).toBe('x');
  });

  it('accepts non-empty string', () => {
    expect(loginFailureRawMessage('y')).toBe('y');
  });

  it('falls back for unknown', () => {
    expect(loginFailureRawMessage(null)).toBe('Anmeldung fehlgeschlagen');
  });
});

describe('mapLoginErrorMessage', () => {
  it('maps Parse lockout', () => {
    expect(
      mapLoginErrorMessage(
        'Your account is locked due to multiple failed login attempts. Please try again after 5 minute(s)',
      ),
    ).toContain('Fehlversuche');
  });

  it('maps invalid credentials', () => {
    expect(mapLoginErrorMessage('Invalid username/password.')).toBe(
      'E-Mail oder Passwort ist nicht korrekt.',
    );
  });

  it('preserves short German backend messages', () => {
    expect(mapLoginErrorMessage('Ungültiger Code')).toBe('Ungültiger Code');
  });

  it('maps English 2FA-style errors', () => {
    expect(mapLoginErrorMessage('Invalid verification code')).toBe(
      'Sicherheitscode ungültig oder abgelaufen.',
    );
  });

  it('maps network failures', () => {
    expect(mapLoginErrorMessage('Failed to fetch')).toBe('Keine Verbindung zum Server. Bitte Netzwerk prüfen.');
  });

  it('uses generic fallback for unknown English', () => {
    expect(mapLoginErrorMessage('Something weird')).toBe('Anmeldung fehlgeschlagen. Bitte erneut versuchen.');
  });
});
