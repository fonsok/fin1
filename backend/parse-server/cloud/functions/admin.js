// ============================================================================
// Parse Cloud Code – Admin Functions (modular)
// ============================================================================
//
// Admin-Funktionen mit rollenbasierter Zugriffskontrolle.
// Dokumentation: Documentation/FIN1_APP_DOCS/09_ADMIN_ROLES_SEPARATION.md
//
// Rollen: admin, business_admin, security_officer, compliance, customer_service
// Aufteilung in Module unter functions/admin/ für bessere Wartbarkeit.
//
// ============================================================================

'use strict';

// Helpers first (getRequesterIdString, getRoleDescription)
require('./admin/helpers');

// Dashboard & User Management
require('./admin/dashboard');
require('./admin/users');
require('./admin/adminCustomerViewAudit');
require('./admin/compliance');
require('./admin/fourEyes');
require('./admin/financial');
require('./admin/security');
require('./admin/permissions');
require('./admin/usersAdminAccounts');
require('./admin/devHelpers');
require('./admin/system');
require('./admin/opsHealth');
require('./admin/reports');
require('./admin/onboarding');
require('./admin/companyKyb');
require('./admin/ledgerOpeningSnapshot');
