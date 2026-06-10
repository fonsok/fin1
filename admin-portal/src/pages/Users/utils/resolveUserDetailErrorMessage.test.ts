import { describe, expect, it } from 'vitest';
import { resolveUserDetailErrorMessage } from './resolveUserDetailErrorMessage';

describe('resolveUserDetailErrorMessage', () => {
  it('returns message when userId is missing', () => {
    expect(resolveUserDetailErrorMessage(null, undefined)).toBe('Keine Benutzer-ID in der URL.');
  });

  it('treats Parse 101 as not found', () => {
    const err = new Error('Object not found. — code 101');
    expect(resolveUserDetailErrorMessage(err, 'abc123')).toBe('Benutzer nicht gefunden (abc123).');
  });

  it('shows API error text for load failures', () => {
    const err = new Error('loadConfig is not a function');
    expect(resolveUserDetailErrorMessage(err, 'trader-1')).toBe(
      'Benutzerdetails konnten nicht geladen werden: loadConfig is not a function',
    );
  });

  it('falls back to not found when there is no error object', () => {
    expect(resolveUserDetailErrorMessage(null, 'inv-9')).toBe('Benutzer nicht gefunden (inv-9).');
  });
});
