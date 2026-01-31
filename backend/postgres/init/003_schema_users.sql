-- ============================================================================
-- FIN1 DATABASE SCHEMA
-- 003_schema_users.sql - User Management
-- ============================================================================
--
-- Dieses Schema verwaltet alle Benutzerdaten, KYC, Risk Assessment,
-- Einwilligungen und Geräte. Es ist die Grundlage für alle anderen
-- benutzerbezogenen Funktionen.
--
-- Tabellen (17):
--   1. users                       - Kern-Benutzerdaten
--   2. user_profiles               - Persönliche Daten
--   3. user_addresses              - Adressen (mehrere möglich)
--   4. user_citizenship_tax        - Staatsbürgerschaft & Steuerdaten
--   5. user_kyc_documents          - KYC-Dokumente
--   6. user_financial_profiles     - Finanzielle Situation
--   7. user_investment_experience  - Anlageerfahrung pro Asset-Klasse
--   8. user_risk_assessments       - Risikobewertungen (historisiert)
--   9. user_declarations           - Rechtliche Erklärungen
--   10. user_consents              - DSGVO-Einwilligungen
--   11. user_sessions              - Aktive Sessions
--   12. user_security_settings     - Sicherheitseinstellungen
--   13. user_privacy_settings      - Datenschutzeinstellungen
--   14. user_app_preferences       - App-Präferenzen
--   15. user_devices               - Registrierte Geräte
--   16. push_tokens                - Push-Notification Tokens
--   17. user_audit_log             - Änderungshistorie
--
-- ============================================================================

-- ============================================================================
-- 1. USERS
-- ============================================================================
-- Kern-Benutzertabelle (minimal, nur Authentifizierung)

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- Identifikation
    customer_id VARCHAR(20) NOT NULL UNIQUE,  -- Format: INV-2024-00001 oder TRD-2024-00001
    email VARCHAR(255) NOT NULL UNIQUE,
    username VARCHAR(100) UNIQUE,
    phone_number VARCHAR(30),

    -- Authentifizierung
    password_hash VARCHAR(255) NOT NULL,
    password_changed_at TIMESTAMP WITH TIME ZONE,
    password_reset_token VARCHAR(255),
    password_reset_expires TIMESTAMP WITH TIME ZONE,

    -- Rolle und Kontotyp
    role VARCHAR(30) NOT NULL CHECK (role IN (
        'investor', 'trader', 'admin', 'customer_service', 'compliance', 'system'
    )),
    account_type VARCHAR(20) DEFAULT 'individual' CHECK (account_type IN (
        'individual', 'company', 'institutional'
    )),

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',      -- Registrierung begonnen
        'active',       -- Aktiv und verifiziert
        'suspended',    -- Temporär gesperrt
        'locked',       -- Account gesperrt (z.B. nach Fehlversuchen)
        'closed',       -- Account geschlossen
        'deleted'       -- Soft-deleted (DSGVO)
    )),
    status_reason TEXT,
    status_changed_at TIMESTAMP WITH TIME ZONE,
    status_changed_by UUID,

    -- E-Mail Verifizierung
    email_verified BOOLEAN DEFAULT false,
    email_verified_at TIMESTAMP WITH TIME ZONE,
    email_verification_token VARCHAR(255),
    email_verification_expires TIMESTAMP WITH TIME ZONE,

    -- Telefon Verifizierung
    phone_verified BOOLEAN DEFAULT false,
    phone_verified_at TIMESTAMP WITH TIME ZONE,

    -- KYC Status (Zusammenfassung)
    kyc_status VARCHAR(20) DEFAULT 'pending' CHECK (kyc_status IN (
        'pending', 'in_progress', 'verified', 'rejected', 'expired'
    )),
    kyc_verified_at TIMESTAMP WITH TIME ZONE,
    kyc_expires_at TIMESTAMP WITH TIME ZONE,

    -- Onboarding
    onboarding_completed BOOLEAN DEFAULT false,
    onboarding_completed_at TIMESTAMP WITH TIME ZONE,
    onboarding_step VARCHAR(50),  -- Aktueller Schritt bei Abbruch

    -- Login-Tracking
    last_login_at TIMESTAMP WITH TIME ZONE,
    last_login_ip INET,
    login_count INTEGER DEFAULT 0,
    failed_login_count INTEGER DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    deleted_at TIMESTAMP WITH TIME ZONE,  -- Soft delete

    -- Constraints
    CONSTRAINT email_format CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'),
    CONSTRAINT customer_id_format CHECK (customer_id ~ '^(INV|TRD|ADM|CSR)-[0-9]{4}-[0-9]{5}$')
);

