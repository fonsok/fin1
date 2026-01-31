-- ============================================================================
-- FIN1 DATABASE SCHEMA
-- 009_schema_csr.sql - Customer Support (CSR)
-- ============================================================================
--
-- Dieses Schema verwaltet alle Customer Support Funktionen: Tickets, Agents,
-- Berechtigungen, 4-Augen-Prinzip und Kundenzufriedenheit.
--
-- Tabellen (12):
--   1. csr_roles              - CSR-Rollen
--   2. csr_permissions        - Granulare Berechtigungen
--   3. csr_role_permissions   - Mapping Rollen zu Berechtigungen
--   4. csr_agents             - CSR-Agenten
--   5. csr_agent_skills       - Agent-Spezialisierungen
--   6. support_tickets        - Support-Tickets
--   7. ticket_responses       - Ticket-Antworten
--   8. ticket_assignments     - Zuweisung-Historie
--   9. ticket_sla_tracking    - SLA-Monitoring
--   10. four_eyes_requests    - 4-Augen-Genehmigungen
--   11. four_eyes_audit       - 4-Augen-Audit-Trail
--   12. satisfaction_surveys  - Kundenzufriedenheits-Umfragen
--
-- ============================================================================

-- ============================================================================
-- 1. CSR_ROLES
-- ============================================================================
-- CSR-Rollen (Level 1, Level 2, Fraud, Compliance, Teamlead)

CREATE TABLE IF NOT EXISTS csr_roles (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100) NOT NULL,
    display_name_de VARCHAR(100),

    -- Beschreibung
    description TEXT,

    -- Hierarchie
    level INTEGER NOT NULL,  -- 1 = niedrigste, höher = mehr Rechte

    -- Berechtigungen-Flags (Schnellzugriff)
    can_view_trades BOOLEAN DEFAULT false,
    can_approve_requests BOOLEAN DEFAULT false,
    can_manage_agents BOOLEAN DEFAULT false,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE csr_roles IS 'CSR-Rollen mit Hierarchie';

-- ============================================================================
-- 2. CSR_PERMISSIONS
-- ============================================================================
-- Granulare Berechtigungen

