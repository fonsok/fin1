-- ============================================================================
-- DATABASE SCHEMA
-- 007_schema_finance.sql - Finance & Documents
-- ============================================================================
--
-- Dieses Schema verwaltet alle finanziellen Dokumente und Transaktionen:
-- Rechnungen, Wallet-Transaktionen, Dokumente und Kontoauszüge.
--
-- Tabellen (9):
--   1. invoices                - Rechnungen und Gutschriften
--   2. invoice_items           - Einzelposten auf Rechnungen
--   3. wallet_transactions     - Wallet-Transaktionen
--   4. transaction_limits      - Transaktionslimits
--   5. transaction_limit_usage - Aktuelle Limit-Nutzung
--   6. documents               - Alle Dokumente
--   7. document_versions       - Dokumentversionen
--   8. account_statements      - Kontoauszüge
--   9. statement_entries       - Einzelposten auf Kontoauszügen
--
-- ============================================================================

-- ============================================================================
-- 1. INVOICES
-- ============================================================================
-- Rechnungen, Gutschriften und Abrechnungen

CREATE TABLE IF NOT EXISTS invoices (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    invoice_number VARCHAR(30) NOT NULL UNIQUE,  -- Format: INV-2024-0000001

    -- Typ
    invoice_type VARCHAR(30) NOT NULL CHECK (invoice_type IN (
        'buy',                  -- Kaufabrechnung
        'sell',                 -- Verkaufsabrechnung
        'credit_note',          -- Gutschrift (Provision)
        'collection_bill',      -- Sammelabrechnung
        'service_charge',       -- Service-Gebühr
        'fee_invoice',          -- Gebührenrechnung
        'correction'            -- Korrekturrechnung
    )),

    -- Beziehungen
    user_id UUID NOT NULL REFERENCES users(id),
    order_id BIGINT REFERENCES orders(id),
    trade_id BIGINT REFERENCES trades(id),
    investment_id BIGINT REFERENCES investments(id),

    -- Kunde (Snapshot)
    customer_name VARCHAR(200) NOT NULL,
    customer_address TEXT,
    customer_email VARCHAR(255),
    customer_id VARCHAR(20),  -- Kundennummer

    -- Beträge
    subtotal DECIMAL(15,2) NOT NULL,
    tax_amount DECIMAL(15,2) DEFAULT 0,
    tax_rate DECIMAL(5,2) DEFAULT 0,  -- z.B. 19.00 für 19%
    total_amount DECIMAL(15,2) NOT NULL,

    -- Währung
    currency VARCHAR(3) DEFAULT 'EUR',

    -- Datum
    invoice_date DATE NOT NULL DEFAULT CURRENT_DATE,
    due_date DATE,
    period_start DATE,  -- Für Sammelabrechnungen
    period_end DATE,

    -- Status
    status VARCHAR(20) DEFAULT 'draft' CHECK (status IN (
        'draft',      -- Entwurf
        'issued',     -- Ausgestellt
        'sent',       -- Versendet
        'paid',       -- Bezahlt
        'cancelled',  -- Storniert
        'refunded'    -- Erstattet
    )),

    -- PDF
    pdf_url TEXT,
    pdf_generated_at TIMESTAMP WITH TIME ZONE,

    -- Referenzen
    original_invoice_id BIGINT REFERENCES invoices(id),  -- Für Korrekturen

    -- Notizen
    notes TEXT,
    internal_notes TEXT,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT invoice_number_format CHECK (
        invoice_number ~ '^(INV|CN|CB|SC)-[0-9]{4}-[0-9]{7}$'
    )
);

COMMENT ON TABLE invoices IS 'Rechnungen, Gutschriften und Abrechnungen';
COMMENT ON COLUMN invoices.invoice_type IS 'buy=Kauf, sell=Verkauf, credit_note=Gutschrift, collection_bill=Sammelabrechnung';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_invoices_user ON invoices(user_id);
CREATE INDEX IF NOT EXISTS idx_invoices_order ON invoices(order_id) WHERE order_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invoices_trade ON invoices(trade_id) WHERE trade_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_invoices_type ON invoices(invoice_type);
CREATE INDEX IF NOT EXISTS idx_invoices_date ON invoices(invoice_date DESC);

