-- ============================================================================
-- DATABASE SCHEMA
-- 006_schema_investments.sql - Investment System
-- ============================================================================
--
-- Dieses Schema verwaltet alle Investment-bezogenen Daten: Investments,
-- Pool-Partizipationen, Provisionen und Investor-Watchlists.
--
-- Tabellen (7):
--   1. investments              - Investitionen von Investoren in Trader
--   2. investment_batches       - Gruppierte Investment-Batches
--   3. pool_trade_participations - Beteiligung von Investments an Trades
--   4. commissions              - Provisionen für Trader
--   5. investor_watchlist       - Beobachtete Trader (für Investoren)
--   6. saved_filters            - Gespeicherte Filter-Kombinationen
--   7. investment_audit_log     - Änderungshistorie
--
-- ============================================================================

-- ============================================================================
-- 1. INVESTMENTS
-- ============================================================================
-- Investitionen von Investoren in Trader-Pools

CREATE TABLE IF NOT EXISTS investments (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    investment_number VARCHAR(30) NOT NULL UNIQUE,  -- Format: INV-2024-0000001

    -- Beziehungen
    investor_id UUID NOT NULL REFERENCES users(id),
    trader_id UUID NOT NULL REFERENCES users(id),
    batch_id BIGINT,  -- FK zu investment_batches

    -- Beträge
    amount DECIMAL(15,2) NOT NULL,  -- Investierter Betrag
    current_value DECIMAL(15,2),     -- Aktueller Wert
    initial_value DECIMAL(15,2),     -- Anfangswert nach Gebühren

    -- Service Charge (1.5% + MwSt)
    service_charge_rate DECIMAL(6,4) DEFAULT 0.015,
    service_charge_amount DECIMAL(15,2),
    service_charge_vat DECIMAL(15,2),

    -- Performance
    profit DECIMAL(15,2) DEFAULT 0,
    profit_percentage DECIMAL(10,4) DEFAULT 0,

    -- Provisionen
    total_commission_paid DECIMAL(15,2) DEFAULT 0,  -- An Trader gezahlt

    -- Trade-Tracking
    number_of_trades INTEGER DEFAULT 0,

    -- Sequenz (für Batch-Reihenfolge)
    sequence_number INTEGER,

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'reserved' CHECK (status IN (
        'reserved',     -- Kapital reserviert
        'active',       -- Aktiv im Pool
        'executing',    -- Trades werden ausgeführt
        'paused',       -- Pausiert
        'closing',      -- Wird geschlossen
        'completed',    -- Abgeschlossen
        'cancelled'     -- Storniert
    )),
    status_reason TEXT,

    -- Reservierungsstatus
    reservation_status VARCHAR(20) DEFAULT 'pending' CHECK (reservation_status IN (
        'pending',      -- Wartet auf Bestätigung
        'confirmed',    -- Bestätigt
        'expired',      -- Abgelaufen
        'cancelled'     -- Storniert
    )),
    reservation_expires_at TIMESTAMP WITH TIME ZONE,

    -- Zeitstempel
    reserved_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    activated_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,

    -- Trader Info (Snapshot)
    trader_name VARCHAR(200),
    trader_specialization VARCHAR(100),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT investment_number_format CHECK (investment_number ~ '^INV-[0-9]{4}-[0-9]{7}$'),
    CONSTRAINT positive_amount CHECK (amount > 0)
);

COMMENT ON TABLE investments IS 'Investitionen von Investoren in Trader-Pools';
COMMENT ON COLUMN investments.service_charge_rate IS 'Service-Gebühr (Standard: 1.5%)';
COMMENT ON COLUMN investments.total_commission_paid IS 'Summe aller an Trader gezahlten Provisionen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_investments_investor ON investments(investor_id);
CREATE INDEX IF NOT EXISTS idx_investments_trader ON investments(trader_id);
CREATE INDEX IF NOT EXISTS idx_investments_batch ON investments(batch_id) WHERE batch_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_investments_status ON investments(status);
CREATE INDEX IF NOT EXISTS idx_investments_created ON investments(created_at DESC);

-- ============================================================================
-- 2. INVESTMENT_BATCHES
-- ============================================================================
-- Gruppierte Investment-Batches (mehrere Investments zusammen)

