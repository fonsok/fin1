-- ============================================================================
-- FIN1 DATABASE SCHEMA
-- 013_views.sql - Consolidated Views
-- ============================================================================
--
-- Zusätzliche Views für häufige Abfragen und Reporting.
-- Basis-Views sind bereits in den Schema-Dateien definiert.
--
-- ============================================================================

-- ============================================================================
-- DASHBOARD VIEWS
-- ============================================================================

-- Investor Dashboard Summary
CREATE OR REPLACE VIEW v_investor_dashboard AS
SELECT
    u.id AS user_id,
    up.first_name,
    up.last_name,

    -- Wallet
    COALESCE(wb.current_balance, 0) AS wallet_balance,

    -- Investments
    COUNT(DISTINCT i.id) FILTER (WHERE i.status = 'active') AS active_investments,
    COALESCE(SUM(i.amount) FILTER (WHERE i.status = 'active'), 0) AS total_invested,
    COALESCE(SUM(i.current_value) FILTER (WHERE i.status = 'active'), 0) AS current_investment_value,
    COALESCE(SUM(i.profit) FILTER (WHERE i.status IN ('active', 'completed')), 0) AS total_profit,

    -- Watchlist
    (SELECT COUNT(*) FROM investor_watchlist WHERE investor_id = u.id) AS watchlist_count,

    -- Notifications
    (SELECT COUNT(*) FROM notifications WHERE user_id = u.id AND is_read = false) AS unread_notifications,

    -- Documents
    (SELECT COUNT(*) FROM documents WHERE user_id = u.id AND created_at >= NOW() - INTERVAL '30 days') AS recent_documents

FROM users u
JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN v_wallet_balance wb ON u.id = wb.user_id
LEFT JOIN investments i ON u.id = i.investor_id
WHERE u.role = 'investor' AND u.status = 'active'
GROUP BY u.id, up.first_name, up.last_name, wb.current_balance;

-- Trader Dashboard Summary
CREATE OR REPLACE VIEW v_trader_dashboard AS
SELECT
    u.id AS user_id,
    up.first_name,
    up.last_name,

    -- Wallet
    COALESCE(wb.current_balance, 0) AS wallet_balance,

    -- Trading
    COUNT(DISTINCT t.id) FILTER (WHERE t.status IN ('active', 'partial')) AS open_trades,
    COUNT(DISTINCT t.id) FILTER (WHERE t.status = 'completed' AND t.closed_at >= NOW() - INTERVAL '30 days') AS trades_last_30d,
    COALESCE(SUM(t.gross_profit) FILTER (WHERE t.status = 'completed' AND t.closed_at >= NOW() - INTERVAL '30 days'), 0) AS profit_last_30d,

    -- Holdings
    (SELECT COUNT(*) FROM holdings WHERE trader_id = u.id AND status = 'active') AS active_positions,

    -- Investors
    COUNT(DISTINCT i.investor_id) FILTER (WHERE i.status = 'active') AS active_investors,
    COALESCE(SUM(i.amount) FILTER (WHERE i.status = 'active'), 0) AS total_aum,

    -- Commissions
    COALESCE(SUM(c.commission_amount) FILTER (WHERE c.status = 'paid' AND c.paid_at >= NOW() - INTERVAL '30 days'), 0) AS commissions_last_30d,

    -- Watchlist
    (SELECT COUNT(*) FROM trader_watchlist tw JOIN watchlist_items wi ON tw.id = wi.watchlist_id WHERE tw.user_id = u.id) AS watchlist_count

FROM users u
JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN v_wallet_balance wb ON u.id = wb.user_id
LEFT JOIN trades t ON u.id = t.trader_id
LEFT JOIN investments i ON u.id = i.trader_id
LEFT JOIN commissions c ON u.id = c.trader_id
WHERE u.role = 'trader' AND u.status = 'active'
GROUP BY u.id, up.first_name, up.last_name, wb.current_balance;

-- ============================================================================
-- REPORTING VIEWS
-- ============================================================================

-- Daily Transaction Summary
CREATE OR REPLACE VIEW v_daily_transactions AS
SELECT
    DATE(transaction_date) AS tx_date,
    transaction_type,
    COUNT(*) AS tx_count,
    SUM(ABS(amount)) AS total_amount,
    COUNT(DISTINCT user_id) AS unique_users
FROM wallet_transactions
WHERE status = 'completed'
GROUP BY DATE(transaction_date), transaction_type
ORDER BY tx_date DESC, transaction_type;

-- Monthly Investment Summary
CREATE OR REPLACE VIEW v_monthly_investments AS
SELECT
    DATE_TRUNC('month', created_at) AS month,
    COUNT(*) AS new_investments,
    SUM(amount) AS total_invested,
    COUNT(DISTINCT investor_id) AS unique_investors,
    COUNT(DISTINCT trader_id) AS unique_traders,
    AVG(amount) AS avg_investment_size