-- ============================================================================
-- 2. INVOICE_ITEMS
-- ============================================================================
-- Einzelposten auf Rechnungen

CREATE TABLE IF NOT EXISTS invoice_items (
    id SERIAL PRIMARY KEY,
    invoice_id BIGINT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,

    -- Position
    position_number INTEGER NOT NULL,

    -- Beschreibung
    description TEXT NOT NULL,
    description_detail TEXT,

    -- Mengen und Preise
    quantity DECIMAL(15,4) DEFAULT 1,
    unit_price DECIMAL(15,4) NOT NULL,
    unit VARCHAR(20) DEFAULT 'Stück',

    -- Beträge
    subtotal DECIMAL(15,2) NOT NULL,
    tax_rate DECIMAL(5,2) DEFAULT 0,
    tax_amount DECIMAL(15,2) DEFAULT 0,
    total DECIMAL(15,2) NOT NULL,

    -- Kategorisierung
    item_type VARCHAR(30) CHECK (item_type IN (
        'security',       -- Wertpapier
        'fee',            -- Gebühr
        'commission',     -- Provision
        'service_charge', -- Service-Gebühr
        'tax',            -- Steuer
        'adjustment',     -- Anpassung
        'other'
    )),

    -- Referenzen
    security_symbol VARCHAR(50),
    security_name VARCHAR(200),

    -- Sortierung
    sort_order INTEGER DEFAULT 0,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE invoice_items IS 'Einzelposten auf Rechnungen';

-- Index
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);

-- ============================================================================
-- 3. WALLET_TRANSACTIONS
-- ============================================================================
-- Alle Wallet-Transaktionen (Ein- und Auszahlungen, Trades, etc.)

CREATE TABLE IF NOT EXISTS wallet_transactions (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    transaction_number VARCHAR(30) NOT NULL UNIQUE,  -- Format: TXN-2024-0000001

    -- Beziehungen
    user_id UUID NOT NULL REFERENCES users(id),

    -- Typ
    transaction_type VARCHAR(30) NOT NULL CHECK (transaction_type IN (
        'deposit',              -- Einzahlung
        'withdrawal',           -- Auszahlung
        'trade_buy',            -- Kauf (Belastung)
        'trade_sell',           -- Verkauf (Gutschrift)
        'investment',           -- Investment (Belastung)
        'investment_return',    -- Investment-Rückzahlung
        'profit_distribution',  -- Gewinnausschüttung
        'commission_credit',    -- Provision (Trader)
        'commission_debit',     -- Provision (Investor)
        'service_charge',       -- Service-Gebühr
        'fee',                  -- Sonstige Gebühr
        'adjustment',           -- Korrektur
        'transfer_in',          -- Übertrag rein
        'transfer_out',         -- Übertrag raus
        'refund'                -- Erstattung
    )),

    -- Beträge
    amount DECIMAL(15,2) NOT NULL,
    balance_before DECIMAL(15,2),
    balance_after DECIMAL(15,2),

    -- Währung
    currency VARCHAR(3) DEFAULT 'EUR',

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',      -- Ausstehend
        'processing',   -- In Bearbeitung
        'completed',    -- Abgeschlossen
        'failed',       -- Fehlgeschlagen
        'cancelled',    -- Storniert
        'reversed'      -- Rückgebucht
    )),
    status_message TEXT,

    -- Referenzen
    reference_type VARCHAR(30),  -- 'order', 'trade', 'investment', 'invoice'
    reference_id VARCHAR(100),

    -- Beschreibung
    description TEXT,

    -- Externe Referenzen (für Banktransaktionen)
    external_reference VARCHAR(100),
    bank_reference VARCHAR(100),

    -- Zeitstempel
    transaction_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    value_date DATE,  -- Wertstellungsdatum
    completed_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE wallet_transactions IS 'Alle Wallet-Transaktionen';