CREATE TABLE IF NOT EXISTS investment_batches (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    batch_number VARCHAR(30) NOT NULL UNIQUE,  -- Format: BATCH-2024-0000001

    -- Investor
    investor_id UUID NOT NULL REFERENCES users(id),

    -- Aggregierte Werte
    total_amount DECIMAL(15,2) NOT NULL,
    investment_count INTEGER NOT NULL,

    -- Service Charges
    total_service_charge DECIMAL(15,2),
    total_service_charge_vat DECIMAL(15,2),

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',    -- Erstellt, wartet auf Ausführung
        'active',     -- Aktiv
        'completed',  -- Alle Investments abgeschlossen
        'cancelled'   -- Storniert
    )),

    -- Zeitstempel
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    executed_at TIMESTAMP WITH TIME ZONE,
    completed_at TIMESTAMP WITH TIME ZONE
);

COMMENT ON TABLE investment_batches IS 'Gruppierte Investment-Batches';

-- Set FK in investments
ALTER TABLE investments ADD CONSTRAINT fk_investments_batch
    FOREIGN KEY (batch_id) REFERENCES investment_batches(id) ON DELETE SET NULL;

-- Index
CREATE INDEX IF NOT EXISTS idx_investment_batches_investor ON investment_batches(investor_id);

-- ============================================================================
-- 3. POOL_TRADE_PARTICIPATIONS
-- ============================================================================
-- Beteiligung von Investment-Pools an Trades

CREATE TABLE IF NOT EXISTS pool_trade_participations (
    id BIGSERIAL PRIMARY KEY,

    -- Beziehungen
    investment_id BIGINT NOT NULL REFERENCES investments(id) ON DELETE CASCADE,
    trade_id BIGINT NOT NULL REFERENCES trades(id) ON DELETE CASCADE,

    -- Beteiligung
    allocated_amount DECIMAL(15,2) NOT NULL,  -- Anteil am Trade
    ownership_percentage DECIMAL(10,6) NOT NULL,  -- Prozentsatz

    -- Ergebnisse
    profit_share DECIMAL(15,2),  -- Anteil am Gewinn
    loss_share DECIMAL(15,2),    -- Anteil am Verlust
    gross_return DECIMAL(15,2),  -- Brutto-Rendite

    -- Provision
    commission_amount DECIMAL(15,2),  -- Provision für Trader
    commission_rate DECIMAL(6,4),     -- Provisionssatz

    -- Status
    is_settled BOOLEAN DEFAULT false,
    settled_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(investment_id, trade_id)
);

COMMENT ON TABLE pool_trade_participations IS 'Beteiligung von Investments an Trades';
COMMENT ON COLUMN pool_trade_participations.ownership_percentage IS 'Prozentuale Beteiligung am Trade (0-100)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_pool_participation_investment ON pool_trade_participations(investment_id);
CREATE INDEX IF NOT EXISTS idx_pool_participation_trade ON pool_trade_participations(trade_id);
CREATE INDEX IF NOT EXISTS idx_pool_participation_unsettled
    ON pool_trade_participations(is_settled) WHERE is_settled = false;

-- ============================================================================
-- 4. COMMISSIONS
-- ============================================================================
-- Provisionen für Trader (aus Investment-Gewinnen)

CREATE TABLE IF NOT EXISTS commissions (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    commission_number VARCHAR(30) NOT NULL UNIQUE,  -- Format: COM-2024-0000001

    -- Beziehungen
    trader_id UUID NOT NULL REFERENCES users(id),
    investor_id UUID NOT NULL REFERENCES users(id),
    investment_id BIGINT NOT NULL REFERENCES investments(id),
    trade_id BIGINT REFERENCES trades(id),
    participation_id BIGINT REFERENCES pool_trade_participations(id),

    -- Berechnung
    investor_gross_profit DECIMAL(15,2) NOT NULL,  -- Brutto-Gewinn des Investors
    commission_rate DECIMAL(6,4) NOT NULL,         -- Provisionssatz (z.B. 0.05 = 5%)
    commission_amount DECIMAL(15,2) NOT NULL,      -- Provisionsbetrag

    -- Investor Info (Snapshot)
    investor_name VARCHAR(200),
    investment_amount DECIMAL(15,2),

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',      -- Berechnet, wartet auf Auszahlung
        'approved',     -- Genehmigt
        'paid',         -- Ausgezahlt
        'cancelled'     -- Storniert
    )),

    -- Auszahlung
    paid_at TIMESTAMP WITH TIME ZONE,
    payment_reference VARCHAR(100),

    -- Credit Note
    credit_note_id BIGINT,  -- FK zu invoices/documents
    credit_note_number VARCHAR(30),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE commissions IS 'Trader-Provisionen aus Investment-Gewinnen';
