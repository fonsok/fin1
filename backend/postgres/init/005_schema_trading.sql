-- ============================================================================
-- DATABASE SCHEMA
-- 005_schema_trading.sql - Trading System
-- ============================================================================
--
-- Dieses Schema verwaltet alle Trading-bezogenen Daten: Securities, Orders,
-- Trades, Holdings, Market Data und Price Alerts.
--
-- Tabellen (11):
--   1. securities            - Wertpapier-Stammdaten
--   2. orders                - Kauf- und Verkaufsorders
--   3. order_fees            - Gebühren pro Order
--   4. trades                - Trades (Buy + Sell kombiniert)
--   5. trade_audit_log       - Änderungshistorie für Trades
--   6. holdings              - Depot-Positionen
--   7. market_data           - Aktuelle Marktdaten
--   8. price_alerts          - Preisalarme
--   9. price_alert_history   - Ausgelöste Alarme
--   10. trader_watchlist     - Beobachtungsliste (Securities)
--   11. watchlist_items      - Einzelne Watchlist-Einträge
--
-- ============================================================================

-- ============================================================================
-- 1. SECURITIES
-- ============================================================================
-- Wertpapier-Stammdaten

CREATE TABLE IF NOT EXISTS securities (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    symbol VARCHAR(50) NOT NULL,
    isin VARCHAR(12),  -- International Securities Identification Number
    wkn VARCHAR(6),    -- Wertpapierkennnummer (DE)
    cusip VARCHAR(9),  -- US CUSIP

    -- Basisinformationen
    name VARCHAR(200) NOT NULL,
    short_name VARCHAR(50),
    description TEXT,

    -- Typ
    security_type VARCHAR(30) NOT NULL CHECK (security_type IN (
        'stock',           -- Aktie
        'bond',            -- Anleihe
        'etf',             -- ETF
        'fund',            -- Investmentfonds
        'warrant',         -- Optionsschein
        'certificate',     -- Zertifikat
        'option',          -- Option
        'future',          -- Future
        'forex',           -- Devisen
        'crypto',          -- Kryptowährung
        'commodity',       -- Rohstoff
        'index'            -- Index
    )),

    -- Für Derivate
    underlying_symbol VARCHAR(50),  -- Basiswert
    underlying_name VARCHAR(200),
    option_type VARCHAR(10) CHECK (option_type IN ('call', 'put')),
    strike_price DECIMAL(15,4),
    expiry_date DATE,
    multiplier DECIMAL(10,4),
    subscription_ratio DECIMAL(10,4),  -- Bezugsverhältnis

    -- Emittent
    issuer_name VARCHAR(200),
    issuer_code VARCHAR(20),

    -- Handel
    exchange VARCHAR(50),  -- Hauptbörse
    currency VARCHAR(3) DEFAULT 'EUR',
    trading_hours VARCHAR(50),  -- z.B. "08:00-22:00"

    -- Lot Size
    min_lot_size DECIMAL(15,4) DEFAULT 1,
    lot_size_increment DECIMAL(15,4) DEFAULT 1,

    -- Status
    is_tradable BOOLEAN DEFAULT true,
    is_active BOOLEAN DEFAULT true,
    delisted_at DATE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(symbol, exchange),
    CONSTRAINT isin_format CHECK (isin IS NULL OR isin ~ '^[A-Z]{2}[A-Z0-9]{10}$'),
    CONSTRAINT wkn_format CHECK (wkn IS NULL OR wkn ~ '^[A-Z0-9]{6}$')
);

COMMENT ON TABLE securities IS 'Wertpapier-Stammdaten (Aktien, Derivate, etc.)';
COMMENT ON COLUMN securities.subscription_ratio IS 'Bezugsverhältnis für Optionsscheine (z.B. 0.1 = 10:1)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_securities_symbol ON securities(symbol);
CREATE INDEX IF NOT EXISTS idx_securities_isin ON securities(isin) WHERE isin IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_securities_wkn ON securities(wkn) WHERE wkn IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_securities_type ON securities(security_type);
CREATE INDEX IF NOT EXISTS idx_securities_underlying ON securities(underlying_symbol) WHERE underlying_symbol IS NOT NULL;

