-- ============================================================================
-- FIN1 DATABASE SCHEMA
-- 016_seed_data.sql - Initial & Development Seed Data
-- ============================================================================
--
-- WICHTIG: Diese Datei enthält:
--   1. Production-notwendige Daten (Config, Kategorien, Permissions)
--   2. Development/Test-Daten (nur für Entwicklung)
--
-- Die Development-Daten sind in einem Block, der übersprungen werden kann.
--
-- ============================================================================

-- ============================================================================
-- 1. PRODUCTION SEED DATA
-- ============================================================================

-- Diese Daten werden in allen Umgebungen benötigt.

-- ====== CONFIG ITEMS (Financial) ======

INSERT INTO config_items (category_id, key, display_name, data_type, default_value, validation_rules, ui_component, sort_order) VALUES
-- Server (category_id = 1 nach Initial Data)
((SELECT id FROM config_categories WHERE name = 'server'), 'parse_server_path', 'Parse Server Path', 'string', '"/parse"', '{"pattern": "^/.*"}', 'textfield', 1),
((SELECT id FROM config_categories WHERE name = 'server'), 'pdf_service_path', 'PDF Service Path', 'string', '"/api/pdf"', NULL, 'textfield', 2),
((SELECT id FROM config_categories WHERE name = 'server'), 'websocket_enabled', 'WebSocket Enabled', 'boolean', 'true', NULL, 'toggle', 3),

-- Financial
((SELECT id FROM config_categories WHERE name = 'financial'), 'order_fee_rate', 'Order Fee Rate', 'number', '0.005', '{"min": 0, "max": 0.1}', 'slider', 1),
((SELECT id FROM config_categories WHERE name = 'financial'), 'order_fee_minimum', 'Order Fee Minimum (€)', 'number', '5.0', '{"min": 0, "max": 100}', 'textfield', 2),
((SELECT id FROM config_categories WHERE name = 'financial'), 'order_fee_maximum', 'Order Fee Maximum (€)', 'number', '50.0', '{"min": 0, "max": 500}', 'textfield', 3),
((SELECT id FROM config_categories WHERE name = 'financial'), 'exchange_fee_rate', 'Exchange Fee Rate', 'number', '0.001', '{"min": 0, "max": 0.05}', 'slider', 4),
((SELECT id FROM config_categories WHERE name = 'financial'), 'trader_commission_rate', 'Trader Commission Rate', 'number', '0.05', '{"min": 0, "max": 0.5}', 'slider', 5),
((SELECT id FROM config_categories WHERE name = 'financial'), 'platform_service_charge', 'Platform Service Charge', 'number', '0.015', '{"min": 0, "max": 0.1}', 'slider', 6),
((SELECT id FROM config_categories WHERE name = 'financial'), 'minimum_cash_reserve', 'Minimum Cash Reserve (€)', 'number', '12.0', '{"min": 1, "max": 1000}', 'textfield', 7),
((SELECT id FROM config_categories WHERE name = 'financial'), 'initial_trader_balance', 'Initial Trader Balance (€)', 'number', '50000.0', '{"min": 1000, "max": 1000000}', 'textfield', 8),
((SELECT id FROM config_categories WHERE name = 'financial'), 'initial_investor_balance', 'Initial Investor Balance (€)', 'number', '25000.0', '{"min": 1000, "max": 1000000}', 'textfield', 9),

-- Features
((SELECT id FROM config_categories WHERE name = 'features'), 'price_alerts_enabled', 'Price Alerts', 'boolean', 'true', NULL, 'toggle', 1),
((SELECT id FROM config_categories WHERE name = 'features'), 'dark_mode_enabled', 'Dark Mode', 'boolean', 'false', NULL, 'toggle', 2),
((SELECT id FROM config_categories WHERE name = 'features'), 'biometric_auth_enabled', 'Biometric Auth', 'boolean', 'true', NULL, 'toggle', 3),
((SELECT id FROM config_categories WHERE name = 'features'), 'push_notifications_enabled', 'Push Notifications', 'boolean', 'true', NULL, 'toggle', 4),