COMMENT ON COLUMN commissions.commission_rate IS 'Provisionssatz (z.B. 0.05 = 5%)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_commissions_trader ON commissions(trader_id);
CREATE INDEX IF NOT EXISTS idx_commissions_investor ON commissions(investor_id);
CREATE INDEX IF NOT EXISTS idx_commissions_investment ON commissions(investment_id);
CREATE INDEX IF NOT EXISTS idx_commissions_status ON commissions(status);

-- ============================================================================
-- 5. INVESTOR_WATCHLIST
-- ============================================================================
-- Beobachtete Trader (für Investoren)

CREATE TABLE IF NOT EXISTS investor_watchlist (
    id SERIAL PRIMARY KEY,

    -- Beziehungen
    investor_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    trader_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Trader Info (Snapshot für schnellen Zugriff)
    trader_name VARCHAR(200),
    trader_specialization VARCHAR(100),
    trader_risk_class INTEGER,

    -- Notizen
    notes TEXT,
    target_investment_amount DECIMAL(15,2),

    -- Benachrichtigungen
    notify_on_new_trade BOOLEAN DEFAULT false,
    notify_on_performance_change BOOLEAN DEFAULT false,

    -- Sortierung
    sort_order INTEGER DEFAULT 0,

    -- Metadaten
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(investor_id, trader_id)
);

COMMENT ON TABLE investor_watchlist IS 'Trader-Watchlist für Investoren';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_investor_watchlist_investor ON investor_watchlist(investor_id);
CREATE INDEX IF NOT EXISTS idx_investor_watchlist_trader ON investor_watchlist(trader_id);

-- ============================================================================
-- 6. SAVED_FILTERS
-- ============================================================================
-- Gespeicherte Filter-Kombinationen (für Suche)

CREATE TABLE IF NOT EXISTS saved_filters (
    id SERIAL PRIMARY KEY,

    -- Besitzer
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Identifikation
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Kontext
    filter_context VARCHAR(50) NOT NULL CHECK (filter_context IN (
        'trader_discovery',    -- Trader-Suche (Investor)
        'securities_search',   -- Wertpapier-Suche (Trader)
        'investments',         -- Investment-Liste
        'trades',              -- Trade-Liste
        'orders',              -- Order-Liste
        'documents'            -- Dokument-Liste
    )),

    -- Filter-Daten
    filter_criteria JSONB NOT NULL,
    /*
    Beispiel für trader_discovery:
    {
      "min_performance": 10,
      "max_risk_class": 5,
      "specializations": ["stocks", "derivatives"],
      "min_experience_years": 2
    }
    */

    -- Sortierung
    sort_field VARCHAR(50),
    sort_direction VARCHAR(4) CHECK (sort_direction IN ('asc', 'desc')),

    -- Status
    is_default BOOLEAN DEFAULT false,
    is_pinned BOOLEAN DEFAULT false,

    -- Nutzung
    use_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id, filter_context, name)
);

COMMENT ON TABLE saved_filters IS 'Gespeicherte Such- und Filter-Kombinationen';
COMMENT ON COLUMN saved_filters.filter_criteria IS 'Filter-Kriterien als JSON';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_saved_filters_user ON saved_filters(user_id);
CREATE INDEX IF NOT EXISTS idx_saved_filters_context ON saved_filters(user_id, filter_context);

-- ============================================================================
-- 7. INVESTMENT_AUDIT_LOG
-- ============================================================================
-- Änderungshistorie für Investments

CREATE TABLE IF NOT EXISTS investment_audit_log (
    id BIGSERIAL PRIMARY KEY,
    investment_id BIGINT NOT NULL,  -- Kein FK, Investment könnte gelöscht werden

    -- Änderung
    action VARCHAR(30) NOT NULL CHECK (action IN (
        'created', 'activated', 'trade_participated', 'profit_distributed',
        'commission_deducted', 'paused', 'resumed', 'completed', 'cancelled'
    )),

    -- Vorher/Nachher
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    old_values JSONB,
    new_values JSONB,

    -- Kontext
    trade_id BIGINT,
    commission_id BIGINT,

    -- Beträge
    amount_change DECIMAL(15,2),

    -- Wer
    changed_by UUID,  -- NULL = System

    -- Wann
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Details
    notes TEXT
);