FROM investments
WHERE status != 'cancelled'
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- Trading Performance by Trader
CREATE OR REPLACE VIEW v_trader_performance_detailed AS
SELECT
    t.trader_id,
    up.first_name || ' ' || up.last_name AS trader_name,
    ra.risk_class,

    -- Trade Statistics
    COUNT(*) AS total_trades,
    COUNT(*) FILTER (WHERE t.status = 'completed') AS completed_trades,
    COUNT(*) FILTER (WHERE t.gross_profit > 0) AS winning_trades,
    COUNT(*) FILTER (WHERE t.gross_profit <= 0) AS losing_trades,

    -- Profit
    SUM(t.gross_profit) FILTER (WHERE t.status = 'completed') AS total_gross_profit,
    AVG(t.gross_profit) FILTER (WHERE t.status = 'completed') AS avg_profit_per_trade,
    AVG(t.profit_percentage) FILTER (WHERE t.status = 'completed') AS avg_return_pct,

    -- Win Rate
    CASE
        WHEN COUNT(*) FILTER (WHERE t.status = 'completed') > 0
        THEN ROUND(COUNT(*) FILTER (WHERE t.gross_profit > 0)::numeric /
             COUNT(*) FILTER (WHERE t.status = 'completed') * 100, 2)
        ELSE 0
    END AS win_rate_pct,

    -- Volume
    SUM(t.buy_amount) AS total_volume,

    -- Time
    AVG(EXTRACT(EPOCH FROM (t.closed_at - t.opened_at)) / 3600)
        FILTER (WHERE t.status = 'completed') AS avg_holding_hours

FROM trades t
JOIN user_profiles up ON t.trader_id = up.user_id
LEFT JOIN v_current_risk_assessment ra ON t.trader_id = ra.user_id
GROUP BY t.trader_id, up.first_name, up.last_name, ra.risk_class;

-- ============================================================================
-- SEARCH VIEWS
-- ============================================================================

-- Trader Discovery (for Investors)
CREATE OR REPLACE VIEW v_trader_discovery AS
SELECT
    u.id AS trader_id,
    up.first_name || ' ' || SUBSTRING(up.last_name, 1, 1) || '.' AS display_name,
    ra.risk_class,
    tp.total_trades,
    tp.completed_trades,
    tp.win_rate_pct,
    tp.avg_return_pct,

    -- Investor Stats
    (SELECT COUNT(DISTINCT investor_id) FROM investments WHERE trader_id = u.id AND status = 'active') AS active_investors,
    (SELECT COALESCE(SUM(amount), 0) FROM investments WHERE trader_id = u.id AND status = 'active') AS total_aum,

    -- Recent Performance
    (SELECT COALESCE(SUM(gross_profit), 0)
     FROM trades
     WHERE trader_id = u.id AND status = 'completed' AND closed_at >= NOW() - INTERVAL '30 days') AS profit_30d,

    -- Activity
    (SELECT MAX(created_at) FROM trades WHERE trader_id = u.id) AS last_trade_at,

    -- Availability
    EXISTS (
        SELECT 1 FROM investments
        WHERE trader_id = u.id AND status = 'active'
        HAVING SUM(amount) < 1000000  -- Max pool size
    ) AS accepting_investments

FROM users u
JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN v_current_risk_assessment ra ON u.id = ra.user_id
LEFT JOIN v_trader_performance_detailed tp ON u.id = tp.trader_id
WHERE u.role = 'trader'
    AND u.status = 'active'
    AND u.kyc_status = 'verified';

-- ============================================================================
-- COMPLIANCE VIEWS
-- ============================================================================

-- User Compliance Overview
CREATE OR REPLACE VIEW v_user_compliance_overview AS
SELECT
    u.id AS user_id,
    u.customer_id,
    u.email,
    u.role,
    u.kyc_status,

    -- KYC Details
    (SELECT MAX(verified_at) FROM user_kyc_documents WHERE user_id = u.id AND verification_status = 'verified') AS kyc_verified_at,
    (SELECT MIN(expiry_date) FROM user_kyc_documents WHERE user_id = u.id AND verification_status = 'verified') AS kyc_expires_at,

    -- Tax Info
    ct.is_us_person,
    ct.is_pep,

    -- Risk
    ra.risk_class,
    ra.is_manual_override AS risk_override,

    -- Compliance Events
    (SELECT COUNT(*) FROM compliance_events WHERE user_id = u.id AND severity IN ('high', 'critical')) AS high_severity_events,
    (SELECT COUNT(*) FROM compliance_events WHERE user_id = u.id AND requires_review = true AND reviewed = false) AS pending_reviews,

    -- Transaction Limits
    tl.effective_daily_limit,
    tlu.daily_used,

    -- GDPR
    (SELECT COUNT(*) FROM gdpr_requests WHERE user_id = u.id AND status IN ('pending', 'in_progress')) AS pending_gdpr_requests