CREATE TABLE IF NOT EXISTS csr_permissions (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    name VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(200) NOT NULL,

    -- Kategorie
    category VARCHAR(50) NOT NULL CHECK (category IN (
        'viewing',       -- Leserechte
        'modification',  -- Schreibrechte
        'support',       -- Support-Operationen
        'compliance',    -- Compliance/KYC
        'fraud',         -- Fraud-Detection
        'administration' -- Agent-Verwaltung
    )),

    -- Beschreibung
    description TEXT,

    -- Risiko-Level
    risk_level VARCHAR(20) DEFAULT 'low' CHECK (risk_level IN ('low', 'medium', 'high', 'critical')),

    -- Erfordert 4-Augen?
    requires_four_eyes BOOLEAN DEFAULT false,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE csr_permissions IS 'Granulare CSR-Berechtigungen';

-- ============================================================================
-- 3. CSR_ROLE_PERMISSIONS
-- ============================================================================
-- Mapping von Rollen zu Berechtigungen

CREATE TABLE IF NOT EXISTS csr_role_permissions (
    id SERIAL PRIMARY KEY,
    role_id INTEGER NOT NULL REFERENCES csr_roles(id) ON DELETE CASCADE,
    permission_id INTEGER NOT NULL REFERENCES csr_permissions(id) ON DELETE CASCADE,

    -- Einschränkungen
    constraints JSONB,  -- z.B. {"max_amount": 500, "own_tickets_only": true}

    -- Metadaten
    granted_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    granted_by UUID,

    UNIQUE(role_id, permission_id)
);

COMMENT ON TABLE csr_role_permissions IS 'Zuordnung Berechtigungen zu Rollen';

-- ============================================================================
-- 4. CSR_AGENTS
-- ============================================================================
-- CSR-Agenten (erweitert User)

CREATE TABLE IF NOT EXISTS csr_agents (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Rolle
    role_id INTEGER NOT NULL REFERENCES csr_roles(id),

    -- Agent-Details
    agent_number VARCHAR(20) UNIQUE,  -- z.B. CSR-001
    display_name VARCHAR(100),

    -- Kapazität
    max_concurrent_tickets INTEGER DEFAULT 8,
    current_ticket_count INTEGER DEFAULT 0,

    -- Verfügbarkeit
    is_available BOOLEAN DEFAULT true,
    is_online BOOLEAN DEFAULT false,
    last_online_at TIMESTAMP WITH TIME ZONE,
    away_reason VARCHAR(100),

    -- Schicht
    shift_start TIME,
    shift_end TIME,
    timezone VARCHAR(50) DEFAULT 'Europe/Berlin',

    -- Performance (Aggregiert)
    total_tickets_handled INTEGER DEFAULT 0,
    average_response_time_minutes INTEGER,
    average_resolution_time_minutes INTEGER,
    average_satisfaction_rating DECIMAL(3,2),

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE csr_agents IS 'CSR-Agenten mit Kapazität und Performance';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_csr_agents_user ON csr_agents(user_id);
CREATE INDEX IF NOT EXISTS idx_csr_agents_role ON csr_agents(role_id);
CREATE INDEX IF NOT EXISTS idx_csr_agents_available
    ON csr_agents(is_available, is_online) WHERE is_available = true AND is_active = true;

-- ============================================================================
-- 5. CSR_AGENT_SKILLS
-- ============================================================================
-- Spezialisierungen pro Agent

CREATE TABLE IF NOT EXISTS csr_agent_skills (
    id SERIAL PRIMARY KEY,
    agent_id INTEGER NOT NULL REFERENCES csr_agents(id) ON DELETE CASCADE,

    -- Skill
    skill_type VARCHAR(50) NOT NULL CHECK (skill_type IN (
        'general',
        'technical',
        'billing',
        'investments',
        'trading',
        'kyc',
        'fraud',
        'compliance',
        'escalation'
    )),

    -- Level
    proficiency_level INTEGER DEFAULT 1 CHECK (proficiency_level BETWEEN 1 AND 5),

    -- Sprachen
    languages TEXT[],  -- ['de', 'en']

    -- Metadaten
    acquired_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(agent_id, skill_type)
);

COMMENT ON TABLE csr_agent_skills IS 'Agent-Spezialisierungen für Skill-based Routing';

-- ============================================================================
-- 6. SUPPORT_TICKETS
-- ============================================================================
-- Support-Tickets

CREATE TABLE IF NOT EXISTS support_tickets (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    ticket_number VARCHAR(20) NOT NULL UNIQUE,  -- Format: TKT-2024-00001

    -- Kunde
    customer_id UUID NOT NULL REFERENCES users(id),
    customer_name VARCHAR(200),
    customer_email VARCHAR(255),

    -- Inhalt
    subject VARCHAR(300) NOT NULL,
    description TEXT NOT NULL,

    -- Klassifikation
    category VARCHAR(50) NOT NULL CHECK (category IN (
        'general',
        'account_issue',
        'technical_issue',
        'billing',
        'investment',
        'trading_question',
        'security',
        'feedback',
        'complaint',
        'kyc',
        'fraud_report'
    )),

    -- Priorität
    priority VARCHAR(20) NOT NULL DEFAULT 'medium' CHECK (priority IN (
        'low', 'medium', 'high', 'urgent'
    )),

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'open' CHECK (status IN (
        'open',
        'in_progress',
        'waiting_for_customer',
        'escalated',
        'resolved',
        'closed',
        'archived'
    )),

    -- Zuweisung
    assigned_to INTEGER REFERENCES csr_agents(id),
    assigned_at TIMESTAMP WITH TIME ZONE,

    -- Eskalation
    escalated_to INTEGER REFERENCES csr_agents(id),
    escalation_reason TEXT,
    escalation_level INTEGER DEFAULT 0,

    -- Tags
    tags TEXT[],

    -- Verknüpfungen
    related_investment_id BIGINT,
    related_trade_id BIGINT,
    related_order_id BIGINT,

    -- Wiedereröffnung
    parent_ticket_id BIGINT REFERENCES support_tickets(id),
    reopen_count INTEGER DEFAULT 0,

    -- Zeitstempel
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    first_response_at TIMESTAMP WITH TIME ZONE,
    resolved_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,
    archived_at TIMESTAMP WITH TIME ZONE,

    -- Automatische Archivierung
    auto_archive_at TIMESTAMP WITH TIME ZONE  -- 30 Tage nach Schließung
);

COMMENT ON TABLE support_tickets IS 'Support-Tickets mit vollständigem Lifecycle';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_support_tickets_customer ON support_tickets(customer_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_assigned ON support_tickets(assigned_to);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON support_tickets(status);
CREATE INDEX IF NOT EXISTS idx_support_tickets_priority ON support_tickets(priority);
CREATE INDEX IF NOT EXISTS idx_support_tickets_created ON support_tickets(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_support_tickets_open
    ON support_tickets(status, priority) WHERE status IN ('open', 'in_progress', 'escalated');

-- ============================================================================
-- 7. TICKET_RESPONSES
-- ============================================================================
-- Antworten und Aktivitäten auf Tickets

CREATE TABLE IF NOT EXISTS ticket_responses (
    id BIGSERIAL PRIMARY KEY,
    ticket_id BIGINT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,

    -- Autor
    agent_id INTEGER REFERENCES csr_agents(id),
    agent_name VARCHAR(100),
    customer_id UUID REFERENCES users(id),  -- Wenn Kunde antwortet

    -- Inhalt
    message TEXT NOT NULL,

    -- Typ
    response_type VARCHAR(30) NOT NULL CHECK (response_type IN (
        'message',        -- Normale Nachricht
        'internal_note',  -- Interne Notiz (nicht für Kunde sichtbar)
        'solution',       -- Lösungsvorschlag
        'escalation',     -- Eskalations-Notiz
        'status_change',  -- Status-Änderung
        'assignment',     -- Zuweisung
        'auto_response'   -- Automatische Antwort
    )),

    -- Flags
    is_internal BOOLEAN DEFAULT false,  -- Nicht für Kunde sichtbar
    is_solution BOOLEAN DEFAULT false,

    -- Lösungsdetails
    solution_type VARCHAR(50),
    solution_details JSONB,

    -- Anhänge
    attachments JSONB,  -- [{url, filename, size, type}]

    -- Canned Response
    canned_response_id INTEGER,

    -- Zeitstempel
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE ticket_responses IS 'Ticket-Antworten und Aktivitäten';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_ticket_responses_ticket ON ticket_responses(ticket_id);
CREATE INDEX IF NOT EXISTS idx_ticket_responses_agent ON ticket_responses(agent_id);

-- ============================================================================
-- 8. TICKET_ASSIGNMENTS
-- ============================================================================
-- Zuweisung-Historie

CREATE TABLE IF NOT EXISTS ticket_assignments (
    id SERIAL PRIMARY KEY,
    ticket_id BIGINT NOT NULL REFERENCES support_tickets(id) ON DELETE CASCADE,

    -- Von/An
    assigned_from INTEGER REFERENCES csr_agents(id),
    assigned_to INTEGER NOT NULL REFERENCES csr_agents(id),

    -- Grund
    assignment_type VARCHAR(30) CHECK (assignment_type IN (
        'initial',      -- Erste Zuweisung
        'manual',       -- Manuelle Umzuweisung
        'auto',         -- Automatisch (Round-Robin)
        'skill_based',  -- Skill-basiert
        'escalation',   -- Eskalation
        'workload'      -- Workload-Balancing
    )),
    reason TEXT,

    -- Zeitstempel
    assigned_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE ticket_assignments IS 'Historie der Ticket-Zuweisungen';

-- Index
CREATE INDEX IF NOT EXISTS idx_ticket_assignments_ticket ON ticket_assignments(ticket_id);

-- ============================================================================
-- 9. TICKET_SLA_TRACKING
-- ============================================================================
-- SLA-Monitoring pro Ticket

CREATE TABLE IF NOT EXISTS ticket_sla_tracking (
    id SERIAL PRIMARY KEY,
    ticket_id BIGINT NOT NULL UNIQUE REFERENCES support_tickets(id) ON DELETE CASCADE,

    -- First Response SLA
    first_response_target TIMESTAMP WITH TIME ZONE,
    first_response_actual TIMESTAMP WITH TIME ZONE,
    first_response_breached BOOLEAN DEFAULT false,

    -- Resolution SLA
    resolution_target TIMESTAMP WITH TIME ZONE,
    resolution_actual TIMESTAMP WITH TIME ZONE,
    resolution_breached BOOLEAN DEFAULT false,

    -- Pausierung
    is_paused BOOLEAN DEFAULT false,
    paused_at TIMESTAMP WITH TIME ZONE,
    paused_reason VARCHAR(100),
    total_paused_minutes INTEGER DEFAULT 0,

    -- Status
    sla_status VARCHAR(20) DEFAULT 'on_track' CHECK (sla_status IN (
        'on_track',   -- Im Plan
        'warning',    -- Warnung (<25% Zeit übrig)
        'breached',   -- SLA verletzt
        'paused',     -- Pausiert
        'completed'   -- Abgeschlossen
    )),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE ticket_sla_tracking IS 'SLA-Tracking und -Monitoring pro Ticket';

-- ============================================================================
-- 10. FOUR_EYES_REQUESTS
-- ============================================================================
-- 4-Augen-Genehmigungsanträge

CREATE TABLE IF NOT EXISTS four_eyes_requests (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    request_number VARCHAR(20) NOT NULL UNIQUE,  -- Format: 4E-2024-00001

    -- Typ
    request_type VARCHAR(50) NOT NULL CHECK (request_type IN (
        -- Account
        'account_suspension_extended',
        'account_suspension_permanent',
        'account_reactivation',

        -- Financial
        'chargeback_over_50',
        'chargeback_over_500',
        'refund_over_100',

        -- Compliance
        'sar_submission',
        'kyc_manual_approval',
        'kyc_rejection',

        -- GDPR
        'gdpr_data_deletion',
        'gdpr_data_export',

        -- Customer Data
        'address_change',
        'name_change'
    )),

    -- Risiko
    risk_level VARCHAR(20) NOT NULL CHECK (risk_level IN (
        'low', 'medium', 'high', 'critical'
    )),

    -- Antragsteller
    requester_id INTEGER NOT NULL REFERENCES csr_agents(id),
    requester_justification TEXT NOT NULL,

    -- Betroffener Kunde
    customer_id UUID REFERENCES users(id),
    ticket_id BIGINT REFERENCES support_tickets(id),

    -- Request-Details
    request_data JSONB NOT NULL,
    /* Beispiel für chargeback:
    {
        "amount": 150.00,
        "transaction_id": "TXN-2024-0000123",
        "reason": "Unauthorized transaction"
    }
    */

    -- Genehmigung
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending', 'approved', 'rejected', 'expired', 'cancelled'
    )),
    approver_id INTEGER REFERENCES csr_agents(id),
    approver_notes TEXT,
    approved_at TIMESTAMP WITH TIME ZONE,
    rejected_at TIMESTAMP WITH TIME ZONE,

    -- Ablauf
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,

    -- Ausführung
    executed BOOLEAN DEFAULT false,
    executed_at TIMESTAMP WITH TIME ZONE,
    execution_result JSONB,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE four_eyes_requests IS '4-Augen-Genehmigungsanträge';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_four_eyes_status ON four_eyes_requests(status) WHERE status = 'pending';
CREATE INDEX IF NOT EXISTS idx_four_eyes_requester ON four_eyes_requests(requester_id);
CREATE INDEX IF NOT EXISTS idx_four_eyes_customer ON four_eyes_requests(customer_id);

-- ============================================================================
-- 11. FOUR_EYES_AUDIT
-- ============================================================================
-- Unveränderlicher Audit-Trail für 4-Augen-Prozesse

CREATE TABLE IF NOT EXISTS four_eyes_audit (
    id BIGSERIAL PRIMARY KEY,
    request_id INTEGER NOT NULL REFERENCES four_eyes_requests(id),

    -- Aktion
    action VARCHAR(30) NOT NULL CHECK (action IN (
        'created', 'viewed', 'approved', 'rejected',
        'expired', 'cancelled', 'executed'
    )),

    -- Wer
    performed_by INTEGER REFERENCES csr_agents(id),
    performed_by_role VARCHAR(50),

    -- Details
    notes TEXT,

    -- Kontext
    ip_address INET,
    user_agent TEXT,
    session_id VARCHAR(100),

    -- Wann
    performed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE four_eyes_audit IS 'Unveränderlicher Audit-Trail für 4-Augen-Prozesse';

-- Index
CREATE INDEX IF NOT EXISTS idx_four_eyes_audit_request ON four_eyes_audit(request_id);

-- ============================================================================
-- 12. SATISFACTION_SURVEYS
-- ============================================================================
-- Kundenzufriedenheits-Umfragen

CREATE TABLE IF NOT EXISTS satisfaction_surveys (
    id SERIAL PRIMARY KEY,

    -- Beziehungen
    ticket_id BIGINT NOT NULL REFERENCES support_tickets(id),
    customer_id UUID NOT NULL REFERENCES users(id),
    agent_id INTEGER REFERENCES csr_agents(id),

    -- Bewertung
    rating INTEGER CHECK (rating BETWEEN 1 AND 5),  -- 1-5 Sterne

    -- Schnell-Feedback
    was_issue_resolved BOOLEAN,
    was_agent_helpful BOOLEAN,
    was_response_time_satisfactory BOOLEAN,

    -- Kommentar
    comment TEXT,

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',     -- Gesendet, wartet auf Antwort
        'completed',   -- Ausgefüllt
        'expired',     -- Abgelaufen (7 Tage)
        'declined'     -- Abgelehnt
    )),

    -- Zeitstempel
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    completed_at TIMESTAMP WITH TIME ZONE,
    expires_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE satisfaction_surveys IS 'Kundenzufriedenheits-Umfragen nach Ticket-Abschluss';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_satisfaction_surveys_ticket ON satisfaction_surveys(ticket_id);
CREATE INDEX IF NOT EXISTS idx_satisfaction_surveys_agent ON satisfaction_surveys(agent_id);
CREATE INDEX IF NOT EXISTS idx_satisfaction_surveys_status ON satisfaction_surveys(status) WHERE status = 'pending';

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Offene Tickets mit SLA-Status
CREATE OR REPLACE VIEW v_open_tickets AS
SELECT
    t.*,
    sla.first_response_target,
    sla.resolution_target,
    sla.sla_status,
    a.display_name AS assigned_agent_name,
    EXTRACT(EPOCH FROM (NOW() - t.created_at)) / 3600 AS hours_open
FROM support_tickets t
LEFT JOIN ticket_sla_tracking sla ON t.id = sla.ticket_id
LEFT JOIN csr_agents a ON t.assigned_to = a.id
WHERE t.status IN ('open', 'in_progress', 'waiting_for_customer', 'escalated')
ORDER BY
    CASE t.priority
        WHEN 'urgent' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END,
    t.created_at;

-- Agent Performance
CREATE OR REPLACE VIEW v_agent_performance AS
SELECT
    a.id AS agent_id,
    a.display_name,
    r.display_name AS role_name,
    a.total_tickets_handled,
    a.current_ticket_count,
    a.average_response_time_minutes,
    a.average_resolution_time_minutes,
    a.average_satisfaction_rating,
    COUNT(t.id) FILTER (WHERE t.status = 'closed' AND t.closed_at >= NOW() - INTERVAL '30 days') AS closed_last_30_days,
    AVG(s.rating) FILTER (WHERE s.completed_at >= NOW() - INTERVAL '30 days') AS avg_rating_last_30_days
FROM csr_agents a
JOIN csr_roles r ON a.role_id = r.id
LEFT JOIN support_tickets t ON a.id = t.assigned_to
LEFT JOIN satisfaction_surveys s ON a.id = s.agent_id AND s.status = 'completed'
WHERE a.is_active = true
GROUP BY a.id, a.display_name, r.display_name, a.total_tickets_handled,
         a.current_ticket_count, a.average_response_time_minutes,
         a.average_resolution_time_minutes, a.average_satisfaction_rating;

-- Pending 4-Eyes Requests
CREATE OR REPLACE VIEW v_pending_four_eyes AS
SELECT
    r.*,
    req.display_name AS requester_name,
    req_role.display_name AS requester_role,
    up.first_name || ' ' || up.last_name AS customer_name
FROM four_eyes_requests r
JOIN csr_agents req ON r.requester_id = req.id
JOIN csr_roles req_role ON req.role_id = req_role.id
LEFT JOIN users u ON r.customer_id = u.id
LEFT JOIN user_profiles up ON u.id = up.user_id
WHERE r.status = 'pending'
    AND r.expires_at > NOW()
ORDER BY
    CASE r.risk_level
        WHEN 'critical' THEN 1
        WHEN 'high' THEN 2
        WHEN 'medium' THEN 3
        ELSE 4
    END,
    r.created_at;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER csr_roles_updated_at
    BEFORE UPDATE ON csr_roles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER csr_agents_updated_at
    BEFORE UPDATE ON csr_agents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER support_tickets_updated_at
    BEFORE UPDATE ON support_tickets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER ticket_sla_tracking_updated_at
    BEFORE UPDATE ON ticket_sla_tracking
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER four_eyes_requests_updated_at
    BEFORE UPDATE ON four_eyes_requests
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INITIAL DATA - Roles & Permissions
-- ============================================================================

-- Roles
INSERT INTO csr_roles (name, display_name, display_name_de, level, can_view_trades, can_approve_requests, can_manage_agents) VALUES
('level_1', 'Level 1 Support', 'Level 1 Support', 1, false, false, false),
('level_2', 'Level 2 Support', 'Level 2 Support', 2, true, false, false),
('fraud_analyst', 'Fraud Analyst', 'Betrugsanalyst', 3, true, true, false),
('compliance_officer', 'Compliance Officer', 'Compliance-Beauftragter', 3, true, true, false),
('tech_support', 'Technical Support', 'Technischer Support', 2, false, false, false),
('teamlead', 'Team Lead', 'Teamleiter', 4, true, true, true)
ON CONFLICT (name) DO NOTHING;

-- Basic Permissions
INSERT INTO csr_permissions (name, display_name, category, risk_level, requires_four_eyes) VALUES
-- Viewing
('view_customer_profile', 'View Customer Profile', 'viewing', 'low', false),
('view_customer_transactions', 'View Customer Transactions', 'viewing', 'low', false),
('view_customer_trades', 'View Customer Trades', 'viewing', 'medium', false),
('view_customer_investments', 'View Customer Investments', 'viewing', 'medium', false),

-- Support
('create_ticket', 'Create Ticket', 'support', 'low', false),
('respond_ticket', 'Respond to Ticket', 'support', 'low', false),
('close_ticket', 'Close Ticket', 'support', 'low', false),
('escalate_ticket', 'Escalate Ticket', 'support', 'medium', false),

-- Modification
('modify_customer_address', 'Modify Customer Address', 'modification', 'medium', true),
('modify_customer_name', 'Modify Customer Name', 'modification', 'high', true),
('process_chargeback', 'Process Chargeback', 'modification', 'high', true),
('process_refund', 'Process Refund', 'modification', 'medium', true),

-- Compliance
('approve_kyc', 'Approve KYC', 'compliance', 'high', true),
('reject_kyc', 'Reject KYC', 'compliance', 'high', true),
('submit_sar', 'Submit SAR', 'compliance', 'critical', true),

-- Fraud
('suspend_account_temp', 'Suspend Account (Temporary)', 'fraud', 'medium', false),
('suspend_account_extended', 'Suspend Account (Extended)', 'fraud', 'high', true),
('reactivate_account', 'Reactivate Account', 'fraud', 'high', true),

-- Administration
('manage_agents', 'Manage Agents', 'administration', 'medium', false),
('approve_four_eyes', 'Approve Four-Eyes Requests', 'administration', 'high', false)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- END OF 009_schema_csr.sql
-- ============================================================================