COMMENT ON TABLE investment_audit_log IS 'Audit-Trail für Investment-Änderungen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_investment_audit_investment ON investment_audit_log(investment_id);
CREATE INDEX IF NOT EXISTS idx_investment_audit_time ON investment_audit_log(changed_at DESC);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Aktive Investments mit Performance
CREATE OR REPLACE VIEW v_active_investments AS
SELECT
    i.*,
    up.first_name || ' ' || up.last_name AS investor_full_name,
    tp.first_name || ' ' || tp.last_name AS trader_full_name,
    COALESCE(
        (SELECT SUM(ptp.profit_share)
         FROM pool_trade_participations ptp
         WHERE ptp.investment_id = i.id), 0
    ) AS total_profit_from_trades,
    COALESCE(
        (SELECT COUNT(*)
         FROM pool_trade_participations ptp
         WHERE ptp.investment_id = i.id), 0
    ) AS trades_participated
FROM investments i
JOIN user_profiles up ON i.investor_id = up.user_id
JOIN user_profiles tp ON i.trader_id = tp.user_id
WHERE i.status IN ('active', 'executing');

-- Investment-Übersicht pro Investor
CREATE OR REPLACE VIEW v_investor_portfolio AS
SELECT
    i.investor_id,
    COUNT(*) FILTER (WHERE i.status = 'active') AS active_investments,
    COUNT(*) FILTER (WHERE i.status = 'completed') AS completed_investments,
    SUM(i.amount) FILTER (WHERE i.status IN ('active', 'executing')) AS total_invested,
    SUM(i.current_value) FILTER (WHERE i.status IN ('active', 'executing')) AS total_current_value,
    SUM(i.profit) FILTER (WHERE i.status = 'completed') AS total_realized_profit,
    SUM(i.total_commission_paid) AS total_commissions_paid
FROM investments i
GROUP BY i.investor_id;

-- Trader-Performance für Investoren
CREATE OR REPLACE VIEW v_trader_performance AS
SELECT
    u.id AS trader_id,
    up.first_name || ' ' || up.last_name AS trader_name,
    ra.risk_class,
    COUNT(DISTINCT i.id) AS total_investors,
    SUM(i.amount) AS total_aum,  -- Assets Under Management
    COUNT(DISTINCT t.id) AS total_trades,
    AVG(t.profit_percentage) AS avg_trade_return,
    SUM(c.commission_amount) AS total_commissions_earned
FROM users u
JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN v_current_risk_assessment ra ON u.id = ra.user_id
LEFT JOIN investments i ON u.id = i.trader_id AND i.status IN ('active', 'completed')
LEFT JOIN trades t ON u.id = t.trader_id AND t.status = 'completed'
LEFT JOIN commissions c ON u.id = c.trader_id AND c.status = 'paid'
WHERE u.role = 'trader'
GROUP BY u.id, up.first_name, up.last_name, ra.risk_class;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER investments_updated_at
    BEFORE UPDATE ON investments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER pool_trade_participations_updated_at
    BEFORE UPDATE ON pool_trade_participations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER commissions_updated_at
    BEFORE UPDATE ON commissions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER investor_watchlist_updated_at
    BEFORE UPDATE ON investor_watchlist
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER saved_filters_updated_at
    BEFORE UPDATE ON saved_filters
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Investment Audit Trigger
CREATE OR REPLACE FUNCTION log_investment_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO investment_audit_log (investment_id, action, new_status, new_values)
        VALUES (NEW.id, 'created', NEW.status, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status != NEW.status THEN
            INSERT INTO investment_audit_log (
                investment_id, action, old_status, new_status,
                old_values, new_values, amount_change
            )
            VALUES (
                NEW.id,
                CASE
                    WHEN NEW.status = 'active' THEN 'activated'
                    WHEN NEW.status = 'completed' THEN 'completed'
                    WHEN NEW.status = 'cancelled' THEN 'cancelled'
                    WHEN NEW.status = 'paused' THEN 'paused'
                    ELSE 'status_change'
                END,
                OLD.status, NEW.status,
                to_jsonb(OLD), to_jsonb(NEW),
                NEW.current_value - OLD.current_value
            );
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER investments_audit_trigger
    AFTER INSERT OR UPDATE ON investments
    FOR EACH ROW EXECUTE FUNCTION log_investment_change();

-- ============================================================================
-- END OF 006_schema_investments.sql
-- ============================================================================
