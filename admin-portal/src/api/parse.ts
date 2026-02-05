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

  const response = await fetch(`${PARSE_SERVER_URL}${endpoint}`, {
    method,
    headers,
    body: data ? JSON.stringify(data) : undefined,
  });

  const result = await response.json();

  if (!response.ok) {
    throw new Error(result.error || 'Request failed');
  }

  return result;
}

/**
 * Get stored session token
 */
function getSessionToken(): string | null {
  return localStorage.getItem(SESSION_KEY);
}

/**
 * Store session
 */
function storeSession(sessionToken: string, user: any): void {
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
export function getCurrentUser(): any | null {
  const userStr = localStorage.getItem(USER_KEY);
  if (!userStr) return null;

  try {
    return JSON.parse(userStr);
  } catch {
    return null;
  }
}

/**
 * Validate current session
 */
export async function validateSession(): Promise<any | null> {
  const sessionToken = getSessionToken();
  if (!sessionToken) return null;

  try {
    const user = await parseRequest<any>('GET', '/users/me', undefined, sessionToken);
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
export async function login(email: string, password: string): Promise<any> {
  const result = await parseRequest<any>('POST', '/login', {
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
  const result = await parseRequest<{ result: T }>(
    'POST',
    `/functions/${name}`,
    params || {},
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
