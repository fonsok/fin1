-- ============================================================================
-- FIN1 DATABASE SCHEMA
-- 011_schema_admin.sql - Admin Features
-- ============================================================================
--
-- Dieses Schema verwaltet Admin-spezifische Funktionen: Bank-Abstimmung,
-- Rundungsdifferenzen und User-Impersonation.
--
-- Tabellen (3):
--   1. bank_reconciliation     - Bank-Abstimmung (Gegenkonto)
--   2. rounding_differences    - Rundungsdifferenzen-Tracking
--   3. admin_impersonation_log - User-Impersonation-Audit
--
-- ============================================================================

-- ============================================================================
-- 1. BANK_RECONCILIATION
-- ============================================================================
-- Bank-Abstimmung und Gegenkonto-Buchungen

CREATE TABLE IF NOT EXISTS bank_reconciliation (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    posting_number VARCHAR(30) NOT NULL UNIQUE,  -- Format: BNK-2024-0000001

    -- Buchung
    posting_date DATE NOT NULL,
    value_date DATE,

    -- Typ
    posting_type VARCHAR(30) NOT NULL CHECK (posting_type IN (
        'deposit',           -- Einzahlung
        'withdrawal',        -- Auszahlung
        'fee',               -- Gebühr
        'interest',          -- Zinsen
        'correction',        -- Korrektur
        'rounding',          -- Rundungsdifferenz
        'system_transfer',   -- System-Übertrag
        'other'
    )),

    -- Seite
    side VARCHAR(10) NOT NULL CHECK (side IN ('debit', 'credit')),

    -- Beträge
    amount DECIMAL(15,2) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',

    -- Konten
    account_type VARCHAR(30) NOT NULL CHECK (account_type IN (
        'user_wallet',       -- Benutzer-Wallet
        'pool_account',      -- Investment-Pool
        'fee_account',       -- Gebühren-Konto
        'commission_account', -- Provisions-Konto
        'suspense_account',  -- Verrechnungskonto
        'bank_account'       -- Bank-Konto
    )),
    contra_account_type VARCHAR(30) CHECK (contra_account_type IN (
        'user_wallet', 'pool_account', 'fee_account',
        'commission_account', 'suspense_account', 'bank_account'
    )),

    -- Beziehungen
    user_id UUID REFERENCES users(id),
    transaction_id BIGINT REFERENCES wallet_transactions(id),

    -- Beschreibung
    description TEXT NOT NULL,
    reference VARCHAR(100),

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',     -- Ausstehend
        'matched',     -- Abgestimmt
        'unmatched',   -- Nicht abgestimmt
        'disputed',    -- Strittig
        'resolved'     -- Geklärt
    )),

    -- Abstimmung
    matched_with_id BIGINT REFERENCES bank_reconciliation(id),
    matched_at TIMESTAMP WITH TIME ZONE,
    matched_by UUID,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

COMMENT ON TABLE bank_reconciliation IS 'Bank-Abstimmung und Gegenkonto-Buchungen';
COMMENT ON COLUMN bank_reconciliation.side IS 'Buchungsseite: debit (Soll) oder credit (Haben)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_bank_recon_date ON bank_reconciliation(posting_date DESC);
CREATE INDEX IF NOT EXISTS idx_bank_recon_status ON bank_reconciliation(status) WHERE status IN ('pending', 'unmatched');
CREATE INDEX IF NOT EXISTS idx_bank_recon_user ON bank_reconciliation(user_id) WHERE user_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_bank_recon_transaction ON bank_reconciliation(transaction_id) WHERE transaction_id IS NOT NULL;

-- ============================================================================
-- 2. ROUNDING_DIFFERENCES
-- ============================================================================
-- Tracking von Rundungsdifferenzen