-- ============================================================================
-- 2. ORDERS
-- ============================================================================
-- Kauf- und Verkaufsorders

CREATE TABLE IF NOT EXISTS orders (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    order_number VARCHAR(30) NOT NULL UNIQUE,  -- Format: ORD-2024-0000001

    -- Beziehungen
    trader_id UUID NOT NULL REFERENCES users(id),
    security_id INTEGER NOT NULL REFERENCES securities(id),
    trade_id BIGINT,  -- FK zu trades, NULL bei Buy-Orders bis Trade erstellt

    -- Wertpapier-Snapshot (denormalisiert für History)
    symbol VARCHAR(50) NOT NULL,
    security_name VARCHAR(200),
    security_type VARCHAR(30),
    wkn VARCHAR(6),

    -- Order-Typ
    side VARCHAR(10) NOT NULL CHECK (side IN ('buy', 'sell')),
    order_type VARCHAR(20) NOT NULL CHECK (order_type IN (
        'market',   -- Marktorder
        'limit',    -- Limitorder
        'stop',     -- Stop-Order
        'stop_limit' -- Stop-Limit-Order
    )),

    -- Mengen und Preise
    quantity DECIMAL(15,4) NOT NULL,
    executed_quantity DECIMAL(15,4) DEFAULT 0,
    remaining_quantity DECIMAL(15,4),

    price DECIMAL(15,4),  -- Ausführungspreis (bei Market: nach Ausführung)
    limit_price DECIMAL(15,4),  -- Limitpreis
    stop_price DECIMAL(15,4),   -- Stop-Preis

    -- Beträge
    gross_amount DECIMAL(15,2),  -- Bruttobetrag
    net_amount DECIMAL(15,2),    -- Nettobetrag (nach Gebühren)
    total_fees DECIMAL(15,2),    -- Gesamtgebühren

    -- Derivat-spezifisch
    option_direction VARCHAR(10) CHECK (option_direction IN ('call', 'put')),
    underlying_asset VARCHAR(50),
    strike DECIMAL(15,4),

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',      -- Erstellt, wartet auf Übermittlung
        'submitted',    -- An Börse übermittelt
        'partial',      -- Teilweise ausgeführt
        'executed',     -- Vollständig ausgeführt
        'cancelled',    -- Storniert
        'rejected',     -- Abgelehnt
        'expired'       -- Abgelaufen
    )),
    status_message TEXT,

    -- Gültigkeit
    time_in_force VARCHAR(10) DEFAULT 'day' CHECK (time_in_force IN (
        'day',   -- Gültig für den Tag
        'gtc',   -- Good Till Cancelled
        'ioc',   -- Immediate Or Cancel
        'fok'    -- Fill Or Kill
    )),
    valid_until TIMESTAMP WITH TIME ZONE,

    -- Zeitstempel
    submitted_at TIMESTAMP WITH TIME ZONE,
    executed_at TIMESTAMP WITH TIME ZONE,
    cancelled_at TIMESTAMP WITH TIME ZONE,

    -- Referenzen
    original_holding_id BIGINT,  -- Bei Verkauf: Referenz auf Holding
    parent_order_id BIGINT REFERENCES orders(id),  -- Für Teilausführungen

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT order_number_format CHECK (order_number ~ '^ORD-[0-9]{4}-[0-9]{7}$')
);

COMMENT ON TABLE orders IS 'Kauf- und Verkaufsorders';
COMMENT ON COLUMN orders.remaining_quantity IS 'Noch nicht ausgeführte Menge (für Teilausführungen)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_orders_trader ON orders(trader_id);
CREATE INDEX IF NOT EXISTS idx_orders_trade ON orders(trade_id) WHERE trade_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_created ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_symbol ON orders(symbol);

-- ============================================================================
-- 3. ORDER_FEES
-- ============================================================================
-- Gebühren pro Order (aufgeschlüsselt)