COMMENT ON TABLE users IS 'Kern-Benutzertabelle mit Authentifizierungsdaten';
COMMENT ON COLUMN users.customer_id IS 'Kunden-ID Format: INV-YYYY-NNNNN (Investor), TRD-YYYY-NNNNN (Trader)';
COMMENT ON COLUMN users.status IS 'pending=Registrierung, active=Aktiv, suspended=Gesperrt, closed=Geschlossen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_customer_id ON users(customer_id);
CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
CREATE INDEX IF NOT EXISTS idx_users_status ON users(status);
CREATE INDEX IF NOT EXISTS idx_users_kyc_status ON users(kyc_status);

-- ============================================================================
-- 2. USER_PROFILES
-- ============================================================================
-- Persönliche Daten (Name, Geburtsdatum, etc.)

CREATE TABLE IF NOT EXISTS user_profiles (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Anrede
    salutation VARCHAR(10) CHECK (salutation IN ('mr', 'mrs', 'ms', 'dr', 'prof', 'diverse')),
    academic_title VARCHAR(50),

    -- Name
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    middle_name VARCHAR(100),
    birth_name VARCHAR(100),  -- Geburtsname falls abweichend

    -- Geburt
    date_of_birth DATE NOT NULL,
    place_of_birth VARCHAR(100),
    country_of_birth VARCHAR(100),

    -- Kontakt (zusätzlich zu users.phone_number)
    mobile_phone VARCHAR(30),
    landline_phone VARCHAR(30),

    -- Profilbild
    profile_image_url TEXT,
    profile_image_updated_at TIMESTAMP WITH TIME ZONE,

    -- Sprache
    preferred_language VARCHAR(5) DEFAULT 'de',  -- ISO 639-1

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_profiles IS 'Persönliche Benutzerdaten (Name, Geburtsdatum, etc.)';
COMMENT ON COLUMN user_profiles.birth_name IS 'Geburtsname, falls vom aktuellen Namen abweichend';

-- ============================================================================
-- 3. USER_ADDRESSES
-- ============================================================================
-- Adressen (mehrere pro User möglich)

CREATE TABLE IF NOT EXISTS user_addresses (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Typ
    address_type VARCHAR(20) DEFAULT 'primary' CHECK (address_type IN (
        'primary',    -- Hauptadresse (Meldeadresse)
        'billing',    -- Rechnungsadresse
        'shipping',   -- Versandadresse
        'previous'    -- Frühere Adresse
    )),

    -- Adresse
    street VARCHAR(200) NOT NULL,
    house_number VARCHAR(20),
    address_line_2 VARCHAR(200),  -- Zusatz (Apartment, Etage)
    postal_code VARCHAR(20) NOT NULL,
    city VARCHAR(100) NOT NULL,
    state VARCHAR(100),
    country VARCHAR(100) NOT NULL DEFAULT 'Deutschland',
    country_code VARCHAR(2) DEFAULT 'DE',  -- ISO 3166-1 alpha-2

    -- Flags
    is_primary BOOLEAN DEFAULT false,

    -- Verifizierung
    verified BOOLEAN DEFAULT false,
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID,  -- Admin der verifiziert hat
    verification_method VARCHAR(30),  -- 'document', 'postident', 'video_ident'
    verification_document_url TEXT,

    -- Gültigkeit
    valid_from DATE,
    valid_until DATE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Nur eine Adresse pro Typ
    UNIQUE(user_id, address_type) WHERE address_type != 'previous'
);

COMMENT ON TABLE user_addresses IS 'Benutzeradressen (Haupt-, Rechnungs-, Versandadresse)';

-- Index
CREATE INDEX IF NOT EXISTS idx_user_addresses_user ON user_addresses(user_id);

-- ============================================================================
-- 4. USER_CITIZENSHIP_TAX
-- ============================================================================
-- Staatsbürgerschaft und Steuerinformationen

CREATE TABLE IF NOT EXISTS user_citizenship_tax (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Staatsbürgerschaft
    nationality VARCHAR(100) NOT NULL,
    nationality_code VARCHAR(2),  -- ISO 3166-1 alpha-2
    additional_nationalities TEXT[],  -- Array für mehrere

    -- US Person Status (FATCA)
    is_us_person BOOLEAN DEFAULT false,
    us_tin VARCHAR(20),  -- US Tax Identification Number

    -- Deutsche Steuer-ID
    tax_id VARCHAR(50),  -- Steueridentifikationsnummer
    tax_country VARCHAR(100) DEFAULT 'Deutschland',
    tax_country_code VARCHAR(2) DEFAULT 'DE',

    -- Zusätzliche Steuerresidenz (CRS)
    additional_tax_residencies JSONB,  -- [{"country": "AT", "country_code": "AT", "tax_id": "123"}]

    -- PEP Status (Politically Exposed Person)
    is_pep BOOLEAN DEFAULT false,
    pep_details TEXT,
    pep_checked_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_citizenship_tax IS 'Staatsbürgerschaft und Steuerinformationen (FATCA/CRS)';
COMMENT ON COLUMN user_citizenship_tax.is_us_person IS 'FATCA: US Person Status';
COMMENT ON COLUMN user_citizenship_tax.is_pep IS 'Politically Exposed Person (AML)';

-- ============================================================================
-- 5. USER_KYC_DOCUMENTS
-- ============================================================================
-- KYC-Identifikationsdokumente

CREATE TABLE IF NOT EXISTS user_kyc_documents (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Dokumenttyp
    document_type VARCHAR(30) NOT NULL CHECK (document_type IN (
        'passport',           -- Reisepass
        'id_card',            -- Personalausweis
        'drivers_license',    -- Führerschein
        'residence_permit',   -- Aufenthaltstitel
        'address_proof',      -- Adressnachweis
        'selfie',             -- Selfie für Video-Ident
        'other'
    )),

    -- Dokument-Details
    document_number VARCHAR(50),
    issuing_authority VARCHAR(200),
    issuing_country VARCHAR(100),
    issuing_country_code VARCHAR(2),
    issue_date DATE,
    expiry_date DATE,

    -- Bilder
    front_image_url TEXT,
    back_image_url TEXT,

    -- Verifizierung
    verification_status VARCHAR(20) DEFAULT 'pending' CHECK (verification_status IN (
        'pending',    -- Hochgeladen, wartet auf Prüfung
        'in_review',  -- In Prüfung
        'verified',   -- Verifiziert
        'rejected',   -- Abgelehnt
        'expired'     -- Abgelaufen
    )),
    verification_method VARCHAR(30),  -- 'manual', 'postident', 'video_ident', 'auto_ocr'
    verified_at TIMESTAMP WITH TIME ZONE,
    verified_by UUID,
    rejection_reason TEXT,
    rejection_code VARCHAR(50),

    -- OCR/Auto-Extraction
    extracted_data JSONB,  -- Automatisch extrahierte Daten
    confidence_score DECIMAL(5,2),  -- OCR Confidence 0-100

    -- Flags
    is_primary BOOLEAN DEFAULT false,  -- Primärdokument für Identifikation

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Nur ein primäres Dokument pro Typ
    UNIQUE(user_id, document_type, is_primary) WHERE is_primary = true
);

COMMENT ON TABLE user_kyc_documents IS 'KYC-Identifikationsdokumente (Ausweis, Pass, etc.)';
COMMENT ON COLUMN user_kyc_documents.confidence_score IS 'OCR Confidence Score (0-100)';

-- Index
CREATE INDEX IF NOT EXISTS idx_kyc_documents_user ON user_kyc_documents(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_documents_status ON user_kyc_documents(verification_status);

-- ============================================================================
-- 6. USER_FINANCIAL_PROFILES
-- ============================================================================
-- Finanzielle Situation des Benutzers

CREATE TABLE IF NOT EXISTS user_financial_profiles (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Beschäftigung
    employment_status VARCHAR(30) CHECK (employment_status IN (
        'employed', 'self_employed', 'civil_servant', 'freelancer',
        'unemployed', 'student', 'retired', 'homemaker', 'other'
    )),
    occupation VARCHAR(200),
    employer_name VARCHAR(200),
    employer_industry VARCHAR(100),
    employment_since DATE,

    -- Einkommen
    income_amount DECIMAL(12,2),  -- Exakter Betrag (optional)
    income_range VARCHAR(30) CHECK (income_range IN (
        'under_15k',     -- < 15.000 €
        '15k_30k',       -- 15.000 - 30.000 €
        '30k_50k',       -- 30.000 - 50.000 €
        '50k_75k',       -- 50.000 - 75.000 €
        '75k_100k',      -- 75.000 - 100.000 €
        '100k_150k',     -- 100.000 - 150.000 €
        'over_150k'      -- > 150.000 €
    )),
    income_currency VARCHAR(3) DEFAULT 'EUR',
    income_sources JSONB,  -- {"salary": true, "pension": false, "investments": true}

    -- Vermögen
    liquid_assets_range VARCHAR(30) CHECK (liquid_assets_range IN (
        'under_10k',     -- < 10.000 €
        '10k_25k',       -- 10.000 - 25.000 €
        '25k_50k',       -- 25.000 - 50.000 €
        '50k_100k',      -- 50.000 - 100.000 €
        '100k_500k',     -- 100.000 - 500.000 €
        '500k_1m',       -- 500.000 - 1.000.000 €
        'over_1m'        -- > 1.000.000 €
    )),
    total_assets_range VARCHAR(30),

    -- Art des Vermögens
    asset_type VARCHAR(20) DEFAULT 'private' CHECK (asset_type IN (
        'private', 'business', 'mixed'
    )),
    asset_sources JSONB,  -- {"savings": true, "inheritance": true, "sale": false}

    -- Verbindlichkeiten
    has_liabilities BOOLEAN DEFAULT false,
    liabilities_amount DECIMAL(12,2),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_financial_profiles IS 'Finanzielle Situation (Einkommen, Vermögen)';

-- ============================================================================
-- 7. USER_INVESTMENT_EXPERIENCE
-- ============================================================================
-- Anlageerfahrung pro Asset-Klasse (MiFID II)

CREATE TABLE IF NOT EXISTS user_investment_experience (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Asset-Klasse
    asset_class VARCHAR(30) NOT NULL CHECK (asset_class IN (
        'stocks',           -- Aktien
        'bonds',            -- Anleihen
        'etfs',             -- ETFs
        'funds',            -- Investmentfonds
        'derivatives',      -- Derivate (Optionsscheine, Zertifikate)
        'forex',            -- Devisen
        'crypto',           -- Kryptowährungen
        'real_estate',      -- Immobilien
        'commodities',      -- Rohstoffe
        'structured',       -- Strukturierte Produkte
        'other'
    )),

    -- Erfahrung
    experience_level VARCHAR(20) CHECK (experience_level IN (
        'none',             -- Keine Erfahrung
        'basic',            -- Grundkenntnisse
        'intermediate',     -- Fortgeschritten
        'advanced',         -- Erfahren
        'expert'            -- Experte
    )),
    years_experience INTEGER CHECK (years_experience >= 0 AND years_experience <= 50),

    -- Transaktionen
    transaction_count VARCHAR(20) CHECK (transaction_count IN (
        'none', '1_5', '6_10', '11_25', '26_50', '50_plus'
    )),
    average_transaction_size VARCHAR(30) CHECK (average_transaction_size IN (
        'under_1k', '1k_5k', '5k_10k', '10k_50k', '50k_100k', 'over_100k'
    )),

    -- Haltedauer
    typical_holding_period VARCHAR(30) CHECK (typical_holding_period IN (
        'intraday',         -- Innerhalb eines Tages
        'days_weeks',       -- Tage bis Wochen
        'months',           -- Monate
        'years'             -- Jahre
    )),

    -- Wissen
    knowledge_source TEXT[],  -- ['self_taught', 'courses', 'professional', 'university']
    has_professional_certification BOOLEAN DEFAULT false,
    certification_details TEXT,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id, asset_class)
);

COMMENT ON TABLE user_investment_experience IS 'Anlageerfahrung pro Asset-Klasse (MiFID II Anforderung)';

-- Index
CREATE INDEX IF NOT EXISTS idx_investment_experience_user ON user_investment_experience(user_id);

-- ============================================================================
-- 8. USER_RISK_ASSESSMENTS
-- ============================================================================
-- Risikobewertungen (historisiert für MiFID II Compliance)

CREATE TABLE IF NOT EXISTS user_risk_assessments (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Risikoklasse
    risk_class INTEGER NOT NULL CHECK (risk_class BETWEEN 1 AND 7),
    risk_class_label VARCHAR(50),  -- 'Konservativ', 'Ausgewogen', 'Spekulativ'

    -- Berechnungsmethode
    calculation_method VARCHAR(20) DEFAULT 'automatic' CHECK (calculation_method IN (
        'automatic',   -- Automatisch berechnet
        'manual',      -- Manuell durch Admin
        'override'     -- User Override (mit Bestätigung)
    )),

    -- Berechnete Scores (0-10)
    experience_score INTEGER CHECK (experience_score BETWEEN 0 AND 10),
    knowledge_score INTEGER CHECK (knowledge_score BETWEEN 0 AND 10),
    frequency_score INTEGER CHECK (frequency_score BETWEEN 0 AND 10),
    loss_tolerance_score INTEGER CHECK (loss_tolerance_score BETWEEN 0 AND 10),

    -- Inputs
    desired_return VARCHAR(30) CHECK (desired_return IN (
        'capital_preservation',  -- Kapitalerhalt
        'moderate_growth',       -- Moderates Wachstum (5-10%)
        'growth',                -- Wachstum (10-20%)
        'high_growth',           -- Hohes Wachstum (20-50%)
        'aggressive'             -- Aggressiv (>50%)
    )),
    investment_horizon VARCHAR(20) CHECK (investment_horizon IN (
        'short',    -- < 1 Jahr
        'medium',   -- 1-5 Jahre
        'long'      -- > 5 Jahre
    )),
    leveraged_products_experience BOOLEAN DEFAULT false,

    -- Override
    is_manual_override BOOLEAN DEFAULT false,
    override_reason TEXT,
    override_acknowledged_at TIMESTAMP WITH TIME ZONE,
    override_warning_shown BOOLEAN DEFAULT false,

    -- Gültigkeit
    valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valid_until TIMESTAMP WITH TIME ZONE,  -- NULL = aktuell gültig

    -- Audit
    assessed_by VARCHAR(100),  -- 'system' oder Admin-ID
    assessment_notes TEXT,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Nur ein aktives Assessment pro User
    UNIQUE(user_id, valid_from)
);

COMMENT ON TABLE user_risk_assessments IS 'Risikobewertungen (historisiert für MiFID II)';
COMMENT ON COLUMN user_risk_assessments.risk_class IS 'Risikoklasse 1-7 (1=konservativ, 7=spekulativ)';
COMMENT ON COLUMN user_risk_assessments.is_manual_override IS 'User hat höhere Risikoklasse gewählt als empfohlen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_risk_assessments_user ON user_risk_assessments(user_id);
CREATE INDEX IF NOT EXISTS idx_risk_assessments_current
    ON user_risk_assessments(user_id, valid_until)
    WHERE valid_until IS NULL;

-- ============================================================================
-- 9. USER_DECLARATIONS
-- ============================================================================
-- Rechtliche Erklärungen (Insider, AML, etc.)

CREATE TABLE IF NOT EXISTS user_declarations (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Typ der Erklärung
    declaration_type VARCHAR(50) NOT NULL CHECK (declaration_type IN (
        'insider_trading',       -- Insiderhandel-Erklärung
        'money_laundering',      -- Geldwäsche-Erklärung
        'pep',                   -- PEP-Erklärung
        'fatca',                 -- FATCA-Erklärung
        'crs',                   -- CRS-Erklärung (Common Reporting Standard)
        'beneficial_owner',      -- Wirtschaftlich Berechtigter
        'source_of_funds',       -- Herkunft der Mittel
        'tax_residency'          -- Steuerliche Ansässigkeit
    )),

    -- Erklärungsinhalt
    declaration_data JSONB,  -- Typ-spezifische Daten
    /*
      Beispiel insider_trading:
      {
        "is_broker_employee": false,
        "is_director_10percent": false,
        "is_government_official": false,
        "details": null
      }
    */

    -- Akzeptanz
    accepted BOOLEAN NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE NOT NULL,

    -- Version
    version VARCHAR(20) NOT NULL,  -- Version der Erklärung
    document_url TEXT,  -- Link zum Dokument dieser Version

    -- Kontext
    ip_address INET,
    user_agent TEXT,
    device_id VARCHAR(100),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,  -- Einige Erklärungen laufen ab

    UNIQUE(user_id, declaration_type, version)
);

COMMENT ON TABLE user_declarations IS 'Rechtliche Erklärungen (Insider, AML, FATCA, etc.)';

-- Index
CREATE INDEX IF NOT EXISTS idx_declarations_user ON user_declarations(user_id);

-- ============================================================================
-- 10. USER_CONSENTS
-- ============================================================================
-- DSGVO-konforme Einwilligungen

CREATE TABLE IF NOT EXISTS user_consents (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Typ der Einwilligung
    consent_type VARCHAR(50) NOT NULL CHECK (consent_type IN (
        'terms_of_service',      -- AGB
        'privacy_policy',        -- Datenschutzerklärung
        'marketing_email',       -- Marketing per E-Mail
        'marketing_phone',       -- Marketing per Telefon
        'marketing_push',        -- Marketing per Push
        'marketing_sms',         -- Marketing per SMS
        'data_processing',       -- Datenverarbeitung
        'third_party_sharing',   -- Weitergabe an Dritte
        'analytics',             -- Analytics/Tracking
        'crash_reporting',       -- Crash-Reports
        'personalization',       -- Personalisierung
        'newsletter'             -- Newsletter
    )),

    -- Version
    version VARCHAR(20) NOT NULL,  -- z.B. "v2.1"
    document_url TEXT,  -- Link zum Dokument dieser Version
    document_hash VARCHAR(64),  -- SHA256 des Dokuments

    -- Status
    accepted BOOLEAN NOT NULL,
    accepted_at TIMESTAMP WITH TIME ZONE,

    -- Widerruf
    revoked_at TIMESTAMP WITH TIME ZONE,
    revocation_reason TEXT,

    -- Kontext
    ip_address INET,
    user_agent TEXT,
    device_id VARCHAR(100),

    -- DSGVO Art. 6 Rechtsgrundlage
    legal_basis VARCHAR(30) CHECK (legal_basis IN (
        'consent',           -- Art. 6(1)(a) - Einwilligung
        'contract',          -- Art. 6(1)(b) - Vertrag
        'legal_obligation',  -- Art. 6(1)(c) - Rechtliche Verpflichtung
        'vital_interests',   -- Art. 6(1)(d) - Lebenswichtige Interessen
        'public_interest',   -- Art. 6(1)(e) - Öffentliches Interesse
        'legitimate_interest' -- Art. 6(1)(f) - Berechtigtes Interesse
    )),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id, consent_type, version)
);

COMMENT ON TABLE user_consents IS 'DSGVO-konforme Einwilligungsverwaltung';
COMMENT ON COLUMN user_consents.legal_basis IS 'DSGVO Art. 6 Rechtsgrundlage';

-- Index
CREATE INDEX IF NOT EXISTS idx_consents_user ON user_consents(user_id);
CREATE INDEX IF NOT EXISTS idx_consents_type ON user_consents(consent_type);

-- ============================================================================
-- 11. USER_SESSIONS
-- ============================================================================
-- Aktive Benutzersitzungen

CREATE TABLE IF NOT EXISTS user_sessions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Session Token
    session_token VARCHAR(255) NOT NULL UNIQUE,
    refresh_token VARCHAR(255),

    -- Gerät
    device_id VARCHAR(100),
    device_name VARCHAR(200),
    device_type VARCHAR(30),  -- 'iphone', 'ipad', 'mac', 'android', 'web'

    -- Client Info
    app_version VARCHAR(20),
    os_version VARCHAR(50),
    user_agent TEXT,

    -- Location
    ip_address INET,
    location_country VARCHAR(100),
    location_city VARCHAR(100),

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Zeitstempel
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    last_activity_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,
    ended_at TIMESTAMP WITH TIME ZONE,
    ended_reason VARCHAR(30)  -- 'logout', 'expired', 'revoked', 'security'
);

COMMENT ON TABLE user_sessions IS 'Aktive Benutzersitzungen für Multi-Device Support';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_sessions_user ON user_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_token ON user_sessions(session_token);
CREATE INDEX IF NOT EXISTS idx_sessions_active ON user_sessions(user_id, is_active) WHERE is_active = true;

-- ============================================================================
-- 12. USER_SECURITY_SETTINGS
-- ============================================================================
-- Sicherheitseinstellungen (2FA, Biometrie, etc.)

CREATE TABLE IF NOT EXISTS user_security_settings (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Biometrie
    biometric_enabled BOOLEAN DEFAULT false,
    biometric_type VARCHAR(20),  -- 'face_id', 'touch_id', 'optic_id'
    biometric_enrolled_at TIMESTAMP WITH TIME ZONE,

    -- 2FA
    two_factor_enabled BOOLEAN DEFAULT false,
    two_factor_method VARCHAR(20) CHECK (two_factor_method IN (
        'sms', 'email', 'authenticator', 'hardware_key'
    )),
    two_factor_secret VARCHAR(255),  -- Encrypted TOTP secret
    two_factor_backup_codes TEXT[],  -- Encrypted backup codes
    two_factor_enrolled_at TIMESTAMP WITH TIME ZONE,

    -- Auto-Lock
    auto_lock_enabled BOOLEAN DEFAULT true,
    auto_lock_timeout INTEGER DEFAULT 300,  -- Sekunden (0 = sofort, NULL = nie)

    -- Login Alerts
    login_alerts_enabled BOOLEAN DEFAULT true,
    login_alert_email BOOLEAN DEFAULT true,
    login_alert_push BOOLEAN DEFAULT true,

    -- Sicherheitsfragen (falls verwendet)
    security_questions JSONB,  -- Encrypted

    -- Trusted Devices
    trusted_devices_enabled BOOLEAN DEFAULT false,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_security_settings IS 'Sicherheitseinstellungen (2FA, Biometrie, Auto-Lock)';

-- ============================================================================
-- 13. USER_PRIVACY_SETTINGS
-- ============================================================================
-- Datenschutzeinstellungen

CREATE TABLE IF NOT EXISTS user_privacy_settings (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Datensammlung
    analytics_enabled BOOLEAN DEFAULT false,
    crash_reporting_enabled BOOLEAN DEFAULT true,
    usage_data_sharing_enabled BOOLEAN DEFAULT false,
    personalized_ads_enabled BOOLEAN DEFAULT false,

    -- Profil-Sichtbarkeit (für Investoren/Trader)
    profile_visible_to_traders BOOLEAN DEFAULT true,
    profile_visible_to_investors BOOLEAN DEFAULT true,
    show_real_name BOOLEAN DEFAULT false,  -- Zeige echten Namen statt Username

    -- Investment-Sichtbarkeit
    investment_history_visible BOOLEAN DEFAULT true,
    performance_metrics_visible BOOLEAN DEFAULT true,

    -- Marketing
    marketing_emails_enabled BOOLEAN DEFAULT false,
    newsletter_subscribed BOOLEAN DEFAULT false,
    third_party_data_sharing_enabled BOOLEAN DEFAULT false,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_privacy_settings IS 'Datenschutz- und Sichtbarkeitseinstellungen';

-- ============================================================================
-- 14. USER_APP_PREFERENCES
-- ============================================================================
-- App-Präferenzen (Theme, Sprache, etc.)

CREATE TABLE IF NOT EXISTS user_app_preferences (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Darstellung
    theme VARCHAR(20) DEFAULT 'system' CHECK (theme IN ('light', 'dark', 'system')),
    accent_color VARCHAR(20),
    font_size VARCHAR(20) DEFAULT 'medium' CHECK (font_size IN ('small', 'medium', 'large')),

    -- Sprache
    language VARCHAR(5) DEFAULT 'de',  -- ISO 639-1
    region VARCHAR(5) DEFAULT 'DE',    -- ISO 3166-1 alpha-2

    -- Zahlenformate
    currency_display VARCHAR(20) DEFAULT 'symbol',  -- 'symbol', 'code', 'name'
    number_format VARCHAR(20) DEFAULT 'de',  -- 'de' (1.234,56) oder 'en' (1,234.56)
    date_format VARCHAR(20) DEFAULT 'dd.MM.yyyy',

    -- Dashboard
    default_dashboard_tab VARCHAR(50),
    dashboard_widgets JSONB,  -- Konfiguration der Dashboard-Widgets

    -- Listen
    default_list_view VARCHAR(20) DEFAULT 'list',  -- 'list', 'grid', 'compact'
    items_per_page INTEGER DEFAULT 25,

    -- Benachrichtigungen (App-Einstellungen, nicht Marketing)
    notification_sound BOOLEAN DEFAULT true,
    notification_vibration BOOLEAN DEFAULT true,
    notification_badge BOOLEAN DEFAULT true,

    -- Trading-Präferenzen (für Trader)
    default_order_type VARCHAR(20),  -- 'market', 'limit'
    confirm_before_order BOOLEAN DEFAULT true,
    show_order_preview BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE user_app_preferences IS 'App-Einstellungen (Theme, Sprache, Darstellung)';

-- ============================================================================
-- 15. USER_DEVICES
-- ============================================================================
-- Registrierte Geräte

CREATE TABLE IF NOT EXISTS user_devices (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Identifikation
    device_id VARCHAR(100) NOT NULL,  -- Eindeutige Geräte-ID
    device_fingerprint VARCHAR(255),   -- Browser/App Fingerprint

    -- Geräteinformationen
    device_name VARCHAR(200),  -- z.B. "Max's iPhone 15"
    device_type VARCHAR(30) NOT NULL CHECK (device_type IN (
        'iphone', 'ipad', 'mac', 'apple_watch',
        'android_phone', 'android_tablet',
        'windows', 'linux', 'web', 'other'
    )),
    device_model VARCHAR(100),  -- z.B. "iPhone 15 Pro"
    manufacturer VARCHAR(100),

    -- Software
    os_name VARCHAR(50),       -- z.B. "iOS"
    os_version VARCHAR(50),    -- z.B. "17.2"
    app_version VARCHAR(20),   -- z.B. "1.2.3"

    -- Status
    is_trusted BOOLEAN DEFAULT false,
    trusted_at TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN DEFAULT true,

    -- Letzte Nutzung
    last_used_at TIMESTAMP WITH TIME ZONE,
    last_ip_address INET,
    last_location VARCHAR(200),

    -- Push-Fähigkeit
    push_enabled BOOLEAN DEFAULT false,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id, device_id)
);

COMMENT ON TABLE user_devices IS 'Registrierte Benutzergeräte für Multi-Device Support';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_devices_user ON user_devices(user_id);
CREATE INDEX IF NOT EXISTS idx_devices_active ON user_devices(user_id, is_active) WHERE is_active = true;

-- ============================================================================
-- 16. PUSH_TOKENS
-- ============================================================================
-- Push-Notification Tokens (APNS/FCM)

CREATE TABLE IF NOT EXISTS push_tokens (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id INTEGER REFERENCES user_devices(id) ON DELETE CASCADE,

    -- Token
    token TEXT NOT NULL,
    token_type VARCHAR(20) NOT NULL CHECK (token_type IN (
        'apns',        -- Apple Push Notification Service
        'apns_sandbox', -- APNS Sandbox (Development)
        'fcm',         -- Firebase Cloud Messaging
        'web_push'     -- Web Push API
    )),

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Validierung
    last_validated_at TIMESTAMP WITH TIME ZONE,
    validation_failures INTEGER DEFAULT 0,
    last_failure_reason TEXT,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(token, token_type)
);

COMMENT ON TABLE push_tokens IS 'Push-Notification Tokens (APNS/FCM)';

-- Index
CREATE INDEX IF NOT EXISTS idx_push_tokens_user ON push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_active ON push_tokens(user_id, is_active) WHERE is_active = true;

-- ============================================================================
-- 17. USER_AUDIT_LOG
-- ============================================================================
-- Änderungshistorie für Benutzerdaten (10 Jahre Aufbewahrung)

CREATE TABLE IF NOT EXISTS user_audit_log (
    id BIGSERIAL PRIMARY KEY,
    user_id UUID NOT NULL,  -- Kein FK, da User gelöscht werden kann

    -- Was wurde geändert
    table_name VARCHAR(100) NOT NULL,
    record_id INTEGER,
    action VARCHAR(20) NOT NULL CHECK (action IN (
        'create', 'update', 'delete', 'login', 'logout',
        'password_change', 'password_reset', 'email_change',
        '2fa_enable', '2fa_disable', 'kyc_submit', 'kyc_verify',
        'consent_grant', 'consent_revoke', 'gdpr_export', 'gdpr_delete'
    )),

    -- Änderungsdetails
    old_values JSONB,
    new_values JSONB,
    changed_fields TEXT[],

    -- Wer
    changed_by UUID,  -- NULL = selbst, UUID = Admin
    changed_by_role VARCHAR(50),

    -- Kontext
    ip_address INET,
    user_agent TEXT,
    session_id UUID,
    request_id VARCHAR(100),

    -- Wann
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Compliance
    reason TEXT,
    retention_until DATE DEFAULT (CURRENT_DATE + INTERVAL '10 years')
);

COMMENT ON TABLE user_audit_log IS 'Audit-Trail für alle Benutzer-Änderungen (10 Jahre)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_user_audit_user ON user_audit_log(user_id);
CREATE INDEX IF NOT EXISTS idx_user_audit_table ON user_audit_log(table_name);
CREATE INDEX IF NOT EXISTS idx_user_audit_action ON user_audit_log(action);
CREATE INDEX IF NOT EXISTS idx_user_audit_time ON user_audit_log(changed_at DESC);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Aktuelles Risk Assessment pro User
CREATE OR REPLACE VIEW v_current_risk_assessment AS
SELECT DISTINCT ON (user_id)
    user_id,
    risk_class,
    risk_class_label,
    calculation_method,
    experience_score,
    knowledge_score,
    is_manual_override,
    valid_from,
    assessed_by
FROM user_risk_assessments
WHERE valid_until IS NULL OR valid_until > NOW()
ORDER BY user_id, valid_from DESC;

-- Vollständiges User-Profil (für schnellen Zugriff)
CREATE OR REPLACE VIEW v_user_complete AS
SELECT
    u.id,
    u.customer_id,
    u.email,
    u.role,
    u.account_type,
    u.status,
    u.kyc_status,
    u.email_verified,
    u.onboarding_completed,
    p.salutation,
    p.first_name,
    p.last_name,
    p.date_of_birth,
    p.preferred_language,
    a.street || ' ' || COALESCE(a.house_number, '') AS address,
    a.postal_code,
    a.city,
    a.country,
    ct.nationality,
    ct.tax_id,
    ct.is_us_person,
    ct.is_pep,
    fp.employment_status,
    fp.income_range,
    fp.liquid_assets_range,
    ra.risk_class,
    ra.is_manual_override,
    u.created_at,
    u.last_login_at
FROM users u
LEFT JOIN user_profiles p ON u.id = p.user_id
LEFT JOIN user_addresses a ON u.id = a.user_id AND a.is_primary = true
LEFT JOIN user_citizenship_tax ct ON u.id = ct.user_id
LEFT JOIN user_financial_profiles fp ON u.id = fp.user_id
LEFT JOIN v_current_risk_assessment ra ON u.id = ra.user_id
WHERE u.status != 'deleted';

-- KYC-Status Übersicht
CREATE OR REPLACE VIEW v_kyc_status AS
SELECT
    u.id AS user_id,
    u.customer_id,
    u.email_verified,
    u.phone_verified,
    u.kyc_status,
    a.verified AS address_verified,
    (SELECT verification_status FROM user_kyc_documents
     WHERE user_id = u.id AND document_type IN ('passport', 'id_card')
     AND is_primary = true LIMIT 1) AS document_status,
    CASE
        WHEN u.email_verified
            AND a.verified
            AND EXISTS (SELECT 1 FROM user_kyc_documents
                       WHERE user_id = u.id AND verification_status = 'verified')
        THEN 'complete'
        WHEN u.kyc_status = 'rejected' THEN 'rejected'
        WHEN u.kyc_status = 'in_progress' THEN 'in_progress'
        ELSE 'incomplete'
    END AS overall_kyc_status
FROM users u
LEFT JOIN user_addresses a ON u.id = a.user_id AND a.is_primary = true;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

-- Auto-Update updated_at für alle User-Tabellen
CREATE TRIGGER user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_addresses_updated_at
    BEFORE UPDATE ON user_addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_citizenship_tax_updated_at
    BEFORE UPDATE ON user_citizenship_tax
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_kyc_documents_updated_at
    BEFORE UPDATE ON user_kyc_documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_financial_profiles_updated_at
    BEFORE UPDATE ON user_financial_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_investment_experience_updated_at
    BEFORE UPDATE ON user_investment_experience
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_security_settings_updated_at
    BEFORE UPDATE ON user_security_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_privacy_settings_updated_at
    BEFORE UPDATE ON user_privacy_settings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_app_preferences_updated_at
    BEFORE UPDATE ON user_app_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER user_devices_updated_at
    BEFORE UPDATE ON user_devices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER push_tokens_updated_at
    BEFORE UPDATE ON push_tokens
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- END OF 003_schema_users.sql
-- ============================================================================
