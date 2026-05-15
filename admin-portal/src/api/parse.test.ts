import { describe, it, expect, vi, beforeEach } from 'vitest';
import {
  login,
  logout,
  getCurrentUser,
  validateSession,
  cloudFunction,
  verify2FA,
  setup2FA,
  enable2FA,
} from './parse';

// Mock fetch is set up in test/setup.ts

/** Minimal `Response` compatible with `parseRequest` (uses `response.text()`, not `json()`). */
function mockParseFetchResponse(
  body: unknown,
  options: { ok?: boolean; status?: number } = {},
): Response {
  const ok = options.ok !== false;
  const status = options.status ?? (ok ? 200 : 400);
  const rawText =
    body === undefined || body === null
      ? ''
      : typeof body === 'string'
        ? body
        : JSON.stringify(body);

  return {
    ok,
    status,
    text: () => Promise.resolve(rawText),
    json: () => Promise.resolve(rawText ? (JSON.parse(rawText) as unknown) : {}),
  } as unknown as Response;
}

describe('Parse API', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    localStorage.clear();
  });

  describe('login', () => {
    it('calls login endpoint with credentials', async () => {
      const mockUser = {
        objectId: 'user123',
        email: 'test@test.com',
        username: 'test@test.com',
        role: 'admin',
        sessionToken: 'session123',
      };

      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse(mockUser));

      const result = await login('test@test.com', 'password123');

      expect(global.fetch).toHaveBeenCalledTimes(1);

      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/login',
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'X-Parse-Application-Id': 'fin1-app-id',
            'Content-Type': 'application/json',
          }),
          body: JSON.stringify({
            username: 'test@test.com',
            password: 'password123',
          }),
        })
      );
      expect(result).toEqual(mockUser);
    });

    it('hydrates role from /users/me when /login omits role', async () => {
      vi.mocked(global.fetch)
        .mockResolvedValueOnce(
          mockParseFetchResponse({
            objectId: 'user123',
            email: 'csr@test.com',
            username: 'csr@test.com',
            sessionToken: 'session123',
          }),
        )
        .mockResolvedValueOnce(
          mockParseFetchResponse({
            objectId: 'user123',
            email: 'csr@test.com',
            username: 'csr@test.com',
            role: 'customer_service',
            csrSubRole: 'level_2',
          }),
        );

      const result = await login('csr@test.com', 'pw');

      expect(global.fetch).toHaveBeenCalledTimes(2);
      expect(global.fetch).toHaveBeenNthCalledWith(
        2,
        '/parse/users/me',
        expect.objectContaining({
          method: 'GET',
          headers: expect.objectContaining({
            'X-Parse-Session-Token': 'session123',
          }),
        }),
      );
      expect(result.role).toBe('customer_service');
      expect(result.csrSubRole).toBe('level_2');
    });

    it('normalizes email to lowercase and trims', async () => {
      vi.mocked(global.fetch).mockResolvedValueOnce(
        mockParseFetchResponse({
          sessionToken: 'token',
          objectId: 'o1',
          email: 'test@test.com',
          username: 'test@test.com',
          role: 'admin',
        }),
      );

      await login('  TEST@Test.COM  ', 'password');

      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/login',
        expect.objectContaining({
          body: JSON.stringify({
            username: 'test@test.com',
            password: 'password',
          }),
        })
      );
    });

    it('stores session after successful login', async () => {
      const mockUser = {
        objectId: 'user123',
        email: 'test@test.com',
        username: 'test@test.com',
        role: 'admin',
        sessionToken: 'session123',
      };

      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse(mockUser));

      await login('test@test.com', 'password');

      expect(localStorage.setItem).toHaveBeenCalledWith('parse_session', 'session123');
      expect(localStorage.setItem).toHaveBeenCalledWith('parse_user', JSON.stringify(mockUser));
    });

    it('throws error on failed login', async () => {
      vi.mocked(global.fetch).mockResolvedValueOnce(
        mockParseFetchResponse({ error: 'Invalid credentials' }, { ok: false, status: 401 }),
      );

      await expect(login('test@test.com', 'wrong')).rejects.toThrow('Invalid credentials');
    });
  });

  describe('logout', () => {
    it('calls logout endpoint and clears session', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse({}));

      await logout();

      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/logout',
        expect.objectContaining({
          method: 'POST',
          headers: expect.objectContaining({
            'X-Parse-Session-Token': 'session123',
          }),
        })
      );
      expect(localStorage.removeItem).toHaveBeenCalledWith('parse_session');
      expect(localStorage.removeItem).toHaveBeenCalledWith('parse_user');
    });

    it('clears session even if logout request fails', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockRejectedValueOnce(new Error('Network error'));

      await logout();

      expect(localStorage.removeItem).toHaveBeenCalledWith('parse_session');
    });

    it('handles logout when no session exists', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce(null);

      await logout();

      expect(global.fetch).not.toHaveBeenCalled();
      expect(localStorage.removeItem).toHaveBeenCalled();
    });
  });

  describe('getCurrentUser', () => {
    it('returns null when no user in storage', () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce(null);
      expect(getCurrentUser()).toBeNull();
    });

    it('returns parsed user from storage', () => {
      const user = { objectId: 'user123', email: 'test@test.com' };
      vi.mocked(localStorage.getItem).mockReturnValueOnce(JSON.stringify(user));

      expect(getCurrentUser()).toEqual(user);
    });

    it('returns null for invalid JSON', () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('invalid-json');
      expect(getCurrentUser()).toBeNull();
    });
  });

  describe('validateSession', () => {
    it('returns null when no session token', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce(null);

      const result = await validateSession();

      expect(result).toBeNull();
      expect(global.fetch).not.toHaveBeenCalled();
    });

    it('validates session and returns user', async () => {
      const mockUser = { objectId: 'user123', email: 'test@test.com' };
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse(mockUser));

      const result = await validateSession();

      expect(result).toEqual(mockUser);
      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/users/me',
        expect.objectContaining({
          headers: expect.objectContaining({
            'X-Parse-Session-Token': 'session123',
          }),
        })
      );
    });

    it('clears session on validation failure', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('invalid-session');
      vi.mocked(global.fetch).mockResolvedValueOnce(
        mockParseFetchResponse({ error: 'Invalid session' }, { ok: false, status: 401 }),
      );

      const result = await validateSession();

      expect(result).toBeNull();
      expect(localStorage.removeItem).toHaveBeenCalledWith('parse_session');
    });
  });

  describe('cloudFunction', () => {
    it('calls cloud function endpoint', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse({ result: { data: 'test' } }));

      const result = await cloudFunction<{ data: string }>('testFunction', { param: 'value' });

      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/functions/testFunction',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({ param: 'value' }),
        }),
      );
      expect(result).toEqual({ data: 'test' });
    });

    it('sends listSortOrder alongside sortOrder for server-side sort direction', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse({ result: { items: [] } }));

      await cloudFunction('getTickets', { sortBy: 'createdAt', sortOrder: 'asc' });

      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/functions/getTickets',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({
            sortBy: 'createdAt',
            sortOrder: 'asc',
            listSortOrder: 'asc',
          }),
        }),
      );
    });

    it('does not rewrite numeric sortOrder when sortBy is absent (FAQ CRUD)', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse({ result: { objectId: 'x' } }));

      await cloudFunction('createFAQ', {
        question: 'Q',
        answer: 'A',
        categoryId: 'cat1',
        sortOrder: 100,
      });

      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/functions/createFAQ',
        expect.objectContaining({
          method: 'POST',
          body: JSON.stringify({
            question: 'Q',
            answer: 'A',
            categoryId: 'cat1',
            sortOrder: 100,
          }),
        }),
      );
    });

    it('handles cloud function without params', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse({ result: [] }));

      await cloudFunction('listItems');

      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/functions/listItems',
        expect.objectContaining({
          body: JSON.stringify({}),
        })
      );
    });
  });

  describe('2FA functions', () => {
    it('verify2FA calls correct endpoint', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(mockParseFetchResponse({ verified: true }));

      const result = await verify2FA('123456');

      expect(global.fetch).toHaveBeenCalledWith(
        '/parse/functions/verify2FACode',
        expect.objectContaining({
          body: JSON.stringify({ code: '123456' }),
        })
      );
      expect(result).toEqual({ verified: true });
    });

    it('setup2FA returns secret and QR code', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(
        mockParseFetchResponse({
          secret: 'ABCD1234',
          qrCodeUrl: 'data:image/png;base64,...',
        }),
      );

      const result = await setup2FA();

      expect(result.secret).toBe('ABCD1234');
      expect(result.qrCodeUrl).toBeDefined();
    });

    it('enable2FA returns backup codes', async () => {
      vi.mocked(localStorage.getItem).mockReturnValueOnce('session123');
      vi.mocked(global.fetch).mockResolvedValueOnce(
        mockParseFetchResponse({
          success: true,
          backupCodes: ['code1', 'code2', 'code3'],
        }),
      );

      const result = await enable2FA('123456');

      expect(result.success).toBe(true);
      expect(result.backupCodes).toHaveLength(3);
    });
  });
});
