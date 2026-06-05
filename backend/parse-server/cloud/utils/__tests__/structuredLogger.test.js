'use strict';

const {
  audit,
  setAuditLoggerSinks,
  resetAuditLogger,
} = require('../structuredLogger');

function captureSinks() {
  const captured = { info: [], warn: [], error: [] };
  setAuditLoggerSinks({
    info: (line) => captured.info.push(line),
    warn: (line) => captured.warn.push(line),
    error: (line) => captured.error.push(line),
  });
  return captured;
}

afterEach(() => {
  resetAuditLogger();
});

describe('structuredLogger', () => {
  it('writes a JSON line with ts, level, event and merged fields', () => {
    const captured = captureSinks();

    audit.info('settlement.book', {
      tradeId: 't1',
      investmentId: 'i1',
      businessCaseId: 'BC-1',
      amount: 123.45,
      message: 'booked',
    });

    expect(captured.info).toHaveLength(1);
    const parsed = JSON.parse(captured.info[0]);
    expect(parsed).toEqual(
      expect.objectContaining({
        level: 'info',
        event: 'settlement.book',
        tradeId: 't1',
        investmentId: 'i1',
        businessCaseId: 'BC-1',
        amount: 123.45,
        message: 'booked',
      }),
    );
    expect(typeof parsed.ts).toBe('string');
    expect(parsed.ts).toMatch(/^\d{4}-\d{2}-\d{2}T/);
  });

  it('routes warn / error to their respective sinks', () => {
    const captured = captureSinks();

    audit.warn('settlement.gap', { gap: 0.5 });
    audit.error('settlement.failure', { error: new Error('boom') });

    expect(captured.warn).toHaveLength(1);
    expect(captured.error).toHaveLength(1);
    expect(JSON.parse(captured.warn[0])).toEqual(
      expect.objectContaining({ level: 'warn', event: 'settlement.gap', gap: 0.5 }),
    );
    const errorLine = JSON.parse(captured.error[0]);
    expect(errorLine).toEqual(
      expect.objectContaining({ level: 'error', event: 'settlement.failure', error: 'boom' }),
    );
  });

  it('redacts sensitive keys (password, sessionToken, masterKey, …)', () => {
    const captured = captureSinks();

    audit.info('user.login', {
      userId: 'u1',
      password: 'must-not-leak',
      sessionToken: 'must-not-leak',
      masterKey: 'must-not-leak',
      nested: { accessToken: 'must-not-leak', keep: 'ok' },
    });

    const parsed = JSON.parse(captured.info[0]);
    expect(parsed.userId).toBe('u1');
    expect(parsed.password).toBeUndefined();
    expect(parsed.sessionToken).toBeUndefined();
    expect(parsed.masterKey).toBeUndefined();
    expect(parsed.nested).toEqual({ keep: 'ok' });
  });

  it('handles cyclic objects by marking them as [Circular]', () => {
    const captured = captureSinks();

    const cyclic = { a: 1 };
    cyclic.self = cyclic;

    audit.info('cyclic.test', { cyclic });
    expect(captured.info).toHaveLength(1);
    const parsed = JSON.parse(captured.info[0]);
    expect(parsed.event).toBe('cyclic.test');
    expect(parsed.cyclic).toEqual({ a: 1, self: '[Circular]' });
  });

  it('uses fallback event name when caller passes invalid event', () => {
    const captured = captureSinks();

    audit.info('', { foo: 'bar' });
    audit.info(undefined, { foo: 'bar' });

    expect(captured.info).toHaveLength(2);
    expect(JSON.parse(captured.info[0]).event).toBe('unknown');
    expect(JSON.parse(captured.info[1]).event).toBe('unknown');
  });
});