-- Company
((SELECT id FROM config_categories WHERE name = 'company'), 'company_name', 'Company Name', 'string', '"FIN1 Investing GmbH"', NULL, 'textfield', 1),
((SELECT id FROM config_categories WHERE name = 'company'), 'company_address', 'Address', 'string', '"Hauptstraße 100"', NULL, 'textfield', 2),
((SELECT id FROM config_categories WHERE name = 'company'), 'company_city', 'City', 'string', '"60311 Frankfurt am Main"', NULL, 'textfield', 3),
((SELECT id FROM config_categories WHERE name = 'company'), 'company_email', 'Email', 'email', '"info@fin1-investing.de"', NULL, 'textfield', 4),
((SELECT id FROM config_categories WHERE name = 'company'), 'company_phone', 'Phone', 'string', '"+49 (0) 69 12345678"', NULL, 'textfield', 5),
((SELECT id FROM config_categories WHERE name = 'company'), 'company_vat_id', 'VAT ID', 'string', '"DE123456789"', NULL, 'textfield', 6),
((SELECT id FROM config_categories WHERE name = 'company'), 'company_register', 'Register Number', 'string', '"HRB 123456"', NULL, 'textfield', 7),
((SELECT id FROM config_categories WHERE name = 'company'), 'bank_iban', 'Bank IBAN', 'string', '"DE89 3704 0044 0532 0130 00"', NULL, 'textfield', 8),
((SELECT id FROM config_categories WHERE name = 'company'), 'bank_bic', 'Bank BIC', 'string', '"COBADEFFXXX"', NULL, 'textfield', 9),

-- Limits
((SELECT id FROM config_categories WHERE name = 'limits'), 'min_deposit', 'Min Deposit (€)', 'number', '10.0', '{"min": 1, "max": 1000}', 'textfield', 1),
((SELECT id FROM config_categories WHERE name = 'limits'), 'max_deposit', 'Max Deposit (€)', 'number', '100000.0', '{"min": 1000, "max": 1000000}', 'textfield', 2),
((SELECT id FROM config_categories WHERE name = 'limits'), 'min_withdrawal', 'Min Withdrawal (€)', 'number', '10.0', '{"min": 1, "max": 1000}', 'textfield', 3),
((SELECT id FROM config_categories WHERE name = 'limits'), 'max_withdrawal', 'Max Withdrawal (€)', 'number', '50000.0', '{"min": 1000, "max": 500000}', 'textfield', 4),
((SELECT id FROM config_categories WHERE name = 'limits'), 'daily_transaction_limit', 'Daily Limit (€)', 'number', '10000.0', '{"min": 100, "max": 100000}', 'textfield', 5),
((SELECT id FROM config_categories WHERE name = 'limits'), 'min_investment', 'Min Investment (€)', 'number', '100.0', '{"min": 10, "max": 10000}', 'textfield', 6),

-- Security
((SELECT id FROM config_categories WHERE name = 'security'), 'session_timeout_minutes', 'Session Timeout (min)', 'integer', '30', '{"min": 5, "max": 120}', 'textfield', 1),
((SELECT id FROM config_categories WHERE name = 'security'), 'max_login_attempts', 'Max Login Attempts', 'integer', '5', '{"min": 3, "max": 10}', 'textfield', 2),
((SELECT id FROM config_categories WHERE name = 'security'), 'lockout_duration_minutes', 'Lockout Duration (min)', 'integer', '15', '{"min": 5, "max": 60}', 'textfield', 3),
((SELECT id FROM config_categories WHERE name = 'security'), 'require_2fa', '2FA Required', 'boolean', 'false', NULL, 'toggle', 4),

-- Maintenance
((SELECT id FROM config_categories WHERE name = 'maintenance'), 'maintenance_mode', 'Maintenance Mode', 'boolean', 'false', NULL, 'toggle', 1),
((SELECT id FROM config_categories WHERE name = 'maintenance'), 'maintenance_message', 'Maintenance Message', 'string', '"Das System wird gewartet."', NULL, 'textarea', 2)

ON CONFLICT (category_id, key) DO NOTHING;

-- ====== DEFAULT CONFIG VALUES (for development environment) ======

INSERT INTO config_values (item_id, environment_id, value)
SELECT ci.id, e.id, ci.default_value
FROM config_items ci
CROSS JOIN environments e
WHERE e.name = 'development'
AND NOT EXISTS (
    SELECT 1 FROM config_values cv
    WHERE cv.item_id = ci.id AND cv.environment_id = e.id
);

-- ====== CSR ROLE PERMISSIONS (Production) ======