COMMENT ON COLUMN wallet_transactions.value_date IS 'Wertstellungsdatum für Buchung';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_wallet_tx_user ON wallet_transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_type ON wallet_transactions(transaction_type);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_status ON wallet_transactions(status);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_date ON wallet_transactions(transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_wallet_tx_reference
    ON wallet_transactions(reference_type, reference_id)
    WHERE reference_type IS NOT NULL;

-- ============================================================================
-- 4. TRANSACTION_LIMITS
-- ============================================================================
-- Transaktionslimits pro User (basierend auf Risikoklasse)

CREATE TABLE IF NOT EXISTS transaction_limits (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Basis-Limits
    daily_limit DECIMAL(15,2) NOT NULL DEFAULT 10000,
    weekly_limit DECIMAL(15,2) NOT NULL DEFAULT 50000,
    monthly_limit DECIMAL(15,2) NOT NULL DEFAULT 200000,

    -- Einzeltransaktionslimit
    single_transaction_limit DECIMAL(15,2) DEFAULT 50000,

    -- Risikoklassen-basierte Limits
    risk_class INTEGER,
    risk_multiplier DECIMAL(5,2) DEFAULT 1.0,

    -- Berechnete effektive Limits
    effective_daily_limit DECIMAL(15,2),
    effective_weekly_limit DECIMAL(15,2),
    effective_monthly_limit DECIMAL(15,2),

    -- Override (für manuelle Anpassungen)
    has_custom_limits BOOLEAN DEFAULT false,
    custom_limit_reason TEXT,
    custom_limit_approved_by UUID,
    custom_limit_approved_at TIMESTAMP WITH TIME ZONE,

    -- Gültigkeit
    valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valid_until TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE transaction_limits IS 'Transaktionslimits pro User';
COMMENT ON COLUMN transaction_limits.risk_multiplier IS 'Multiplikator basierend auf Risikoklasse';

-- ============================================================================
-- 5. TRANSACTION_LIMIT_USAGE
-- ============================================================================
-- Aktuelle Nutzung der Transaktionslimits

CREATE TABLE IF NOT EXISTS transaction_limit_usage (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Aktuelle Nutzung
    daily_used DECIMAL(15,2) DEFAULT 0,
    weekly_used DECIMAL(15,2) DEFAULT 0,
    monthly_used DECIMAL(15,2) DEFAULT 0,

    -- Perioden
    daily_period_start DATE DEFAULT CURRENT_DATE,
    weekly_period_start DATE,
    monthly_period_start DATE,

    -- Letzte Aktualisierung
    last_transaction_at TIMESTAMP WITH TIME ZONE,
    last_reset_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id)
);

COMMENT ON TABLE transaction_limit_usage IS 'Aktuelle Nutzung der Transaktionslimits';

-- Index
CREATE INDEX IF NOT EXISTS idx_limit_usage_user ON transaction_limit_usage(user_id);

-- ============================================================================
-- 6. DOCUMENTS
-- ============================================================================
-- Alle Dokumente (PDFs, Uploads, etc.)

CREATE TABLE IF NOT EXISTS documents (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    document_number VARCHAR(30) UNIQUE,  -- Optional

    -- Beziehungen
    user_id UUID NOT NULL REFERENCES users(id),

    -- Dokumenttyp
    document_type VARCHAR(50) NOT NULL CHECK (document_type IN (
        -- Trading
        'buy_invoice',
        'sell_invoice',
        'trade_statement',
        'collection_bill',

        -- Investment
        'investment_confirmation',
        'credit_note',

        -- Account
        'account_statement',
        'monthly_statement',
        'annual_statement',
        'tax_certificate',

        -- KYC
        'kyc_document',
        'identity_proof',
        'address_proof',

        -- Legal
        'terms_acceptance',
        'risk_disclosure',

        -- Support
        'support_attachment',

        -- Other
        'other'
    )),

    -- Datei
    file_name VARCHAR(255) NOT NULL,
    file_type VARCHAR(50),  -- MIME type
    file_size BIGINT,
    file_url TEXT NOT NULL,
    file_hash VARCHAR(64),  -- SHA256 für Integrität

    -- Beschreibung
    title VARCHAR(200),
    description TEXT,

    -- Referenzen
    reference_type VARCHAR(30),  -- 'invoice', 'trade', 'investment', 'ticket'
    reference_id VARCHAR(100),

    -- Perioden (für Statements)
    period_year INTEGER,
    period_month INTEGER,

    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'draft',      -- Entwurf
        'active',     -- Aktiv
        'archived',   -- Archiviert
        'deleted'     -- Gelöscht
    )),

    -- Zugriff
    is_public BOOLEAN DEFAULT false,
    access_count INTEGER DEFAULT 0,
    last_accessed_at TIMESTAMP WITH TIME ZONE,
    downloaded_at TIMESTAMP WITH TIME ZONE,

    -- Benachrichtigung
    notification_sent BOOLEAN DEFAULT false,
    notification_sent_at TIMESTAMP WITH TIME ZONE,

    -- Aufbewahrung
    retention_until DATE,

    -- Metadaten
    metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE documents IS 'Alle Dokumente (PDFs, Uploads)';
