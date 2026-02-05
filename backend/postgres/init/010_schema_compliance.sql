-- ============================================================================
-- DATABASE SCHEMA
-- 010_schema_compliance.sql - Compliance & Audit
-- ============================================================================
--
-- Dieses Schema verwaltet alle Compliance-relevanten Daten: Events, KYC-Änderungen,
-- Audit-Logs und GDPR-Anfragen. 10-Jahres-Aufbewahrung für BaFin/GwG.
--
-- Tabellen (8):
--   1. compliance_events        - Regulatorische Events
--   2. kyc_change_requests      - KYC-Änderungsanträge
--   3. kyc_change_audit         - KYC-Änderungs-Audit
--   4. audit_logs               - Allgemeiner Audit-Trail
--   5. data_access_logs         - DSGVO-Datenzugriffs-Protokoll
--   6. gdpr_requests            - DSGVO-Anfragen
--   7. statement_generation_log - Kontoauszugs-Generierung
--   8. service_lifecycle_log    - Service-Lifecycle-Events
--
-- ============================================================================

-- ============================================================================
-- 1. COMPLIANCE_EVENTS
-- ============================================================================
-- Regulatorische Events (AML, MiFID II, etc.)

CREATE TABLE IF NOT EXISTS compliance_events (
    id BIGSERIAL PRIMARY KEY,

    -- Beziehungen
    user_id UUID NOT NULL,  -- Kein FK, User könnte gelöscht werden

    -- Event-Typ
    event_type VARCHAR(50) NOT NULL CHECK (event_type IN (
        -- KYC/AML
        'kyc_initiated',
        'kyc_document_uploaded',
        'kyc_verified',
        'kyc_rejected',
        'kyc_expired',
        'aml_check_passed',
        'aml_check_failed',
        'pep_check_positive',
        'sanction_check_positive',

        -- Trading (MiFID II)
        'order_placed',
        'order_executed',
        'order_cancelled',
        'trade_completed',
        'appropriateness_check',
        'risk_warning_shown',
        'risk_warning_acknowledged',

        -- Transactions (GwG)
        'large_transaction',       -- > 10.000 €
        'suspicious_activity',
        'sar_filed',               -- Suspicious Activity Report
        'deposit_received',
        'withdrawal_requested',
        'withdrawal_completed',

        -- Account
        'account_created',
        'account_suspended',
        'account_reactivated',
        'account_closed',
        'login_from_new_device',
        'failed_login_attempt',
        'password_changed',
        'two_factor_enabled',

        -- Data
        'data_exported',
        'data_deleted',
        'consent_given',
        'consent_revoked'
    )),

    -- Schweregrad
    severity VARCHAR(20) NOT NULL DEFAULT 'low' CHECK (severity IN (
        'info', 'low', 'medium', 'high', 'critical'
    )),

    -- Beschreibung
    description TEXT NOT NULL,

    -- Details
    metadata JSONB,
    /*
    Beispiel für large_transaction:
    {
        "amount": 15000.00,
        "currency": "EUR",
        "transaction_id": "TXN-2024-0000001",
        "source": "bank_transfer"
    }
    */

    -- Referenzen
    reference_type VARCHAR(50),
    reference_id VARCHAR(100),

    -- Regulatorische Flags
    regulatory_flags TEXT[],  -- ['aml', 'mifid2', 'gdpr', 'gwg']

    -- Review
    requires_review BOOLEAN DEFAULT false,
    reviewed BOOLEAN DEFAULT false,
    reviewed_by UUID,
    reviewed_at TIMESTAMP WITH TIME ZONE,
    review_notes TEXT,

    -- Kontext
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),

    -- Zeitstempel
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Compliance
    retention_until DATE DEFAULT (CURRENT_DATE + INTERVAL '10 years')
);

