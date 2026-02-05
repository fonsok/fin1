-- ============================================================================
-- DATABASE SCHEMA
-- 012_indexes.sql - Consolidated Index Overview & Additional Indexes
-- ============================================================================
--
-- Die meisten Indexes sind bereits in den jeweiligen Schema-Dateien definiert.
-- Diese Datei enthält:
--   1. Übersicht aller Indexes
--   2. Zusätzliche Performance-Indexes
--   3. Composite Indexes für häufige Queries
--   4. Partial Indexes für spezielle Abfragen
--
-- ============================================================================

-- ============================================================================
-- ADDITIONAL PERFORMANCE INDEXES
-- ============================================================================

-- ====== USERS ======

-- Häufige Kombination: Role + Status + KYC
CREATE INDEX IF NOT EXISTS idx_users_role_status_kyc
    ON users(role, status, kyc_status)
    WHERE status = 'active';

-- Für Login-Lookup
CREATE INDEX IF NOT EXISTS idx_users_email_lower
    ON users(LOWER(email));

-- Letzte Logins (für Admin-Dashboard)
CREATE INDEX IF NOT EXISTS idx_users_last_login
    ON users(last_login_at DESC NULLS LAST)
    WHERE status = 'active';

-- ====== INVESTMENTS ======

-- Investor + Status Kombination (häufige Abfrage)
CREATE INDEX IF NOT EXISTS idx_investments_investor_status
    ON investments(investor_id, status);

-- Trader + Status Kombination
CREATE INDEX IF NOT EXISTS idx_investments_trader_status
    ON investments(trader_id, status);

-- Für Pool Balance Berechnung
CREATE INDEX IF NOT EXISTS idx_investments_active_trader
    ON investments(trader_id, amount)
    WHERE status IN ('active', 'executing');

-- ====== TRADES ======

-- Offene Trades pro Trader
CREATE INDEX IF NOT EXISTS idx_trades_trader_open
    ON trades(trader_id, created_at DESC)
    WHERE status IN ('pending', 'active', 'partial');

-- Für Profit Calculation
CREATE INDEX IF NOT EXISTS idx_trades_completed_recent
    ON trades(closed_at DESC, gross_profit)
    WHERE status = 'completed' AND closed_at >= NOW() - INTERVAL '90 days';

-- ====== ORDERS ======

-- Pending Orders pro Trader
CREATE INDEX IF NOT EXISTS idx_orders_trader_pending
    ON orders(trader_id, created_at DESC)
    WHERE status IN ('pending', 'submitted');

-- Ausgeführte Orders nach Datum
CREATE INDEX IF NOT EXISTS idx_orders_executed_date
    ON orders(executed_at DESC)
    WHERE status = 'executed';

-- ====== TRANSACTIONS ======

-- User Wallet Balance (letzte Transaktion)
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user_latest
    ON wallet_transactions(user_id, completed_at DESC NULLS LAST)
    WHERE status = 'completed';

-- Pending Transactions
CREATE INDEX IF NOT EXISTS idx_wallet_tx_pending
    ON wallet_transactions(status, created_at)
    WHERE status IN ('pending', 'processing');

-- ====== DOCUMENTS ======

-- User Documents nach Typ
CREATE INDEX IF NOT EXISTS idx_documents_user_type
    ON documents(user_id, document_type, created_at DESC);

-- Aktive Statements
CREATE INDEX IF NOT EXISTS idx_documents_statements
    ON documents(user_id, period_year DESC, period_month DESC)
    WHERE document_type IN ('monthly_statement', 'annual_statement');

-- ====== NOTIFICATIONS ======

-- Ungelesene Notifications (sehr häufig)
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread_recent
    ON notifications(user_id, created_at DESC)
    WHERE is_read = false AND is_archived = false;

-- Nach Kategorie filtern
CREATE INDEX IF NOT EXISTS idx_notifications_user_category
    ON notifications(user_id, category, created_at DESC)
    WHERE is_archived = false;

-- ====== SUPPORT TICKETS ======

-- Offene Tickets mit Priorität
CREATE INDEX IF NOT EXISTS idx_tickets_open_priority
    ON support_tickets(
        CASE priority
            WHEN 'urgent' THEN 1
            WHEN 'high' THEN 2
            WHEN 'medium' THEN 3
            ELSE 4
        END,
        created_at
    )
    WHERE status IN ('open', 'in_progress', 'escalated');

-- Tickets pro Agent
CREATE INDEX IF NOT EXISTS idx_tickets_agent_status
    ON support_tickets(assigned_to, status)
    WHERE assigned_to IS NOT NULL;