FROM users u
LEFT JOIN user_citizenship_tax ct ON u.id = ct.user_id
LEFT JOIN v_current_risk_assessment ra ON u.id = ra.user_id
LEFT JOIN transaction_limits tl ON u.id = tl.user_id
LEFT JOIN transaction_limit_usage tlu ON u.id = tlu.user_id
WHERE u.status != 'deleted';

-- ============================================================================
-- SUPPORT VIEWS
-- ============================================================================

-- Customer Support Overview (for CSR)
CREATE OR REPLACE VIEW v_csr_customer_overview AS
SELECT
    u.id AS user_id,
    u.customer_id,
    u.email,
    u.role,
    u.status AS account_status,
    u.kyc_status,
    up.first_name,
    up.last_name,
    up.phone_number,

    -- Recent Activity
    u.last_login_at,

    -- Support History
    (SELECT COUNT(*) FROM support_tickets WHERE customer_id = u.id) AS total_tickets,
    (SELECT COUNT(*) FROM support_tickets WHERE customer_id = u.id AND status IN ('open', 'in_progress')) AS open_tickets,
    (SELECT AVG(rating) FROM satisfaction_surveys WHERE customer_id = u.id AND status = 'completed') AS avg_satisfaction,

    -- Financial Summary
    COALESCE(wb.current_balance, 0) AS wallet_balance,
    (SELECT COUNT(*) FROM investments WHERE investor_id = u.id AND status = 'active') AS active_investments,
    (SELECT COUNT(*) FROM trades WHERE trader_id = u.id AND status IN ('active', 'partial')) AS open_trades

FROM users u
JOIN user_profiles up ON u.id = up.user_id
LEFT JOIN v_wallet_balance wb ON u.id = wb.user_id
WHERE u.status != 'deleted';

-- ============================================================================
-- MATERIALIZED VIEWS (for performance)
-- ============================================================================

-- Materialized: Daily Statistics (refresh daily)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_daily_stats AS
SELECT
    CURRENT_DATE AS stat_date,

    -- Users
    (SELECT COUNT(*) FROM users WHERE status = 'active') AS active_users,
    (SELECT COUNT(*) FROM users WHERE created_at::date = CURRENT_DATE) AS new_users_today,

    -- Investments
    (SELECT COUNT(*) FROM investments WHERE status = 'active') AS active_investments,
    (SELECT COALESCE(SUM(amount), 0) FROM investments WHERE status = 'active') AS total_invested,

    -- Trades
    (SELECT COUNT(*) FROM trades WHERE status IN ('active', 'partial')) AS open_trades,
    (SELECT COUNT(*) FROM trades WHERE created_at::date = CURRENT_DATE) AS trades_today,

    -- Support
    (SELECT COUNT(*) FROM support_tickets WHERE status IN ('open', 'in_progress')) AS open_tickets
WITH DATA;

-- Index on materialized view
CREATE UNIQUE INDEX IF NOT EXISTS idx_mv_daily_stats_date ON mv_daily_stats(stat_date);

-- Refresh command (to be scheduled):
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_daily_stats;

-- ============================================================================
-- HELPER FUNCTIONS FOR VIEWS
-- ============================================================================

-- Function to get user's full name
CREATE OR REPLACE FUNCTION get_user_display_name(p_user_id UUID)
RETURNS TEXT AS $$
DECLARE
    v_name TEXT;
BEGIN
    SELECT
        COALESCE(
            CASE
                WHEN salutation IS NOT NULL
                THEN salutation || ' ' || first_name || ' ' || last_name
                ELSE first_name || ' ' || last_name
            END,
            'Unknown'
        )
    INTO v_name
    FROM user_profiles
    WHERE user_id = p_user_id;

    RETURN COALESCE(v_name, 'Unknown');
END;
$$ LANGUAGE plpgsql STABLE;

-- Function to format currency
CREATE OR REPLACE FUNCTION format_currency(
    p_amount DECIMAL,
    p_currency VARCHAR DEFAULT 'EUR',
    p_locale VARCHAR DEFAULT 'de_DE'
)
RETURNS TEXT AS $$
BEGIN
    RETURN CASE p_currency
        WHEN 'EUR' THEN TO_CHAR(p_amount, '999G999G999D99') || ' €'
        WHEN 'USD' THEN '$' || TO_CHAR(p_amount, '999G999G999D99')
        ELSE TO_CHAR(p_amount, '999G999G999D99') || ' ' || p_currency
    END;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- END OF 013_views.sql
-- ============================================================================