CREATE TABLE IF NOT EXISTS order_fees (
    id SERIAL PRIMARY KEY,
    order_id BIGINT NOT NULL REFERENCES orders(id) ON DELETE CASCADE,

    -- Gebührentyp
    fee_type VARCHAR(30) NOT NULL CHECK (fee_type IN (
        'order_fee',       -- Ordergebühr
        'exchange_fee',    -- Börsengebühr
        'broker_fee',      -- Broker-Gebühr
        'clearing_fee',    -- Clearing-Gebühr
        'foreign_cost',    -- Auslandsspesen
        'stamp_duty',      -- Stempelsteuer (UK)
        'financial_tx_tax', -- Finanztransaktionssteuer
        'other'
    )),

    -- Berechnung
    calculation_basis VARCHAR(20) CHECK (calculation_basis IN (
        'percentage',  -- Prozentsatz
        'fixed',       -- Fixer Betrag
        'tiered'       -- Staffel
    )),
    rate DECIMAL(10,6),  -- Prozentsatz (z.B. 0.005 = 0.5%)

    -- Beträge
    base_amount DECIMAL(15,2),  -- Grundbetrag (z.B. Order-Volumen)
    fee_amount DECIMAL(15,2) NOT NULL,  -- Gebührenbetrag

    -- Grenzen
    min_fee DECIMAL(15,2),
    max_fee DECIMAL(15,2),

    -- Beschreibung
    description VARCHAR(200),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE order_fees IS 'Detaillierte Gebührenaufschlüsselung pro Order';

-- Index
CREATE INDEX IF NOT EXISTS idx_order_fees_order ON order_fees(order_id);

-- ============================================================================
-- 4. TRADES
-- ============================================================================
-- Trades (kombiniert Buy und Sell Orders)

CREATE TABLE IF NOT EXISTS trades (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    trade_number INTEGER NOT NULL UNIQUE,  -- Fortlaufende Nummer

    -- Beziehungen
    trader_id UUID NOT NULL REFERENCES users(id),
    buy_order_id BIGINT NOT NULL REFERENCES orders(id),

    -- Wertpapier-Snapshot
    symbol VARCHAR(50) NOT NULL,
    security_name VARCHAR(200),
    security_type VARCHAR(30),
    wkn VARCHAR(6),

    -- Mengen
    quantity DECIMAL(15,4) NOT NULL,
    sold_quantity DECIMAL(15,4) DEFAULT 0,
    remaining_quantity DECIMAL(15,4),

    -- Preise
    buy_price DECIMAL(15,4) NOT NULL,
    average_sell_price DECIMAL(15,4),
    current_price DECIMAL(15,4),

    -- Beträge
    buy_amount DECIMAL(15,2) NOT NULL,
    sell_amount DECIMAL(15,2),
    gross_profit DECIMAL(15,2),
    net_profit DECIMAL(15,2),
    total_fees DECIMAL(15,2),

    -- Performance
    profit_percentage DECIMAL(10,4),

    -- Status
    status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (status IN (
        'pending',     -- Buy-Order erstellt, noch nicht ausgeführt
        'active',      -- Buy ausgeführt, Position offen
        'partial',     -- Teilweise verkauft
        'completed',   -- Vollständig verkauft
        'cancelled'    -- Storniert
    )),

    -- Zeitstempel
    opened_at TIMESTAMP WITH TIME ZONE,  -- Buy ausgeführt
    closed_at TIMESTAMP WITH TIME ZONE,  -- Vollständig verkauft

    -- Profit berechnet
    profit_calculated BOOLEAN DEFAULT false,
    profit_calculated_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE trades IS 'Trades (Buy + zugehörige Sell Orders)';
COMMENT ON COLUMN trades.remaining_quantity IS 'Noch nicht verkaufte Menge';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trades_trader ON trades(trader_id);
CREATE INDEX IF NOT EXISTS idx_trades_status ON trades(status);
CREATE INDEX IF NOT EXISTS idx_trades_symbol ON trades(symbol);
CREATE INDEX IF NOT EXISTS idx_trades_created ON trades(created_at DESC);

-- Setze FK in orders nach trades erstellt ist
ALTER TABLE orders ADD CONSTRAINT fk_orders_trade
    FOREIGN KEY (trade_id) REFERENCES trades(id) ON DELETE SET NULL;

-- ============================================================================
-- 5. TRADE_AUDIT_LOG
-- ============================================================================
-- Änderungshistorie für Trades

CREATE TABLE IF NOT EXISTS trade_audit_log (
    id BIGSERIAL PRIMARY KEY,
    trade_id BIGINT NOT NULL,  -- Kein FK, Trade könnte gelöscht werden

    -- Änderung
    action VARCHAR(30) NOT NULL CHECK (action IN (
        'created', 'buy_executed', 'sell_added', 'sell_executed',
        'partial_close', 'completed', 'cancelled', 'profit_calculated'
    )),

    -- Vorher/Nachher
    old_status VARCHAR(20),
    new_status VARCHAR(20),
    old_values JSONB,
    new_values JSONB,

    -- Kontext
    order_id BIGINT,  -- Zugehörige Order (falls relevant)

    -- Wer
    changed_by UUID,  -- NULL = System

    -- Wann
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Details
    notes TEXT
);

COMMENT ON TABLE trade_audit_log IS 'Audit-Trail für Trade-Änderungen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_trade_audit_trade ON trade_audit_log(trade_id);
CREATE INDEX IF NOT EXISTS idx_trade_audit_time ON trade_audit_log(changed_at DESC);

-- ============================================================================
-- 6. HOLDINGS
-- ============================================================================
-- Depot-Positionen (aus abgeschlossenen Trades)

CREATE TABLE IF NOT EXISTS holdings (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    position_number VARCHAR(30) NOT NULL UNIQUE,  -- Format: POS-2024-0000001

    -- Beziehungen
    trader_id UUID NOT NULL REFERENCES users(id),
    trade_id BIGINT REFERENCES trades(id),
    security_id INTEGER NOT NULL REFERENCES securities(id),

    -- Wertpapier-Snapshot
    symbol VARCHAR(50) NOT NULL,
    security_name VARCHAR(200),
    wkn VARCHAR(6),

    -- Mengen
    quantity DECIMAL(15,4) NOT NULL,
    remaining_quantity DECIMAL(15,4) NOT NULL,  -- Nach Teilverkäufen

    -- Preise
    purchase_price DECIMAL(15,4) NOT NULL,
    current_price DECIMAL(15,4),

    -- Beträge
    purchase_amount DECIMAL(15,2) NOT NULL,
    current_value DECIMAL(15,2),
    unrealized_profit DECIMAL(15,2),
    unrealized_profit_pct DECIMAL(10,4),

    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active',    -- Aktive Position
        'partial',   -- Teilweise verkauft
        'closed'     -- Vollständig verkauft
    )),

    -- Zeitstempel
    acquired_at TIMESTAMP WITH TIME ZONE NOT NULL,
    last_updated_at TIMESTAMP WITH TIME ZONE,
    closed_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE holdings IS 'Aktuelle Depot-Positionen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_holdings_trader ON holdings(trader_id);
CREATE INDEX IF NOT EXISTS idx_holdings_status ON holdings(status) WHERE status = 'active';
CREATE INDEX IF NOT EXISTS idx_holdings_symbol ON holdings(symbol);

-- ============================================================================
-- 7. MARKET_DATA
-- ============================================================================
-- Aktuelle Marktdaten

CREATE TABLE IF NOT EXISTS market_data (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    symbol VARCHAR(50) NOT NULL,
    exchange VARCHAR(50) NOT NULL DEFAULT 'Xetra',

    -- Preise
    price DECIMAL(15,4) NOT NULL,
    bid DECIMAL(15,4),
    ask DECIMAL(15,4),
    bid_size INTEGER,
    ask_size INTEGER,

    -- Tageswerte
    open DECIMAL(15,4),
    high DECIMAL(15,4),
    low DECIMAL(15,4),
    close DECIMAL(15,4),
    previous_close DECIMAL(15,4),

    -- Veränderung
    change DECIMAL(15,4),
    change_percent DECIMAL(10,4),

    -- Volumen
    volume BIGINT,
    average_volume BIGINT,

    -- Zeitstempel
    timestamp TIMESTAMP WITH TIME ZONE NOT NULL,
    last_trade_time TIMESTAMP WITH TIME ZONE,

    -- Status
    market_status VARCHAR(20) CHECK (market_status IN (
        'pre_market', 'open', 'closed', 'post_market'
    )),

    -- Metadaten
    data_source VARCHAR(50),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(symbol, exchange, timestamp)
);

COMMENT ON TABLE market_data IS 'Aktuelle und historische Marktdaten';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_market_data_symbol ON market_data(symbol, exchange);
CREATE INDEX IF NOT EXISTS idx_market_data_timestamp ON market_data(timestamp DESC);

-- Partitionierung empfohlen für große Datenmengen (nach Monat)
-- CREATE TABLE market_data_2024_01 PARTITION OF market_data
--     FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- ============================================================================
-- 8. PRICE_ALERTS
-- ============================================================================
-- Preisalarme

CREATE TABLE IF NOT EXISTS price_alerts (
    id SERIAL PRIMARY KEY,

    -- Beziehungen
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    security_id INTEGER REFERENCES securities(id),

    -- Wertpapier
    symbol VARCHAR(50) NOT NULL,
    security_name VARCHAR(200),

    -- Alert-Typ
    alert_type VARCHAR(20) NOT NULL CHECK (alert_type IN (
        'above',          -- Preis über Schwelle
        'below',          -- Preis unter Schwelle
        'change_up',      -- Änderung nach oben (%)
        'change_down',    -- Änderung nach unten (%)
        'change_any'      -- Änderung in beliebige Richtung (%)
    )),

    -- Schwellwerte
    threshold_price DECIMAL(15,4),
    threshold_change_percent DECIMAL(10,4),

    -- Referenzpreis (für prozentuale Alerts)
    reference_price DECIMAL(15,4),

    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'active',     -- Aktiv
        'triggered',  -- Ausgelöst
        'cancelled',  -- Storniert
        'expired'     -- Abgelaufen
    )),

    -- Benachrichtigung
    notification_sent BOOLEAN DEFAULT false,
    notification_sent_at TIMESTAMP WITH TIME ZONE,

    -- Wiederholung
    is_repeating BOOLEAN DEFAULT false,
    repeat_interval INTEGER,  -- Minuten zwischen Wiederholungen
    repeat_count INTEGER DEFAULT 0,
    max_repeats INTEGER DEFAULT 1,

    -- Gültigkeit
    expires_at TIMESTAMP WITH TIME ZONE,

    -- Notizen
    notes TEXT,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    triggered_at TIMESTAMP WITH TIME ZONE,
    triggered_price DECIMAL(15,4)
);