COMMENT ON TABLE compliance_events IS 'Regulatorische Events (10 Jahre Aufbewahrung)';
COMMENT ON COLUMN compliance_events.regulatory_flags IS 'Betroffene Regularien: aml, mifid2, gdpr, gwg';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_compliance_events_user ON compliance_events(user_id);
CREATE INDEX IF NOT EXISTS idx_compliance_events_type ON compliance_events(event_type);
CREATE INDEX IF NOT EXISTS idx_compliance_events_severity ON compliance_events(severity) WHERE severity IN ('high', 'critical');
CREATE INDEX IF NOT EXISTS idx_compliance_events_review
    ON compliance_events(requires_review) WHERE requires_review = true AND reviewed = false;
CREATE INDEX IF NOT EXISTS idx_compliance_events_time ON compliance_events(occurred_at DESC);

-- ============================================================================
-- 2. KYC_CHANGE_REQUESTS
-- ============================================================================
-- Änderungsanträge für KYC-Daten (Name, Adresse, etc.)

CREATE TABLE IF NOT EXISTS kyc_change_requests (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    request_number VARCHAR(20) NOT NULL UNIQUE,  -- Format: KYC-2024-00001

    -- Beziehungen
    user_id UUID NOT NULL REFERENCES users(id),
    ticket_id BIGINT REFERENCES support_tickets(id),
    four_eyes_request_id INTEGER REFERENCES four_eyes_requests(id),

    -- Änderungstyp
    change_type VARCHAR(30) NOT NULL CHECK (change_type IN (
        'name_change',
        'address_change',
        'nationality_change',
        'tax_info_change',
        'document_update'
    )),

    -- Alte und neue Werte
    old_values JSONB NOT NULL,
    new_values JSONB NOT NULL,
    /*
    Beispiel für name_change:
    old_values: {"first_name": "Max", "last_name": "Müller"}
    new_values: {"first_name": "Max", "last_name": "Schmidt"}
    */

    -- Nachweis
    supporting_document_id BIGINT REFERENCES documents(id),
    supporting_document_type VARCHAR(50),

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',
        'in_review',
        'approved',
        'rejected',
        'cancelled'
    )),

    -- Bearbeitung
    processed_by INTEGER REFERENCES csr_agents(id),
    processed_at TIMESTAMP WITH TIME ZONE,
    rejection_reason TEXT,

    -- Anwendung
    applied BOOLEAN DEFAULT false,
    applied_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE kyc_change_requests IS 'KYC-Datenänderungsanträge mit Genehmigungsworkflow';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_kyc_change_user ON kyc_change_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_kyc_change_status ON kyc_change_requests(status) WHERE status IN ('pending', 'in_review');

-- ============================================================================
-- 3. KYC_CHANGE_AUDIT
-- ============================================================================
-- Unveränderlicher Audit-Trail für KYC-Änderungen

CREATE TABLE IF NOT EXISTS kyc_change_audit (
    id BIGSERIAL PRIMARY KEY,

    -- Beziehungen
    request_id INTEGER REFERENCES kyc_change_requests(id),
    user_id UUID NOT NULL,

    -- Aktion
    action VARCHAR(30) NOT NULL CHECK (action IN (
        'request_created',
        'document_uploaded',
        'review_started',
        'approved',
        'rejected',
        'applied',
        'cancelled',
        'reverted'
    )),

    -- Details
    old_values JSONB,
    new_values JSONB,
    notes TEXT,

    -- Wer
    performed_by UUID,  -- NULL = System oder User selbst
    performed_by_role VARCHAR(50),

    -- Kontext
    ip_address INET,

    -- Wann
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Compliance
    retention_until DATE DEFAULT (CURRENT_DATE + INTERVAL '10 years')
);

COMMENT ON TABLE kyc_change_audit IS 'Audit-Trail für KYC-Änderungen (10 Jahre)';

-- Index
CREATE INDEX IF NOT EXISTS idx_kyc_audit_request ON kyc_change_audit(request_id);
CREATE INDEX IF NOT EXISTS idx_kyc_audit_user ON kyc_change_audit(user_id);

-- ============================================================================
-- 4. AUDIT_LOGS
-- ============================================================================
-- Allgemeiner Audit-Trail für alle sensiblen Operationen

