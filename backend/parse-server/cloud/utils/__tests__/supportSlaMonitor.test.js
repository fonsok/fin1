'use strict';

const {
  evaluateSlaBreach,
  buildViolationReason,
  SLA_HOURS,
} = require('../supportSlaMonitor');

describe('supportSlaMonitor', () => {
  it('SLA_HOURS matches urgent 1h first / 4h resolution', () => {
    expect(SLA_HOURS.urgent.first).toBe(1);
    expect(SLA_HOURS.urgent.resolution).toBe(4);
  });

  it('evaluateSlaBreach detects first-response breach', () => {
    const now = new Date('2026-05-16T12:00:00Z');
    const firstResponseTarget = new Date('2026-05-16T10:00:00Z');
    const resolutionTarget = new Date('2026-05-16T20:00:00Z');

    const result = evaluateSlaBreach({
      status: 'open',
      now,
      firstResponseTarget,
      resolutionTarget,
      hasFirstResponse: false,
    });

    expect(result.breached).toBe(true);
    expect(result.firstBreached).toBe(true);
    expect(result.resolutionBreached).toBe(false);
  });

  it('evaluateSlaBreach pauses while waiting for customer', () => {
    const now = new Date('2026-05-16T12:00:00Z');
    const result = evaluateSlaBreach({
      status: 'waiting_for_customer',
      now,
      firstResponseTarget: new Date('2026-05-16T08:00:00Z'),
      resolutionTarget: new Date('2026-05-16T09:00:00Z'),
      hasFirstResponse: false,
    });

    expect(result.breached).toBe(false);
    expect(result.paused).toBe(true);
  });

  it('buildViolationReason combines both breaches', () => {
    const reason = buildViolationReason({ firstBreached: true, resolutionBreached: true });
    expect(reason).toMatch(/Erste Antwort/);
    expect(reason).toMatch(/Lösung/);
  });
});
