// Direct Parse REST API calls (no SDK needed)

const PARSE_APP_ID = import.meta.env.VITE_PARSE_APP_ID || 'fin1-app-id';
const PARSE_SERVER_URL = import.meta.env.VITE_PARSE_SERVER_URL || '/parse';

// Session storage key
const SESSION_KEY = 'parse_session';
const USER_KEY = 'parse_user';

/**
 * Initialize Parse (just logs config)
 */
export function initializeParse(): void {
  console.log('Parse API initialized:', {
    appId: PARSE_APP_ID,
    serverURL: PARSE_SERVER_URL,
  });
}

/**
 * Make a Parse API request
 */
async function parseRequest<T>(
  method: string,
  endpoint: string,
  data?: Record<string, unknown>,
  sessionToken?: string
): Promise<T> {
  const headers: Record<string, string> = {
    'X-Parse-Application-Id': PARSE_APP_ID,
    'Content-Type': 'application/json',
  };

  if (sessionToken) {
    headers['X-Parse-Session-Token'] = sessionToken;
  }

  const url = `${PARSE_SERVER_URL}${endpoint}`;
  let response: Response;
  try {
    response = await fetch(url, {
      method,
      headers,
      body: data ? JSON.stringify(data) : undefined,
      credentials: 'same-origin',
    });
  } catch (err) {
    const hint =
      err instanceof TypeError
        ? ' (Netzwerk: Server erreichbar? HTTPS/Zertifikat? Falsche VITE_PARSE_SERVER_URL im Build?)'
        : '';
    throw new Error(`${err instanceof Error ? err.message : String(err)}${hint}`);
  }

  const rawText = await response.text();
  let result: Record<string, unknown> = {};
  if (rawText) {
    try {
      result = JSON.parse(rawText) as Record<string, unknown>;
    } catch {
      throw new Error(
        `HTTP ${response.status}: Antwort ist kein JSON (${rawText.slice(0, 200)}${rawText.length > 200 ? '…' : ''})`,
      );
    }
  }

  if (!response.ok) {
    const errVal = result.error;
    let errStr =
      typeof errVal === 'string' && errVal.trim().length > 0
        ? errVal
        : typeof result.message === 'string' && result.message.trim().length > 0
          ? result.message
          : undefined;
    const agg = Array.isArray(result.errors) ? (result.errors as { message?: string; code?: number }[]) : [];
    if (!errStr && agg.length > 0) {
      const first = agg
        .map((e) => (typeof e.message === 'string' ? e.message : ''))
        .filter(Boolean)
        .slice(0, 3);
      if (first.length) {
        errStr = `${agg.length} Teilfehler, z.B.: ${first.join('; ')}`;
      }
    }
    const code =
      typeof result.code === 'number' || typeof result.code === 'string' ? String(result.code) : '';
    const tail = [code && `code ${code}`, !errStr && rawText ? rawText.slice(0, 280) : '']
      .filter(Boolean)
      .join(' — ');
    throw new Error(errStr || tail || `HTTP ${response.status}`);
  }

  return result as T;
}

/**
 * Get stored session token
 */
function getSessionToken(): string | null {
  return localStorage.getItem(SESSION_KEY);
}

/** User fields from Parse `GET /users/me` and from login response (without token). */
export interface ParseSessionUser {
  objectId: string;
  email: string;
  username: string;
  role: string;
  firstName?: string;
  lastName?: string;
  csrSubRole?: string;
  csrRole?: string;
  twoFactorEnabled?: boolean;
  twoFactorEnabledAt?: string;
  twoFactorBackupCodes?: unknown[];
}

export type ParseLoginResult = ParseSessionUser & { sessionToken: string };

/**
 * Store session
 */
function storeSession(sessionToken: string, user: ParseSessionUser | ParseLoginResult): void {
  localStorage.setItem(SESSION_KEY, sessionToken);
  localStorage.setItem(USER_KEY, JSON.stringify(user));
}

/**
 * Clear session
 */
function clearSession(): void {
  localStorage.removeItem(SESSION_KEY);
  localStorage.removeItem(USER_KEY);
}

/**
 * Get current user from storage
 */