COMMENT ON TABLE price_alerts IS 'Benutzer-Preisalarme';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_price_alerts_user ON price_alerts(user_id);
CREATE INDEX IF NOT EXISTS idx_price_alerts_active
    ON price_alerts(symbol, status) WHERE status = 'active';

-- ============================================================================
-- 9. PRICE_ALERT_HISTORY
-- ============================================================================
-- Historie ausgelöster Alarme

CREATE TABLE IF NOT EXISTS price_alert_history (
    id BIGSERIAL PRIMARY KEY,

    -- Referenz
    alert_id INTEGER REFERENCES price_alerts(id) ON DELETE SET NULL,
    user_id UUID NOT NULL,

    -- Snapshot des Alerts
    symbol VARCHAR(50) NOT NULL,
    alert_type VARCHAR(20) NOT NULL,
    threshold_price DECIMAL(15,4),
    threshold_change_percent DECIMAL(10,4),

    -- Auslösung
    triggered_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    triggered_price DECIMAL(15,4) NOT NULL,
    price_at_trigger DECIMAL(15,4),

    -- Benachrichtigung
    notification_sent BOOLEAN DEFAULT false,
    notification_channels TEXT[],

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE price_alert_history IS 'Historie aller ausgelösten Preisalarme';

-- Index
CREATE INDEX IF NOT EXISTS idx_price_alert_history_user ON price_alert_history(user_id);

-- ============================================================================
-- 10. TRADER_WATCHLIST
-- ============================================================================
-- Watchlist für Securities (pro Trader)

CREATE TABLE IF NOT EXISTS trader_watchlist (
    id SERIAL PRIMARY KEY,

    -- Besitzer
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Details
    name VARCHAR(100) NOT NULL DEFAULT 'Watchlist',
    description TEXT,

    -- Sortierung
    sort_order INTEGER DEFAULT 0,

    -- Status
    is_default BOOLEAN DEFAULT false,
    is_active BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Nur eine Default-Watchlist pro User
    UNIQUE(user_id, is_default) WHERE is_default = true
);

COMMENT ON TABLE trader_watchlist IS 'Watchlists für Trader (Wertpapier-Beobachtung)';

-- Index
CREATE INDEX IF NOT EXISTS idx_trader_watchlist_user ON trader_watchlist(user_id);

-- ============================================================================
-- 11. WATCHLIST_ITEMS
-- ============================================================================
-- Einträge in Watchlists

CREATE TABLE IF NOT EXISTS watchlist_items (
    id SERIAL PRIMARY KEY,

    -- Beziehungen
    watchlist_id INTEGER NOT NULL REFERENCES trader_watchlist(id) ON DELETE CASCADE,
    security_id INTEGER REFERENCES securities(id),

    -- Wertpapier
    symbol VARCHAR(50) NOT NULL,
    security_name VARCHAR(200),

    -- Position in Liste
    sort_order INTEGER DEFAULT 0,

    -- Notizen
    notes TEXT,
    target_price DECIMAL(15,4),

    -- Metadaten
    added_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(watchlist_id, symbol)
);

COMMENT ON TABLE watchlist_items IS 'Einzelne Wertpapiere in Watchlists';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_watchlist_items_watchlist ON watchlist_items(watchlist_id);
CREATE INDEX IF NOT EXISTS idx_watchlist_items_symbol ON watchlist_items(symbol);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Aktive Trades mit aktuellen Preisen
CREATE OR REPLACE VIEW v_active_trades AS
SELECT
    t.*,
    s.name AS security_full_name,
    s.isin,
    md.price AS current_market_price,
    md.change AS price_change,
    md.change_percent AS price_change_pct,
    (t.quantity - COALESCE(t.sold_quantity, 0)) AS open_quantity,
    ((md.price - t.buy_price) * (t.quantity - COALESCE(t.sold_quantity, 0))) AS unrealized_pnl
FROM trades t
LEFT JOIN securities s ON t.symbol = s.symbol
LEFT JOIN LATERAL (
    SELECT * FROM market_data
    WHERE symbol = t.symbol
    ORDER BY timestamp DESC
    LIMIT 1
) md ON true
WHERE t.status IN ('active', 'partial');

-- Depot-Übersicht pro Trader
CREATE OR REPLACE VIEW v_portfolio_summary AS
SELECT
    h.trader_id,
    COUNT(*) AS position_count,
    SUM(h.purchase_amount) AS total_invested,
    SUM(h.current_value) AS total_current_value,
    SUM(h.unrealized_profit) AS total_unrealized_pnl,
    CASE
        WHEN SUM(h.purchase_amount) > 0
        THEN (SUM(h.unrealized_profit) / SUM(h.purchase_amount)) * 100
        ELSE 0
    END AS total_return_pct
FROM holdings h
WHERE h.status = 'active'
GROUP BY h.trader_id;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER securities_updated_at
    BEFORE UPDATE ON securities
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trades_updated_at
    BEFORE UPDATE ON trades
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER holdings_updated_at
    BEFORE UPDATE ON holdings
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER price_alerts_updated_at
    BEFORE UPDATE ON price_alerts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trader_watchlist_updated_at
    BEFORE UPDATE ON trader_watchlist
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trade Audit Trigger
CREATE OR REPLACE FUNCTION log_trade_change()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO trade_audit_log (trade_id, action, new_status, new_values)
        VALUES (NEW.id, 'created', NEW.status, to_jsonb(NEW));
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.status != NEW.status THEN
            INSERT INTO trade_audit_log (trade_id, action, old_status, new_status, old_values, new_values)
            VALUES (NEW.id,
                CASE
                    WHEN NEW.status = 'active' THEN 'buy_executed'
                    WHEN NEW.status = 'completed' THEN 'completed'
                    WHEN NEW.status = 'cancelled' THEN 'cancelled'
                    ELSE 'status_change'
                END,
                OLD.status, NEW.status, to_jsonb(OLD), to_jsonb(NEW));
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trades_audit_trigger
    AFTER INSERT OR UPDATE ON trades
    FOR EACH ROW EXECUTE FUNCTION log_trade_change();

-- ============================================================================
-- END OF 005_schema_trading.sql
-- ============================================================================