COMMENT ON COLUMN documents.file_hash IS 'SHA256 Hash für Integritätsprüfung';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_documents_user ON documents(user_id);
CREATE INDEX IF NOT EXISTS idx_documents_type ON documents(document_type);
CREATE INDEX IF NOT EXISTS idx_documents_reference
    ON documents(reference_type, reference_id)
    WHERE reference_type IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_documents_period
    ON documents(period_year, period_month)
    WHERE period_year IS NOT NULL;

-- ============================================================================
-- 7. DOCUMENT_VERSIONS
-- ============================================================================
-- Versionshistorie für Dokumente

CREATE TABLE IF NOT EXISTS document_versions (
    id SERIAL PRIMARY KEY,
    document_id BIGINT NOT NULL REFERENCES documents(id) ON DELETE CASCADE,

    -- Version
    version_number INTEGER NOT NULL,

    -- Datei
    file_url TEXT NOT NULL,
    file_hash VARCHAR(64),
    file_size BIGINT,

    -- Änderungsgrund
    change_reason TEXT,

    -- Wer
    created_by UUID,

    -- Wann
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(document_id, version_number)
);

COMMENT ON TABLE document_versions IS 'Versionshistorie für Dokumente';

-- Index
CREATE INDEX IF NOT EXISTS idx_document_versions_doc ON document_versions(document_id);

-- ============================================================================
-- 8. ACCOUNT_STATEMENTS
-- ============================================================================
-- Kontoauszüge (monatlich/jährlich)

CREATE TABLE IF NOT EXISTS account_statements (
    id BIGSERIAL PRIMARY KEY,

    -- Identifikation
    statement_number VARCHAR(30) NOT NULL UNIQUE,

    -- Beziehungen
    user_id UUID NOT NULL REFERENCES users(id),
    document_id BIGINT REFERENCES documents(id),

    -- Periode
    period_type VARCHAR(10) NOT NULL CHECK (period_type IN ('monthly', 'quarterly', 'annual')),
    period_year INTEGER NOT NULL,
    period_month INTEGER,  -- NULL für annual
    period_quarter INTEGER,  -- NULL für monthly/annual
    period_start DATE NOT NULL,
    period_end DATE NOT NULL,

    -- Salden
    opening_balance DECIMAL(15,2) NOT NULL,
    closing_balance DECIMAL(15,2) NOT NULL,

    -- Zusammenfassung
    total_deposits DECIMAL(15,2) DEFAULT 0,
    total_withdrawals DECIMAL(15,2) DEFAULT 0,
    total_trades_buy DECIMAL(15,2) DEFAULT 0,
    total_trades_sell DECIMAL(15,2) DEFAULT 0,
    total_fees DECIMAL(15,2) DEFAULT 0,
    total_commissions DECIMAL(15,2) DEFAULT 0,
    net_profit_loss DECIMAL(15,2) DEFAULT 0,

    -- Anzahl
    transaction_count INTEGER DEFAULT 0,

    -- Status
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN (
        'pending',    -- Wird generiert
        'generated',  -- Generiert
        'sent',       -- An User gesendet
        'error'       -- Fehler bei Generierung
    )),

    -- Generierung
    generated_at TIMESTAMP WITH TIME ZONE,
    generation_error TEXT,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(user_id, period_type, period_year, COALESCE(period_month, 0), COALESCE(period_quarter, 0))
);

COMMENT ON TABLE account_statements IS 'Kontoauszüge (monatlich/quartalsweise/jährlich)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_account_statements_user ON account_statements(user_id);
CREATE INDEX IF NOT EXISTS idx_account_statements_period
    ON account_statements(period_year, period_month);