export function getCurrentUser(): ParseSessionUser | null {
  const userStr = localStorage.getItem(USER_KEY);
  if (!userStr) return null;

  try {
    return JSON.parse(userStr) as ParseSessionUser;
  } catch {
    return null;
  }
}

/**
 * Validate current session
 */
export async function validateSession(): Promise<ParseSessionUser | null> {
  const sessionToken = getSessionToken();
  if (!sessionToken) return null;

  try {
    const user = await parseRequest<ParseSessionUser>('GET', '/users/me', undefined, sessionToken);
    storeSession(sessionToken, user);
    return user;
  } catch (error) {
    console.error('Session validation failed:', error);
    clearSession();
    return null;
  }
}

/**
 * Login with email and password
 */
export async function login(email: string, password: string): Promise<ParseLoginResult> {
  const result = await parseRequest<ParseLoginResult>('POST', '/login', {
    username: email.toLowerCase().trim(),
    password,
  });

  storeSession(result.sessionToken, result);
  return result;
}

/**
 * Logout current user
 */
export async function logout(): Promise<void> {
  const sessionToken = getSessionToken();

  if (sessionToken) {
    try {
      await parseRequest('POST', '/logout', undefined, sessionToken);
    } catch (error) {
      console.error('Logout request failed:', error);
    }
  }

  clearSession();
}

/**
 * Verify 2FA code
 */
export async function verify2FA(code: string): Promise<{ verified: boolean }> {
  const sessionToken = getSessionToken();
  return await parseRequest<{ verified: boolean }>(
    'POST',
    '/functions/verify2FACode',
    { code },
    sessionToken || undefined
  );
}

/**
 * Setup 2FA - get QR code
 */
export async function setup2FA(): Promise<{ secret: string; qrCodeUrl: string }> {
  const sessionToken = getSessionToken();
  return await parseRequest<{ secret: string; qrCodeUrl: string }>(
    'POST',
    '/functions/setup2FA',
    {},
    sessionToken || undefined
  );
}

/**
 * Enable 2FA after verification
 */
export async function enable2FA(code: string): Promise<{ success: boolean; backupCodes: string[] }> {
  const sessionToken = getSessionToken();
  return await parseRequest<{ success: boolean; backupCodes: string[] }>(
    'POST',
    '/functions/enable2FA',
    { code },
    sessionToken || undefined
  );
}

/**
 * Call a cloud function
 */
export async function cloudFunction<T>(name: string, params?: Record<string, unknown>): Promise<T> {
  const sessionToken = getSessionToken();
  const raw = params ? { ...params } : {};
  if (typeof raw.sortBy === 'string') {
    raw.sortBy = raw.sortBy.trim();
  }
  // List/pagination cloud functions use sortOrder as direction ('asc' | 'desc'). FAQ/FAQCategory use numeric sortOrder.
  // Only normalize when sortBy is present so createFAQ/updateFAQ/createFAQCategory keep numeric values intact.
  const hasListSortBy = typeof raw.sortBy === 'string' && raw.sortBy.length > 0;
  if (
    hasListSortBy &&
    'sortOrder' in raw &&
    raw.sortOrder !== undefined &&
    raw.sortOrder !== null
  ) {
    const v = raw.sortOrder;
    let norm: 'asc' | 'desc' = 'desc';
    if (v === true || v === 1 || v === '1') norm = 'asc';
    else if (v === false || v === -1 || v === '-1') norm = 'desc';
    else {
      const s = String(v).trim().toLowerCase();
      norm = s === 'asc' || s === 'ascending' ? 'asc' : 'desc';
    }
    raw.sortOrder = norm;
    // Parse Server merges req.query over req.body; listSortOrder stays body-only so asc is not overridden by ?sortOrder=desc
    raw.listSortOrder = norm;
  }
  const body = Object.fromEntries(
    Object.entries(raw).filter(([, value]) => value !== undefined),
  ) as Record<string, unknown>;
  const result = await parseRequest<{ result: T }>(
    'POST',
    `/functions/${name}`,
    body,
    sessionToken || undefined
  );
  return result.result;
}

// Dummy Parse object for compatibility
export const Parse = {
  User: {
    current: getCurrentUser,
  },
};