CREATE TABLE IF NOT EXISTS audit_logs (
    id BIGSERIAL PRIMARY KEY,

    -- Typ
    log_type VARCHAR(20) NOT NULL CHECK (log_type IN (
        'action',       -- Benutzeraktion
        'data_access',  -- Datenzugriff
        'system',       -- Systemevent
        'security',     -- Sicherheitsevent
        'compliance'    -- Compliance-Event
    )),

    -- Aktion
    action VARCHAR(100) NOT NULL,
    action_category VARCHAR(50),

    -- Wer
    user_id UUID,
    user_role VARCHAR(50),
    agent_id INTEGER,

    -- Was (betroffene Ressource)
    resource_type VARCHAR(50),
    resource_id VARCHAR(100),

    -- Details
    description TEXT,
    old_values JSONB,
    new_values JSONB,
    metadata JSONB,

    -- Ergebnis
    success BOOLEAN DEFAULT true,
    error_message TEXT,

    -- Kontext
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),
    request_id VARCHAR(100),

    -- Zeitstempel
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Compliance
    retention_until DATE DEFAULT (CURRENT_DATE + INTERVAL '10 years')
);

COMMENT ON TABLE audit_logs IS 'Allgemeiner Audit-Trail (10 Jahre Aufbewahrung)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_audit_logs_user ON audit_logs(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_audit_logs_type ON audit_logs(log_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_resource ON audit_logs(resource_type, resource_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_time ON audit_logs(created_at DESC);

-- ============================================================================
-- 5. DATA_ACCESS_LOGS
-- ============================================================================
-- DSGVO-konformes Protokoll aller Datenzugriffe auf personenbezogene Daten

CREATE TABLE IF NOT EXISTS data_access_logs (
    id BIGSERIAL PRIMARY KEY,

    -- Wer greift zu
    accessor_id UUID,  -- User oder Agent
    accessor_type VARCHAR(20) NOT NULL CHECK (accessor_type IN (
        'user',      -- User selbst
        'agent',     -- CSR-Agent
        'admin',     -- Administrator
        'system',    -- Automatisierter Prozess
        'api'        -- API-Zugriff
    )),
    accessor_role VARCHAR(50),

    -- Wessen Daten
    subject_id UUID NOT NULL,  -- Betroffene Person

    -- Was wurde zugegriffen
    data_category VARCHAR(50) NOT NULL CHECK (data_category IN (
        'personal_identification',  -- Name, Geburtsdatum
        'contact_information',      -- Adresse, Telefon, E-Mail
        'financial_information',    -- Kontostand, Transaktionen
        'identity_documents',       -- Ausweis, Pass (besondere Kategorie)
        'trading_data',             -- Trades, Orders
        'investment_data',          -- Investments
        'kyc_aml_data',             -- KYC/AML-Daten (besondere Kategorie)
        'communication_data',       -- Support-Tickets, Nachrichten
        'security_data'             -- Login-History, Sessions
    )),

    -- DSGVO-Kategorien
    is_special_category BOOLEAN DEFAULT false,  -- Art. 9 DSGVO

    -- Art des Zugriffs
    access_type VARCHAR(20) NOT NULL CHECK (access_type IN (
        'view',      -- Anzeigen
        'export',    -- Exportieren
        'print',     -- Drucken
        'modify',    -- Ändern
        'delete'     -- Löschen
    )),

    -- Rechtsgrundlage (Art. 6 DSGVO)
    legal_basis VARCHAR(30) NOT NULL CHECK (legal_basis IN (
        'consent',             -- Art. 6(1)(a) - Einwilligung
        'contract',            -- Art. 6(1)(b) - Vertragserfüllung
        'legal_obligation',    -- Art. 6(1)(c) - Rechtliche Verpflichtung
        'vital_interests',     -- Art. 6(1)(d) - Lebenswichtige Interessen
        'public_interest',     -- Art. 6(1)(e) - Öffentliches Interesse
        'legitimate_interest'  -- Art. 6(1)(f) - Berechtigtes Interesse
    )),

    -- Zweck
    purpose TEXT NOT NULL,

    -- Kontext
    ticket_id BIGINT,  -- Support-Ticket (falls zutreffend)

    -- Technischer Kontext
    ip_address INET,
    user_agent TEXT,

    -- Zeitstempel
    accessed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Compliance
    retention_until DATE DEFAULT (CURRENT_DATE + INTERVAL '10 years')
);

