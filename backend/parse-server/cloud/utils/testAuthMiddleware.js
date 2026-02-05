// ============================================================================
// Parse Cloud Code
// utils/testAuthMiddleware.js - Test Authentication Middleware
// ============================================================================
//
// Middleware for handling simulated session tokens in development/test mode.
// This allows the iOS app to use test users without real Parse authentication.
//
// Token Format: r:base64(userId:role:timestamp)
//
// IMPORTANT: This is for DEVELOPMENT/TESTING only!
// In production, use real Parse authentication.
//
// ============================================================================

'use strict';

/**
 * Decode a simulated session token and return user info.
 * @param {string} token - The simulated token (format: r:base64(userId:role:timestamp))
 * @returns {object|null} User info or null if invalid
 */
function decodeSimulatedToken(token) {
  if (!token || !token.startsWith('r:')) {
    return null;
  }

  try {
    const base64Part = token.substring(2);
    const decoded = Buffer.from(base64Part, 'base64').toString('utf8');
    const [userId, role, timestamp] = decoded.split(':');

    if (!userId || !role) {
      return null;
    }

    // Check if token is expired (24 hours)
    const tokenTime = parseFloat(timestamp);
    const now = Date.now() / 1000;
    if (now - tokenTime > 24 * 60 * 60) {
      console.log('⚠️ Simulated token expired');
      return null;
    }

    return { userId, role };
  } catch (error) {
    console.error('Failed to decode simulated token:', error);
    return null;
  }
}

/**
 * Find or create a simulated user for testing.
 * @param {string} userId - The user ID from the token
 * @param {string} role - The user role
 * @returns {Promise<Parse.User|null>} The user object or null
 */
async function findOrCreateTestUser(userId, role) {
  // First, try to find an existing user with this role
  const userQuery = new Parse.Query(Parse.User);
  userQuery.equalTo('role', role);
  userQuery.equalTo('status', 'active');

  let user = await userQuery.first({ useMasterKey: true });

  if (user) {
    return user;
  }

  // If no user exists, create a test user
  // This should only happen in development
  if (process.env.NODE_ENV !== 'production') {
    console.log(`📝 Creating test user for role: ${role}`);

    user = new Parse.User();
    user.set('username', `test_${role}_${Date.now()}`);
    user.set('email', `test_${role}@fin1.dev`);
    user.set('password', `TestPassword123!`);
    user.set('role', role);
    user.set('status', 'active');
    user.set('customerId', `TEST-${role.toUpperCase()}-${Date.now()}`);

    await user.signUp(null, { useMasterKey: true });
    return user;
  }

  return null;
}

/**
 * Check if we're in development/test mode.
 * @returns {boolean} True if in development mode
 */
function isDevelopmentMode() {
  return process.env.NODE_ENV !== 'production';
}

/**
 * Middleware to inject user from simulated token or development mode.
 * Use this in Cloud Functions that need authentication.
 *
 * In development mode without a real session token, this will
 * automatically inject an admin user for testing purposes.
 *
 * @param {Parse.Cloud.FunctionRequest} request - The Cloud Function request
 * @returns {Promise<Parse.User|null>} The authenticated user or null
 */
async function resolveUserFromSimulatedToken(request) {
  // If user is already set (real Parse session), return early
  if (request.user) {
    return request.user;
  }

  // Check for simulated token in headers
  // Parse SDK sends session token in X-Parse-Session-Token header
  const sessionToken = request.headers?.['x-parse-session-token'];

  if (sessionToken && sessionToken.startsWith('r:')) {
    // Decode the simulated token
    const tokenInfo = decodeSimulatedToken(sessionToken);
    if (tokenInfo) {
      console.log(`🔑 Simulated token detected: role=${tokenInfo.role}, userId=${tokenInfo.userId}`);

      // Find or create a test user
      const user = await findOrCreateTestUser(tokenInfo.userId, tokenInfo.role);

      if (user) {
        request.user = user;
        console.log(`✅ Injected test user: ${user.get('email')} (${user.get('role')})`);
        return user;
      }
    }
  }

  // In development mode, if no user and no valid token, inject admin user
  if (isDevelopmentMode() && !request.user) {
    console.log('🔧 Development mode: Auto-injecting admin user for unauthenticated request');

    const user = await findOrCreateTestUser('dev-admin', 'admin');
    if (user) {
      request.user = user;
      console.log(`✅ Development mode: Injected admin user: ${user.get('email')}`);
      return user;
    }
  }

  return null;
}

/**
 * Enhanced requirePermission that handles simulated tokens.
 * Use this instead of the standard requirePermission for functions
 * that need to support test authentication.
 *
 * @param {Parse.Cloud.FunctionRequest} request - The Cloud Function request
 * @param {string} permission - The required permission
 */
async function requirePermissionWithTestAuth(request, permission) {
  // Try to resolve user from simulated token first
  await resolveUserFromSimulatedToken(request);

  // Now use the standard permission check
  const { requirePermission } = require('./permissions');
  return requirePermission(request, permission);
}

/**
 * Enhanced requireAdminRole that handles simulated tokens.
 *
 * @param {Parse.Cloud.FunctionRequest} request - The Cloud Function request
 */
async function requireAdminRoleWithTestAuth(request) {
  // Try to resolve user from simulated token first
  await resolveUserFromSimulatedToken(request);

  // Now use the standard admin role check
  const { requireAdminRole } = require('./permissions');
  return requireAdminRole(request);
}

module.exports = {
  decodeSimulatedToken,
  findOrCreateTestUser,
  resolveUserFromSimulatedToken,
  requirePermissionWithTestAuth,
  requireAdminRoleWithTestAuth,
};