-- Level 1 Permissions
INSERT INTO csr_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM csr_roles r, csr_permissions p
WHERE r.name = 'level_1' AND p.name IN (
    'view_customer_profile', 'view_customer_transactions',
    'create_ticket', 'respond_ticket', 'close_ticket'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Level 2 Permissions (includes Level 1)
INSERT INTO csr_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM csr_roles r, csr_permissions p
WHERE r.name = 'level_2' AND p.name IN (
    'view_customer_profile', 'view_customer_transactions', 'view_customer_trades',
    'view_customer_investments', 'create_ticket', 'respond_ticket', 'close_ticket',
    'escalate_ticket', 'modify_customer_address', 'process_refund'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Fraud Analyst Permissions
INSERT INTO csr_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM csr_roles r, csr_permissions p
WHERE r.name = 'fraud_analyst' AND p.name IN (
    'view_customer_profile', 'view_customer_transactions', 'view_customer_trades',
    'view_customer_investments', 'create_ticket', 'respond_ticket', 'close_ticket',
    'escalate_ticket', 'process_chargeback', 'suspend_account_temp',
    'suspend_account_extended', 'reactivate_account', 'approve_four_eyes'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Compliance Officer Permissions
INSERT INTO csr_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM csr_roles r, csr_permissions p
WHERE r.name = 'compliance_officer' AND p.name IN (
    'view_customer_profile', 'view_customer_transactions', 'view_customer_trades',
    'view_customer_investments', 'create_ticket', 'respond_ticket', 'close_ticket',
    'escalate_ticket', 'approve_kyc', 'reject_kyc', 'submit_sar',
    'modify_customer_address', 'modify_customer_name', 'approve_four_eyes'
)
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Teamlead Permissions (all)
INSERT INTO csr_role_permissions (role_id, permission_id)
SELECT r.id, p.id
FROM csr_roles r, csr_permissions p
WHERE r.name = 'teamlead'
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- ====== FAQ SAMPLE CONTENT ======

-- Landing Page FAQs
INSERT INTO faqs (category_id, question, answer, is_public, is_user_visible, sort_order) VALUES
((SELECT id FROM faq_categories WHERE slug = 'platform_overview'),
 'Was ist FIN1?',
 'FIN1 ist eine innovative Investmentplattform, die Investoren mit erfahrenen Tradern verbindet. Investoren können ihr Kapital in von Tradern verwaltete Pools investieren und an deren Erfolg partizipieren.',
 true, true, 1),

((SELECT id FROM faq_categories WHERE slug = 'platform_overview'),
 'Wie funktioniert das Investment-Pool-System?',
 'Trader erstellen Investment-Pools, in die Investoren einzahlen können. Der Trader handelt mit dem gesammelten Kapital an den Finanzmärkten. Gewinne werden proportional auf alle Investoren verteilt, abzüglich einer Provision für den Trader.',
 true, true, 2),

((SELECT id FROM faq_categories WHERE slug = 'getting_started'),
 'Wie kann ich mich registrieren?',
 'Klicken Sie auf "Get Started" und folgen Sie dem Registrierungsprozess. Sie werden Ihre persönlichen Daten eingeben, Ihre Identität verifizieren und eine Risikoklassifizierung durchlaufen.',
 true, false, 1),

-- Help Center FAQs
((SELECT id FROM faq_categories WHERE slug = 'investments'),
 'Wie kann ich in einen Trader investieren?',
 'Navigieren Sie zur Trader-Übersicht, wählen Sie einen Trader aus, der zu Ihrem Risikoprofil passt, und klicken Sie auf "Investieren". Geben Sie den gewünschten Betrag ein und bestätigen Sie die Investition.',
 false, true, 1),

((SELECT id FROM faq_categories WHERE slug = 'trading'),
 'Wie platziere ich eine Order?',
 'Im Trading-Bereich können Sie Wertpapiere suchen, analysieren und Orders platzieren. Wählen Sie das gewünschte Wertpapier, geben Sie die Menge ein und wählen Sie den Ordertyp (Market oder Limit).',
 false, true, 1)

ON CONFLICT DO NOTHING;

-- ============================================================================
-- 2. DEVELOPMENT SEED DATA
-- ============================================================================
--
-- ACHTUNG: Die folgenden Daten sind NUR für Entwicklung und Test!
-- In Production sollte dieser Block übersprungen werden.
--
-- Setze Variable um Dev-Daten zu kontrollieren:
-- SET app.seed_dev_data = 'true';
-- ============================================================================

DO $$
DECLARE
    v_seed_dev BOOLEAN := COALESCE(current_setting('app.seed_dev_data', true), 'false')::BOOLEAN;
    v_admin_id UUID;
    v_investor_id UUID;
    v_trader_id UUID;
    v_csr_id UUID;
BEGIN
    -- Skip if not in dev mode
    IF NOT v_seed_dev THEN
        RAISE NOTICE 'Skipping development seed data. Set app.seed_dev_data = true to enable.';
        RETURN;
    END IF;

    RAISE NOTICE 'Seeding development data...';

    -- ====== TEST USERS ======

    -- Admin User
    INSERT INTO users (id, customer_id, email, username, password_hash, role, status, email_verified, kyc_status, onboarding_completed)
    VALUES (
        uuid_generate_v4(),
        'ADM-2024-00001',
        'admin@fin1-dev.local',
        'admin',
        '$2a$10$DEVELOPMENT_HASH_NOT_FOR_PRODUCTION',
        'admin',
        'active',
        true,
        'verified',
        true
    )
    RETURNING id INTO v_admin_id;

    INSERT INTO user_profiles (user_id, salutation, first_name, last_name, date_of_birth)
    VALUES (v_admin_id, 'mr', 'Admin', 'User', '1980-01-01');

    -- Test Investor
    INSERT INTO users (id, customer_id, email, username, password_hash, role, status, email_verified, kyc_status, onboarding_completed)
    VALUES (
        uuid_generate_v4(),
        'INV-2024-00001',
        'investor@fin1-dev.local',
        'testinvestor',
        '$2a$10$DEVELOPMENT_HASH_NOT_FOR_PRODUCTION',
        'investor',
        'active',
        true,
        'verified',
        true
    )
    RETURNING id INTO v_investor_id;

    INSERT INTO user_profiles (user_id, salutation, first_name, last_name, date_of_birth)
    VALUES (v_investor_id, 'mr', 'Max', 'Investor', '1985-06-15');

    INSERT INTO user_addresses (user_id, address_type, street, house_number, postal_code, city, country, is_primary, verified)
    VALUES (v_investor_id, 'primary', 'Teststraße', '123', '60311', 'Frankfurt am Main', 'Deutschland', true, true);

    INSERT INTO user_risk_assessments (user_id, risk_class, calculation_method, experience_score, knowledge_score, desired_return, assessed_by)
    VALUES (v_investor_id, 4, 'automatic', 5, 6, 'growth', 'system');

    -- Test Trader
    INSERT INTO users (id, customer_id, email, username, password_hash, role, status, email_verified, kyc_status, onboarding_completed)
    VALUES (
        uuid_generate_v4(),
        'TRD-2024-00001',
        'trader@fin1-dev.local',
        'testtrader',
        '$2a$10$DEVELOPMENT_HASH_NOT_FOR_PRODUCTION',
        'trader',
        'active',
        true,
        'verified',
        true
    )
    RETURNING id INTO v_trader_id;

    INSERT INTO user_profiles (user_id, salutation, first_name, last_name, date_of_birth)
    VALUES (v_trader_id, 'mrs', 'Lisa', 'Trader', '1990-03-22');

    INSERT INTO user_risk_assessments (user_id, risk_class, calculation_method, experience_score, knowledge_score, desired_return, assessed_by)
    VALUES (v_trader_id, 6, 'automatic', 8, 9, 'high_growth', 'system');

    -- Test CSR Agent
    INSERT INTO users (id, customer_id, email, username, password_hash, role, status, email_verified, kyc_status, onboarding_completed)
    VALUES (
        uuid_generate_v4(),
        'CSR-2024-00001',
        'support@fin1-dev.local',
        'testsupport',
        '$2a$10$DEVELOPMENT_HASH_NOT_FOR_PRODUCTION',
        'customer_service',
        'active',
        true,
        'verified',
        true
    )
    RETURNING id INTO v_csr_id;

    INSERT INTO user_profiles (user_id, salutation, first_name, last_name, date_of_birth)
    VALUES (v_csr_id, 'mr', 'Support', 'Agent', '1988-11-30');

    INSERT INTO csr_agents (user_id, role_id, agent_number, display_name, is_available, is_online)
    VALUES (v_csr_id, (SELECT id FROM csr_roles WHERE name = 'level_2'), 'CSR-001', 'Support A.', true, true);

    -- ====== INITIAL WALLET BALANCES ======

    -- Investor Wallet
    INSERT INTO wallet_transactions (transaction_number, user_id, transaction_type, amount, balance_before, balance_after, status, description, completed_at)
    VALUES
        ('TXN-2024-0000001', v_investor_id, 'deposit', 50000, 0, 50000, 'completed', 'Initial deposit', NOW());

    -- Trader Wallet
    INSERT INTO wallet_transactions (transaction_number, user_id, transaction_type, amount, balance_before, balance_after, status, description, completed_at)
    VALUES
        ('TXN-2024-0000002', v_trader_id, 'deposit', 50000, 0, 50000, 'completed', 'Initial balance', NOW());

    -- ====== SAMPLE SECURITIES ======

    INSERT INTO securities (symbol, name, security_type, wkn, exchange, currency) VALUES
        ('SAP', 'SAP SE', 'stock', '716460', 'Xetra', 'EUR'),
        ('ALV', 'Allianz SE', 'stock', '840400', 'Xetra', 'EUR'),
        ('SIE', 'Siemens AG', 'stock', '723610', 'Xetra', 'EUR'),
        ('DAX-CALL-20000', 'DAX Call 20000', 'warrant', 'TT1234', 'Xetra', 'EUR'),
        ('DAX-PUT-18000', 'DAX Put 18000', 'warrant', 'TT5678', 'Xetra', 'EUR')
    ON CONFLICT DO NOTHING;

    RAISE NOTICE 'Development seed data completed.';

EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Error seeding development data: %', SQLERRM;
END $$;

-- ============================================================================
-- END OF 016_seed_data.sql
-- ============================================================================