CREATE TABLE IF NOT EXISTS rounding_differences (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    difference_number VARCHAR(20) NOT NULL UNIQUE,  -- Format: RND-2024-00001

    -- Kontext
    context_type VARCHAR(30) NOT NULL CHECK (context_type IN (
        'trade_calculation',      -- Trade-Berechnung
        'commission_calculation', -- Provisionsberechnung
        'profit_distribution',    -- Gewinnverteilung
        'fee_calculation',        -- Gebührenberechnung
        'currency_conversion',    -- Währungsumrechnung
        'statement_generation',   -- Kontoauszug
        'other'
    )),

    -- Beziehungen
    trade_id BIGINT REFERENCES trades(id),
    investment_id BIGINT REFERENCES investments(id),
    order_id BIGINT REFERENCES orders(id),

    -- Beträge
    expected_amount DECIMAL(15,6) NOT NULL,
    actual_amount DECIMAL(15,6) NOT NULL,
    difference_amount DECIMAL(15,6) NOT NULL,
    currency VARCHAR(3) DEFAULT 'EUR',

    -- Berechnete Werte
    difference_percentage DECIMAL(10,6),

    -- Status
    status VARCHAR(20) DEFAULT 'open' CHECK (status IN (
        'open',         -- Offen
        'under_review', -- In Prüfung
        'accepted',     -- Akzeptiert (im Rahmen)
        'adjusted',     -- Korrigiert
        'resolved'      -- Gelöst
    )),

    -- Schwellwert
    threshold_exceeded BOOLEAN DEFAULT false,
    threshold_amount DECIMAL(15,6),

    -- Lösung
    resolution_type VARCHAR(30) CHECK (resolution_type IN (
        'automatic',     -- Automatisch ausgeglichen
        'manual',        -- Manuell korrigiert
        'written_off',   -- Abgeschrieben
        'no_action'      -- Keine Aktion erforderlich
    )),
    resolution_notes TEXT,
    resolved_by UUID,
    resolved_at TIMESTAMP WITH TIME ZONE,

    -- Ausgleichsbuchung
    adjustment_posting_id BIGINT REFERENCES bank_reconciliation(id),

    -- Metadaten
    occurred_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE rounding_differences IS 'Tracking und Auflösung von Rundungsdifferenzen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_rounding_diff_status ON rounding_differences(status) WHERE status IN ('open', 'under_review');
CREATE INDEX IF NOT EXISTS idx_rounding_diff_context ON rounding_differences(context_type);
CREATE INDEX IF NOT EXISTS idx_rounding_diff_exceeded
    ON rounding_differences(threshold_exceeded) WHERE threshold_exceeded = true;

-- ============================================================================
-- 3. ADMIN_IMPERSONATION_LOG
-- ============================================================================
-- Audit-Log für Admin User-Impersonation

CREATE TABLE IF NOT EXISTS admin_impersonation_log (
    id SERIAL PRIMARY KEY,

    -- Admin
    admin_id UUID NOT NULL REFERENCES users(id),
    admin_email VARCHAR(255),

    -- Impersonierter User
    target_user_id UUID NOT NULL REFERENCES users(id),
    target_user_email VARCHAR(255),
    target_user_role VARCHAR(30),

    -- Session
    impersonation_session_id UUID NOT NULL UNIQUE DEFAULT uuid_generate_v4(),

    -- Grund
    reason TEXT NOT NULL,
    ticket_id BIGINT REFERENCES support_tickets(id),

    -- Zeitraum
    started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    duration_seconds INTEGER,

    -- Aktivitäten während Impersonation
    actions_performed TEXT[],
    pages_visited TEXT[],

    -- Kontext
    ip_address INET,
    user_agent TEXT,

    -- Status
    is_active BOOLEAN DEFAULT true
);

COMMENT ON TABLE admin_impersonation_log IS 'Audit-Log für Admin User-Impersonation';
COMMENT ON COLUMN admin_impersonation_log.reason IS 'Pflichtangabe: Warum wird der User impersoniert?';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_impersonation_admin ON admin_impersonation_log(admin_id);
CREATE INDEX IF NOT EXISTS idx_impersonation_target ON admin_impersonation_log(target_user_id);
CREATE INDEX IF NOT EXISTS idx_impersonation_active
    ON admin_impersonation_log(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_impersonation_time ON admin_impersonation_log(started_at DESC);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Unabgestimmte Bank-Buchungen
CREATE OR REPLACE VIEW v_bank_unmatched AS
SELECT
    br.*,
    up.first_name || ' ' || up.last_name AS user_name,
    wt.transaction_number AS wallet_tx_number
FROM bank_reconciliation br
LEFT JOIN users u ON br.user_id = u.id
LEFT JOIN user_profiles up ON br.user_id = up.user_id
LEFT JOIN wallet_transactions wt ON br.transaction_id = wt.id
WHERE br.status IN ('pending', 'unmatched')
ORDER BY br.posting_date DESC;

-- Offene Rundungsdifferenzen
CREATE OR REPLACE VIEW v_rounding_diff_open AS
SELECT
    rd.*,
    t.trade_number,
    i.investment_number,
    o.order_number
FROM rounding_differences rd
LEFT JOIN trades t ON rd.trade_id = t.id
LEFT JOIN investments i ON rd.investment_id = i.id
LEFT JOIN orders o ON rd.order_id = o.id
WHERE rd.status IN ('open', 'under_review')
ORDER BY
    CASE WHEN rd.threshold_exceeded THEN 0 ELSE 1 END,
    rd.occurred_at DESC;

-- Aktive Impersonations
CREATE OR REPLACE VIEW v_active_impersonations AS
SELECT
    ail.*,
    admin_p.first_name || ' ' || admin_p.last_name AS admin_name,
    target_p.first_name || ' ' || target_p.last_name AS target_name,
    EXTRACT(EPOCH FROM (NOW() - ail.started_at)) / 60 AS minutes_active
FROM admin_impersonation_log ail
JOIN user_profiles admin_p ON ail.admin_id = admin_p.user_id
JOIN user_profiles target_p ON ail.target_user_id = target_p.user_id
WHERE ail.is_active = true;

-- Admin Summary Report View
CREATE OR REPLACE VIEW v_admin_summary AS
SELECT
    -- Investments
    (SELECT COUNT(*) FROM investments WHERE status = 'active') AS active_investments,
    (SELECT COALESCE(SUM(amount), 0) FROM investments WHERE status = 'active') AS total_invested_amount,
    (SELECT COUNT(*) FROM investments WHERE created_at >= NOW() - INTERVAL '24 hours') AS investments_last_24h,

    -- Trades
    (SELECT COUNT(*) FROM trades WHERE status = 'active') AS active_trades,
    (SELECT COUNT(*) FROM trades WHERE status = 'completed' AND closed_at >= NOW() - INTERVAL '24 hours') AS trades_completed_24h,
    (SELECT COALESCE(SUM(gross_profit), 0) FROM trades WHERE status = 'completed' AND closed_at >= NOW() - INTERVAL '30 days') AS profit_last_30_days,

    -- Users
    (SELECT COUNT(*) FROM users WHERE status = 'active') AS active_users,
    (SELECT COUNT(*) FROM users WHERE created_at >= NOW() - INTERVAL '24 hours') AS new_users_24h,
    (SELECT COUNT(*) FROM users WHERE kyc_status = 'verified') AS kyc_verified_users,

    -- Support
    (SELECT COUNT(*) FROM support_tickets WHERE status IN ('open', 'in_progress')) AS open_tickets,
    (SELECT COUNT(*) FROM four_eyes_requests WHERE status = 'pending') AS pending_approvals,

    -- Compliance
    (SELECT COUNT(*) FROM compliance_events WHERE requires_review = true AND reviewed = false) AS compliance_reviews_pending,
    (SELECT COUNT(*) FROM gdpr_requests WHERE status IN ('pending', 'in_progress')) AS gdpr_requests_open;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER bank_reconciliation_updated_at
    BEFORE UPDATE ON bank_reconciliation
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER rounding_differences_updated_at
    BEFORE UPDATE ON rounding_differences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger für Impersonation-Dauer
CREATE OR REPLACE FUNCTION calculate_impersonation_duration()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.ended_at IS NOT NULL AND OLD.ended_at IS NULL THEN
        NEW.duration_seconds = EXTRACT(EPOCH FROM (NEW.ended_at - NEW.started_at));
        NEW.is_active = false;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER impersonation_duration
    BEFORE UPDATE ON admin_impersonation_log
    FOR EACH ROW EXECUTE FUNCTION calculate_impersonation_duration();

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Funktion zum Starten einer Impersonation
CREATE OR REPLACE FUNCTION start_impersonation(
    p_admin_id UUID,
    p_target_user_id UUID,
    p_reason TEXT,
    p_ticket_id BIGINT DEFAULT NULL
)
RETURNS UUID AS $$
DECLARE
    v_session_id UUID;
    v_admin_email VARCHAR(255);
    v_target_email VARCHAR(255);
    v_target_role VARCHAR(30);
BEGIN
    -- Hole Admin- und Target-Daten
    SELECT email INTO v_admin_email FROM users WHERE id = p_admin_id;
    SELECT email, role INTO v_target_email, v_target_role FROM users WHERE id = p_target_user_id;

    -- Prüfe ob Admin berechtigt ist
    IF NOT EXISTS (
        SELECT 1 FROM users u
        WHERE u.id = p_admin_id AND u.role = 'admin'
    ) THEN
        RAISE EXCEPTION 'User is not an admin';
    END IF;

    -- Prüfe ob bereits aktive Impersonation
    IF EXISTS (
        SELECT 1 FROM admin_impersonation_log
        WHERE admin_id = p_admin_id AND is_active = true
    ) THEN
        RAISE EXCEPTION 'Admin already has an active impersonation session';
    END IF;

    -- Erstelle Impersonation
    INSERT INTO admin_impersonation_log (
        admin_id, admin_email, target_user_id, target_user_email,
        target_user_role, reason, ticket_id
    ) VALUES (
        p_admin_id, v_admin_email, p_target_user_id, v_target_email,
        v_target_role, p_reason, p_ticket_id
    )
    RETURNING impersonation_session_id INTO v_session_id;

    -- Log Compliance Event
    INSERT INTO compliance_events (
        user_id, event_type, severity, description, metadata
    ) VALUES (
        p_target_user_id,
        'account_suspended',  -- Oder eigener Typ
        'medium',
        'Admin impersonation started',
        jsonb_build_object(
            'admin_id', p_admin_id,
            'session_id', v_session_id,
            'reason', p_reason
        )
    );

    RETURN v_session_id;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Beenden einer Impersonation
CREATE OR REPLACE FUNCTION end_impersonation(p_session_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    UPDATE admin_impersonation_log
    SET ended_at = NOW()
    WHERE impersonation_session_id = p_session_id AND is_active = true;

    RETURN FOUND;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- END OF 011_schema_admin.sql
-- ============================================================================