-- ====== PRICE ALERTS ======

-- Aktive Alerts pro Symbol (für Matching)
CREATE INDEX IF NOT EXISTS idx_price_alerts_symbol_active
    ON price_alerts(symbol, alert_type, threshold_price)
    WHERE status = 'active';

-- ====== MARKET DATA ======

-- Letzte Preise pro Symbol
CREATE INDEX IF NOT EXISTS idx_market_data_latest
    ON market_data(symbol, timestamp DESC);

-- ====== COMPLIANCE ======

-- Pending Reviews
CREATE INDEX IF NOT EXISTS idx_compliance_pending_review
    ON compliance_events(severity DESC, occurred_at)
    WHERE requires_review = true AND reviewed = false;

-- User Compliance History
CREATE INDEX IF NOT EXISTS idx_compliance_user_history
    ON compliance_events(user_id, occurred_at DESC);

-- ====== AUDIT LOGS ======

-- Recent Actions
CREATE INDEX IF NOT EXISTS idx_audit_recent_actions
    ON audit_logs(created_at DESC)
    WHERE created_at >= NOW() - INTERVAL '7 days';

-- Security Events
CREATE INDEX IF NOT EXISTS idx_audit_security
    ON audit_logs(user_id, created_at DESC)
    WHERE log_type = 'security';

-- ============================================================================
-- FULL-TEXT SEARCH INDEXES
-- ============================================================================

-- FAQ Search
CREATE INDEX IF NOT EXISTS idx_faqs_fulltext
    ON faqs USING GIN(
        to_tsvector('german', COALESCE(question, '') || ' ' || COALESCE(answer, ''))
    );

-- Ticket Search
CREATE INDEX IF NOT EXISTS idx_tickets_fulltext
    ON support_tickets USING GIN(
        to_tsvector('german', COALESCE(subject, '') || ' ' || COALESCE(description, ''))
    );

-- Securities Search
CREATE INDEX IF NOT EXISTS idx_securities_fulltext
    ON securities USING GIN(
        to_tsvector('german', COALESCE(name, '') || ' ' || COALESCE(symbol, '') || ' ' || COALESCE(isin, ''))
    );

-- ============================================================================
-- EXPRESSION INDEXES
-- ============================================================================

-- Case-insensitive email lookup
CREATE INDEX IF NOT EXISTS idx_users_email_ci
    ON users(LOWER(email));

-- Date-only indexes for date range queries
CREATE INDEX IF NOT EXISTS idx_transactions_date
    ON wallet_transactions(DATE(transaction_date));

CREATE INDEX IF NOT EXISTS idx_trades_opened_date
    ON trades(DATE(opened_at))
    WHERE opened_at IS NOT NULL;

-- ============================================================================
-- COVERING INDEXES (for index-only scans)
-- ============================================================================

-- User basic info (for listings)
CREATE INDEX IF NOT EXISTS idx_users_list_cover
    ON users(id, customer_id, email, role, status);

-- Investment summary (for portfolio view)
CREATE INDEX IF NOT EXISTS idx_investments_summary_cover
    ON investments(investor_id, status, amount, current_value, profit);

-- Trade summary (for dashboard)
CREATE INDEX IF NOT EXISTS idx_trades_summary_cover
    ON trades(trader_id, status, symbol, quantity, buy_price, gross_profit);

-- ============================================================================
-- INDEX MAINTENANCE NOTES
-- ============================================================================
/*
Performance Tuning Notes:

1. REINDEX CONCURRENTLY (PostgreSQL 12+):
   REINDEX INDEX CONCURRENTLY idx_name;

2. Check index usage:
   SELECT
       schemaname, tablename, indexname,
       idx_scan, idx_tup_read, idx_tup_fetch
   FROM pg_stat_user_indexes
   ORDER BY idx_scan DESC;

3. Find unused indexes:
   SELECT
       schemaname, tablename, indexname, pg_size_pretty(pg_relation_size(indexrelid))
   FROM pg_stat_user_indexes
   WHERE idx_scan = 0
   ORDER BY pg_relation_size(indexrelid) DESC;

4. Index bloat check:
   SELECT
       indexrelname,
       pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
   FROM pg_stat_user_indexes;

5. Recommended periodic maintenance:
   - VACUUM ANALYZE (daily for active tables)
   - REINDEX (monthly for heavily updated indexes)
*/

-- ============================================================================
-- END OF 012_indexes.sql
-- ============================================================================