COMMENT ON TABLE data_access_logs IS 'DSGVO-konformes Datenzugriffs-Protokoll';
COMMENT ON COLUMN data_access_logs.is_special_category IS 'Besondere Kategorien personenbezogener Daten (Art. 9 DSGVO)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_data_access_accessor ON data_access_logs(accessor_id);
CREATE INDEX IF NOT EXISTS idx_data_access_subject ON data_access_logs(subject_id);
CREATE INDEX IF NOT EXISTS idx_data_access_category ON data_access_logs(data_category);
CREATE INDEX IF NOT EXISTS idx_data_access_time ON data_access_logs(accessed_at DESC);

-- ============================================================================
-- 6. GDPR_REQUESTS
-- ============================================================================
-- DSGVO-Anfragen (Auskunft, Löschung, Export)

CREATE TABLE IF NOT EXISTS gdpr_requests (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    request_number VARCHAR(20) NOT NULL UNIQUE,  -- Format: GDPR-2024-00001

    -- Antragsteller
    user_id UUID NOT NULL REFERENCES users(id),

    -- Typ
    request_type VARCHAR(30) NOT NULL CHECK (request_type IN (
        'access',          -- Art. 15 - Auskunftsrecht
        'rectification',   -- Art. 16 - Recht auf Berichtigung
        'erasure',         -- Art. 17 - Recht auf Löschung
        'restriction',     -- Art. 18 - Recht auf Einschränkung
        'portability',     -- Art. 20 - Recht auf Datenübertragbarkeit
        'objection'        -- Art. 21 - Widerspruchsrecht
    )),

    -- Details
    scope TEXT[],  -- Welche Daten betroffen
    reason TEXT,

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',
        'in_progress',
        'completed',
        'rejected',
        'cancelled'
    )),

    -- Bearbeitung
    assigned_to INTEGER REFERENCES csr_agents(id),
    processed_by INTEGER REFERENCES csr_agents(id),

    -- Fristen (30 Tage)
    deadline DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '30 days'),
    extended_deadline DATE,
    extension_reason TEXT,

    -- Ergebnis
    result_document_id BIGINT REFERENCES documents(id),
    result_format VARCHAR(20),  -- 'json', 'csv', 'xml', 'pdf'
    rejection_reason TEXT,

    -- 4-Augen für Löschung
    four_eyes_request_id INTEGER REFERENCES four_eyes_requests(id),

    -- Zeitstempel
    requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE gdpr_requests IS 'DSGVO-Betroffenenrechte-Anfragen';
COMMENT ON COLUMN gdpr_requests.deadline IS 'Frist: 30 Tage (Art. 12 DSGVO)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_gdpr_requests_user ON gdpr_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_gdpr_requests_status ON gdpr_requests(status) WHERE status IN ('pending', 'in_progress');
CREATE INDEX IF NOT EXISTS idx_gdpr_requests_deadline ON gdpr_requests(deadline) WHERE status NOT IN ('completed', 'rejected', 'cancelled');

-- ============================================================================
-- 7. STATEMENT_GENERATION_LOG
-- ============================================================================
-- Log der Kontoauszugs-Generierung

CREATE TABLE IF NOT EXISTS statement_generation_log (
    id SERIAL PRIMARY KEY,

    -- Beziehungen
    statement_id BIGINT REFERENCES account_statements(id),
    user_id UUID NOT NULL,

    -- Generierung
    period_type VARCHAR(10) NOT NULL,
    period_year INTEGER NOT NULL,
    period_month INTEGER,

    -- Status
    status VARCHAR(20) NOT NULL CHECK (status IN (
        'started', 'processing', 'completed', 'failed', 'retried'
    )),

    -- Ergebnis
    document_id BIGINT REFERENCES documents(id),
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,

    -- Performance
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    duration_ms INTEGER,

    -- Metadaten
    triggered_by VARCHAR(50)  -- 'scheduler', 'manual', 'on_demand'
);

