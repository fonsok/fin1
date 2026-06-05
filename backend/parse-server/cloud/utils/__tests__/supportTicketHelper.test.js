'use strict';

const {
  normalizeStatusForStorage,
  normalizeStatusForClient,
  isValidStatus,
  mapMessagesToComments,
  mapTicketForClient,
} = require('../supportTicketHelper');

describe('supportTicketHelper', () => {
  it('normalizeStatusForStorage maps waiting alias', () => {
    expect(normalizeStatusForStorage('waiting')).toBe('waiting_for_customer');
    expect(normalizeStatusForStorage('escalated')).toBe('escalated');
  });

  it('normalizeStatusForClient maps waiting_for_customer to waiting', () => {
    expect(normalizeStatusForClient('waiting_for_customer')).toBe('waiting');
    expect(normalizeStatusForClient('escalated')).toBe('escalated');
  });

  it('isValidStatus accepts canonical and alias statuses', () => {
    expect(isValidStatus('waiting')).toBe(true);
    expect(isValidStatus('bogus')).toBe(false);
  });

  it('mapMessagesToComments maps TicketMessage fields', () => {
    const comments = mapMessagesToComments([
      {
        objectId: 'm1',
        message: 'Hello',
        senderId: 'u1',
        senderName: 'Agent',
        isInternal: true,
        createdAt: '2026-01-01T00:00:00.000Z',
      },
    ]);
    expect(comments.length).toBe(1);
    expect(comments[0].content).toBe('Hello');
    expect(comments[0].createdBy).toBe('u1');
    expect(comments[0].createdByName).toBe('Agent');
    expect(comments[0].isInternal).toBe(true);
  });

  it('mapTicketForClient exposes comments and client status', () => {
    const mapped = mapTicketForClient({
      status: 'waiting_for_customer',
      messages: [{ objectId: 'm1', message: 'x', senderId: 'u1', isInternal: false, createdAt: 't' }],
    });
    expect(mapped.status).toBe('waiting');
    expect(mapped.comments.length).toBe(1);
  });
});