-- ============================================================================
-- 9. STATEMENT_ENTRIES
-- ============================================================================
-- Einzelposten auf Kontoauszügen

CREATE TABLE IF NOT EXISTS statement_entries (
    id BIGSERIAL PRIMARY KEY,
    statement_id BIGINT NOT NULL REFERENCES account_statements(id) ON DELETE CASCADE,

    -- Sortierung
    entry_number INTEGER NOT NULL,
    entry_date DATE NOT NULL,
    value_date DATE,

    -- Buchung
    booking_type VARCHAR(30) NOT NULL,  -- Entspricht wallet_transactions.transaction_type
    description TEXT NOT NULL,

    -- Beträge
    debit_amount DECIMAL(15,2),  -- Belastung
    credit_amount DECIMAL(15,2),  -- Gutschrift
    balance_after DECIMAL(15,2),

    -- Referenz
    transaction_id BIGINT REFERENCES wallet_transactions(id),
    reference VARCHAR(100),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE statement_entries IS 'Einzelposten auf Kontoauszügen';

-- Index
CREATE INDEX IF NOT EXISTS idx_statement_entries_statement ON statement_entries(statement_id);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Wallet-Übersicht pro User
CREATE OR REPLACE VIEW v_wallet_balance AS
SELECT
    user_id,
    COALESCE(
        (SELECT balance_after
         FROM wallet_transactions
         WHERE user_id = wt.user_id
         AND status = 'completed'
         ORDER BY completed_at DESC, id DESC
         LIMIT 1),
        0
    ) AS current_balance,
    SUM(CASE WHEN transaction_type = 'deposit' AND status = 'completed' THEN amount ELSE 0 END) AS total_deposits,
    SUM(CASE WHEN transaction_type = 'withdrawal' AND status = 'completed' THEN amount ELSE 0 END) AS total_withdrawals,
    COUNT(*) AS transaction_count
FROM wallet_transactions wt
GROUP BY user_id;

-- Rechnungs-Übersicht
CREATE OR REPLACE VIEW v_invoice_summary AS
SELECT
    user_id,
    invoice_type,
    COUNT(*) AS invoice_count,
    SUM(total_amount) AS total_amount,
    MIN(invoice_date) AS first_invoice_date,
    MAX(invoice_date) AS last_invoice_date
FROM invoices
WHERE status != 'cancelled'
GROUP BY user_id, invoice_type;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER invoices_updated_at
    BEFORE UPDATE ON invoices
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER wallet_transactions_updated_at
    BEFORE UPDATE ON wallet_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER transaction_limits_updated_at
    BEFORE UPDATE ON transaction_limits
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER documents_updated_at
    BEFORE UPDATE ON documents
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER account_statements_updated_at
    BEFORE UPDATE ON account_statements
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Trigger zum Aktualisieren der Limit-Nutzung
CREATE OR REPLACE FUNCTION update_limit_usage()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        -- Nur bei bestimmten Transaktionstypen
        IF NEW.transaction_type IN ('withdrawal', 'investment', 'trade_buy') THEN
            INSERT INTO transaction_limit_usage (user_id, daily_used, weekly_used, monthly_used, last_transaction_at)
            VALUES (NEW.user_id, ABS(NEW.amount), ABS(NEW.amount), ABS(NEW.amount), NOW())
            ON CONFLICT (user_id) DO UPDATE SET
                daily_used = CASE
                    WHEN transaction_limit_usage.daily_period_start = CURRENT_DATE
                    THEN transaction_limit_usage.daily_used + ABS(NEW.amount)
                    ELSE ABS(NEW.amount)
                END,
                weekly_used = transaction_limit_usage.weekly_used + ABS(NEW.amount),
                monthly_used = transaction_limit_usage.monthly_used + ABS(NEW.amount),
                daily_period_start = CURRENT_DATE,
                last_transaction_at = NOW(),
                updated_at = NOW();
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wallet_tx_limit_usage
    AFTER UPDATE ON wallet_transactions
    FOR EACH ROW EXECUTE FUNCTION update_limit_usage();

-- ============================================================================
-- END OF 007_schema_finance.sql
-- ============================================================================