COMMENT ON TABLE statement_generation_log IS 'Log der automatischen Kontoauszugs-Generierung';

-- Index
CREATE INDEX IF NOT EXISTS idx_statement_gen_user ON statement_generation_log(user_id);
CREATE INDEX IF NOT EXISTS idx_statement_gen_status ON statement_generation_log(status) WHERE status = 'failed';

-- ============================================================================
-- 8. SERVICE_LIFECYCLE_LOG
-- ============================================================================
-- Service-Lifecycle-Events (Start, Stop, Health)

CREATE TABLE IF NOT EXISTS service_lifecycle_log (
    id BIGSERIAL PRIMARY KEY,

    -- Service
    service_name VARCHAR(100) NOT NULL,
    service_instance VARCHAR(100),

    -- Event
    event_type VARCHAR(30) NOT NULL CHECK (event_type IN (
        'started',
        'stopped',
        'restarted',
        'health_check',
        'error',
        'warning',
        'config_changed'
    )),

    -- Details
    details JSONB,
    error_message TEXT,

    -- Performance
    uptime_seconds BIGINT,
    memory_usage_mb INTEGER,
    cpu_percent DECIMAL(5,2),

    -- Zeitstempel
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE service_lifecycle_log IS 'Service-Lifecycle-Events für Monitoring';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_service_lifecycle_service ON service_lifecycle_log(service_name);
CREATE INDEX IF NOT EXISTS idx_service_lifecycle_type ON service_lifecycle_log(event_type);
CREATE INDEX IF NOT EXISTS idx_service_lifecycle_time ON service_lifecycle_log(occurred_at DESC);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Compliance-Events für Review
CREATE OR REPLACE VIEW v_compliance_events_for_review AS
SELECT
    ce.*,
    up.first_name || ' ' || up.last_name AS user_name,
    u.email AS user_email,
    u.role AS user_role
FROM compliance_events ce
LEFT JOIN users u ON ce.user_id = u.id
LEFT JOIN user_profiles up ON ce.user_id = up.user_id
WHERE ce.requires_review = true AND ce.reviewed = false
ORDER BY
    CASE ce.severity
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END,
    ce.occurred_at;

-- Offene GDPR-Anfragen
CREATE OR REPLACE VIEW v_gdpr_requests_open AS
SELECT
    gr.*,
    up.first_name || ' ' || up.last_name AS user_name,
    u.email AS user_email,
    a.display_name AS assigned_agent,
    (gr.deadline - CURRENT_DATE) AS days_until_deadline
FROM gdpr_requests gr
JOIN users u ON gr.user_id = u.id
LEFT JOIN user_profiles up ON gr.user_id = up.user_id
LEFT JOIN csr_agents a ON gr.assigned_to = a.id
WHERE gr.status IN ('pending', 'in_progress')
ORDER BY gr.deadline;

-- Compliance-Statistiken
CREATE OR REPLACE VIEW v_compliance_statistics AS
SELECT
    DATE_TRUNC('month', occurred_at) AS month,
    event_type,
    severity,
    COUNT(*) AS event_count,
    COUNT(*) FILTER (WHERE requires_review) AS requires_review_count,
    COUNT(*) FILTER (WHERE reviewed) AS reviewed_count
FROM compliance_events
WHERE occurred_at >= NOW() - INTERVAL '12 months'
GROUP BY DATE_TRUNC('month', occurred_at), event_type, severity
ORDER BY month DESC, severity;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER kyc_change_requests_updated_at
    BEFORE UPDATE ON kyc_change_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER gdpr_requests_updated_at
    BEFORE UPDATE ON gdpr_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- END OF 010_schema_compliance.sql
-- ============================================================================
