-- ============================================================================
-- FIN1 DATABASE SCHEMA
-- 015_functions.sql - Stored Procedures & Business Logic Functions
-- ============================================================================
--
-- Wiederverwendbare Funktionen für:
--   1. ID-Generierung
--   2. Business Logic
--   3. Berechnungen
--   4. Utility Functions
--
-- ============================================================================

-- ============================================================================
-- ID GENERATION FUNCTIONS
-- ============================================================================

-- Generate Customer ID (INV-2024-00001 or TRD-2024-00001)
CREATE OR REPLACE FUNCTION generate_customer_id(p_role VARCHAR)
RETURNS VARCHAR AS $$
DECLARE
    v_prefix VARCHAR(3);
    v_year VARCHAR(4);
    v_sequence INTEGER;
    v_customer_id VARCHAR(20);
BEGIN
    -- Bestimme Prefix
    v_prefix := CASE p_role
        WHEN 'investor' THEN 'INV'
        WHEN 'trader' THEN 'TRD'
        WHEN 'admin' THEN 'ADM'
        WHEN 'customer_service' THEN 'CSR'
        ELSE 'USR'
    END;

    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');

    -- Hole nächste Sequenznummer
    SELECT COALESCE(MAX(
        CAST(SUBSTRING(customer_id FROM v_prefix || '-' || v_year || '-(.*)') AS INTEGER)
    ), 0) + 1
    INTO v_sequence
    FROM users
    WHERE customer_id LIKE v_prefix || '-' || v_year || '-%';

    v_customer_id := v_prefix || '-' || v_year || '-' || LPAD(v_sequence::TEXT, 5, '0');

    RETURN v_customer_id;
END;
$$ LANGUAGE plpgsql;

-- Generate generic sequential number
CREATE OR REPLACE FUNCTION generate_sequential_number(
    p_prefix VARCHAR,
    p_table_name VARCHAR,
    p_column_name VARCHAR
)
RETURNS VARCHAR AS $$
DECLARE
    v_year VARCHAR(4);
    v_sequence INTEGER;
    v_number VARCHAR(30);
    v_query TEXT;
BEGIN
    v_year := TO_CHAR(CURRENT_DATE, 'YYYY');

    -- Dynamische Query für verschiedene Tabellen
    v_query := format(
        'SELECT COALESCE(MAX(
            CAST(SUBSTRING(%I FROM %L || ''-'' || %L || ''-(.*)'') AS INTEGER)
        ), 0) + 1 FROM %I WHERE %I LIKE %L',
        p_column_name,
        p_prefix, v_year,
        p_table_name, p_column_name,
        p_prefix || '-' || v_year || '-%'
    );

    EXECUTE v_query INTO v_sequence;

    v_number := p_prefix || '-' || v_year || '-' || LPAD(v_sequence::TEXT, 7, '0');

    RETURN v_number;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- WALLET FUNCTIONS
-- ============================================================================

-- Get current wallet balance for a user
CREATE OR REPLACE FUNCTION get_wallet_balance(p_user_id UUID)
RETURNS DECIMAL AS $$
DECLARE
    v_balance DECIMAL(15,2);
BEGIN
    SELECT COALESCE(balance_after, 0)
    INTO v_balance
    FROM wallet_transactions
    WHERE user_id = p_user_id AND status = 'completed'
    ORDER BY completed_at DESC, id DESC
    LIMIT 1;

    RETURN COALESCE(v_balance, 0);
END;
$$ LANGUAGE plpgsql STABLE;

-- Process wallet transaction
CREATE OR REPLACE FUNCTION process_wallet_transaction(
    p_user_id UUID,
    p_type VARCHAR,
    p_amount DECIMAL,
    p_description TEXT DEFAULT NULL,
    p_reference_type VARCHAR DEFAULT NULL,
    p_reference_id VARCHAR DEFAULT NULL
)
RETURNS BIGINT AS $$
DECLARE
    v_balance_before DECIMAL;
    v_balance_after DECIMAL;
    v_tx_id BIGINT;
    v_tx_number VARCHAR(30);
BEGIN
    -- Hole aktuelle Balance
    v_balance_before := get_wallet_balance(p_user_id);

    -- Berechne neue Balance
    IF p_type IN ('deposit', 'trade_sell', 'profit_distribution', 'commission_credit', 'refund', 'investment_return') THEN
        v_balance_after := v_balance_before + ABS(p_amount);
    ELSE
        v_balance_after := v_balance_before - ABS(p_amount);
    END IF;

    -- Prüfe auf negative Balance
    IF v_balance_after < 0 THEN
        RAISE EXCEPTION 'Insufficient balance';
    END IF;

    -- Generiere Transaktionsnummer
    v_tx_number := generate_sequential_number('TXN', 'wallet_transactions', 'transaction_number');

    -- Erstelle Transaktion
    INSERT INTO wallet_transactions (
        transaction_number, user_id, transaction_type, amount,
        balance_before, balance_after, status, description,
        reference_type, reference_id, completed_at
    ) VALUES (
        v_tx_number, p_user_id, p_type, p_amount,
        v_balance_before, v_balance_after, 'completed', p_description,
        p_reference_type, p_reference_id, NOW()
    )
    RETURNING id INTO v_tx_id;

    RETURN v_tx_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- INVESTMENT FUNCTIONS
-- ============================================================================

-- Calculate investment value with profits
CREATE OR REPLACE FUNCTION calculate_investment_value(p_investment_id BIGINT)
RETURNS TABLE (
    current_value DECIMAL,
    total_profit DECIMAL,
    profit_percentage DECIMAL,
    commission_paid DECIMAL
) AS $$
DECLARE
    v_initial_amount DECIMAL;
BEGIN
    SELECT i.amount INTO v_initial_amount FROM investments i WHERE i.id = p_investment_id;

    RETURN QUERY
    SELECT
        v_initial_amount + COALESCE(SUM(ptp.profit_share - COALESCE(ptp.loss_share, 0)), 0) AS current_value,
        COALESCE(SUM(ptp.profit_share - COALESCE(ptp.loss_share, 0)), 0) AS total_profit,
        CASE
            WHEN v_initial_amount > 0
            THEN COALESCE(SUM(ptp.profit_share - COALESCE(ptp.loss_share, 0)), 0) / v_initial_amount * 100
            ELSE 0
        END AS profit_percentage,
        COALESCE(SUM(ptp.commission_amount), 0) AS commission_paid
    FROM pool_trade_participations ptp
    WHERE ptp.investment_id = p_investment_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Distribute profit to investment pools
CREATE OR REPLACE FUNCTION distribute_trade_profit(
    p_trade_id BIGINT,
    p_gross_profit DECIMAL
)
RETURNS INTEGER AS $$
DECLARE
    v_participation RECORD;
    v_total_allocated DECIMAL;
    v_commission_rate DECIMAL := 0.05;  -- 5% default
    v_profit_share DECIMAL;
    v_commission DECIMAL;
    v_distributions INTEGER := 0;
BEGIN
    -- Hole Gesamtallokation
    SELECT COALESCE(SUM(allocated_amount), 0) INTO v_total_allocated
    FROM pool_trade_participations
    WHERE trade_id = p_trade_id;

    IF v_total_allocated = 0 THEN
        RETURN 0;
    END IF;

    -- Verteile Profit proportional
    FOR v_participation IN
        SELECT ptp.*, i.investor_id
        FROM pool_trade_participations ptp
        JOIN investments i ON ptp.investment_id = i.id
        WHERE ptp.trade_id = p_trade_id AND ptp.is_settled = false
    LOOP
        -- Berechne Anteil
        v_profit_share := p_gross_profit * (v_participation.allocated_amount / v_total_allocated);
        v_commission := v_profit_share * v_commission_rate;

        -- Update Partizipation
        UPDATE pool_trade_participations
        SET
            profit_share = v_profit_share,
            commission_amount = v_commission,
            commission_rate = v_commission_rate,
            gross_return = v_profit_share - v_commission,
            is_settled = true,
            settled_at = NOW()
        WHERE id = v_participation.id;

        -- Update Investment
        UPDATE investments
        SET
            current_value = current_value + (v_profit_share - v_commission),
            profit = profit + (v_profit_share - v_commission),
            total_commission_paid = total_commission_paid + v_commission,
            updated_at = NOW()
        WHERE id = v_participation.investment_id;

        v_distributions := v_distributions + 1;
    END LOOP;

    RETURN v_distributions;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRADING FUNCTIONS
-- ============================================================================

-- Calculate order fees
CREATE OR REPLACE FUNCTION calculate_order_fees(
    p_order_amount DECIMAL,
    p_is_foreign BOOLEAN DEFAULT false
)
RETURNS TABLE (
    order_fee DECIMAL,
    exchange_fee DECIMAL,
    foreign_costs DECIMAL,
    total_fees DECIMAL
) AS $$
DECLARE
    v_order_fee_rate DECIMAL := 0.005;  -- 0.5%
    v_order_fee_min DECIMAL := 5.0;
    v_order_fee_max DECIMAL := 50.0;
    v_exchange_fee_rate DECIMAL := 0.001;  -- 0.1%
    v_exchange_fee_min DECIMAL := 1.0;
    v_exchange_fee_max DECIMAL := 20.0;
    v_foreign_costs DECIMAL := 1.50;
    v_order_fee DECIMAL;
    v_exchange_fee DECIMAL;
BEGIN
    -- Order Fee
    v_order_fee := GREATEST(v_order_fee_min, LEAST(p_order_amount * v_order_fee_rate, v_order_fee_max));

    -- Exchange Fee
    v_exchange_fee := GREATEST(v_exchange_fee_min, LEAST(p_order_amount * v_exchange_fee_rate, v_exchange_fee_max));

    RETURN QUERY
    SELECT
        v_order_fee AS order_fee,
        v_exchange_fee AS exchange_fee,
        CASE WHEN p_is_foreign THEN v_foreign_costs ELSE 0::DECIMAL END AS foreign_costs,
        v_order_fee + v_exchange_fee + CASE WHEN p_is_foreign THEN v_foreign_costs ELSE 0::DECIMAL END AS total_fees;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- RISK ASSESSMENT FUNCTIONS
-- ============================================================================

-- Calculate risk class based on experience
CREATE OR REPLACE FUNCTION calculate_risk_class(
    p_experience_score INTEGER,
    p_knowledge_score INTEGER,
    p_frequency_score INTEGER,
    p_desired_return VARCHAR
)
RETURNS INTEGER AS $$
DECLARE
    v_total_score INTEGER;
    v_return_multiplier DECIMAL;
    v_risk_class INTEGER;
BEGIN
    -- Calculate base score
    v_total_score := (
        COALESCE(p_experience_score, 0) +
        COALESCE(p_knowledge_score, 0) +
        COALESCE(p_frequency_score, 0)
    ) / 3;

    -- Adjust for desired return
    v_return_multiplier := CASE p_desired_return
        WHEN 'capital_preservation' THEN 0.5
        WHEN 'moderate_growth' THEN 0.75
        WHEN 'growth' THEN 1.0
        WHEN 'high_growth' THEN 1.25
        WHEN 'aggressive' THEN 1.5
        ELSE 1.0
    END;

    v_total_score := ROUND(v_total_score * v_return_multiplier);

    -- Map to risk class (1-7)
    v_risk_class := CASE
        WHEN v_total_score <= 2 THEN 1
        WHEN v_total_score <= 3 THEN 2
        WHEN v_total_score <= 4 THEN 3
        WHEN v_total_score <= 5 THEN 4
        WHEN v_total_score <= 6 THEN 5
        WHEN v_total_score <= 8 THEN 6
        ELSE 7
    END;

    RETURN v_risk_class;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- ============================================================================
-- STATISTICS FUNCTIONS
-- ============================================================================

-- Get trader statistics
CREATE OR REPLACE FUNCTION get_trader_stats(p_trader_id UUID)
RETURNS TABLE (
    total_trades INTEGER,
    winning_trades INTEGER,
    losing_trades INTEGER,
    win_rate DECIMAL,
    total_profit DECIMAL,
    avg_profit_per_trade DECIMAL,
    total_volume DECIMAL,
    active_investors INTEGER,
    total_aum DECIMAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*)::INTEGER FROM trades WHERE trader_id = p_trader_id AND status = 'completed'),
        (SELECT COUNT(*)::INTEGER FROM trades WHERE trader_id = p_trader_id AND status = 'completed' AND gross_profit > 0),
        (SELECT COUNT(*)::INTEGER FROM trades WHERE trader_id = p_trader_id AND status = 'completed' AND gross_profit <= 0),
        (SELECT
            CASE
                WHEN COUNT(*) > 0
                THEN ROUND(COUNT(*) FILTER (WHERE gross_profit > 0)::DECIMAL / COUNT(*) * 100, 2)
                ELSE 0
            END
         FROM trades WHERE trader_id = p_trader_id AND status = 'completed'
        ),
        (SELECT COALESCE(SUM(gross_profit), 0) FROM trades WHERE trader_id = p_trader_id AND status = 'completed'),
        (SELECT COALESCE(AVG(gross_profit), 0) FROM trades WHERE trader_id = p_trader_id AND status = 'completed'),
        (SELECT COALESCE(SUM(buy_amount), 0) FROM trades WHERE trader_id = p_trader_id),
        (SELECT COUNT(DISTINCT investor_id)::INTEGER FROM investments WHERE trader_id = p_trader_id AND status = 'active'),
        (SELECT COALESCE(SUM(amount), 0) FROM investments WHERE trader_id = p_trader_id AND status = 'active');
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

-- Check transaction limit
CREATE OR REPLACE FUNCTION check_transaction_limit(
    p_user_id UUID,
    p_amount DECIMAL,
    p_type VARCHAR DEFAULT 'daily'
)
RETURNS TABLE (
    is_allowed BOOLEAN,
    limit_amount DECIMAL,
    used_amount DECIMAL,
    remaining DECIMAL
) AS $$
DECLARE
    v_limit DECIMAL;
    v_used DECIMAL;
BEGIN
    -- Hole Limits
    SELECT
        CASE p_type
            WHEN 'daily' THEN effective_daily_limit
            WHEN 'weekly' THEN effective_weekly_limit
            WHEN 'monthly' THEN effective_monthly_limit
            ELSE effective_daily_limit
        END
    INTO v_limit
    FROM transaction_limits
    WHERE user_id = p_user_id;

    -- Default Limit wenn nicht konfiguriert
    IF v_limit IS NULL THEN
        v_limit := CASE p_type
            WHEN 'daily' THEN 10000
            WHEN 'weekly' THEN 50000
            WHEN 'monthly' THEN 200000
            ELSE 10000
        END;
    END IF;

    -- Hole aktuelle Nutzung
    SELECT
        CASE p_type
            WHEN 'daily' THEN daily_used
            WHEN 'weekly' THEN weekly_used
            WHEN 'monthly' THEN monthly_used
            ELSE daily_used
        END
    INTO v_used
    FROM transaction_limit_usage
    WHERE user_id = p_user_id;

    v_used := COALESCE(v_used, 0);

    RETURN QUERY
    SELECT
        (v_used + p_amount <= v_limit) AS is_allowed,
        v_limit AS limit_amount,
        v_used AS used_amount,
        (v_limit - v_used) AS remaining;
END;
$$ LANGUAGE plpgsql STABLE;

-- Anonymize user data (for GDPR)
CREATE OR REPLACE FUNCTION anonymize_user_data(p_user_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
    -- Anonymize user
    UPDATE users SET
        email = 'deleted_' || id || '@anonymized.local',
        username = 'deleted_' || id,
        phone_number = NULL,
        password_hash = 'DELETED',
        status = 'deleted',
        deleted_at = NOW()
    WHERE id = p_user_id;

    -- Anonymize profile
    UPDATE user_profiles SET
        first_name = 'Deleted',
        last_name = 'User',
        middle_name = NULL,
        birth_name = NULL,
        date_of_birth = '1900-01-01',
        place_of_birth = NULL,
        country_of_birth = NULL,
        mobile_phone = NULL,
        landline_phone = NULL,
        profile_image_url = NULL
    WHERE user_id = p_user_id;

    -- Anonymize addresses
    UPDATE user_addresses SET
        street = 'Anonymized',
        house_number = NULL,
        address_line_2 = NULL,
        postal_code = '00000',
        city = 'Anonymized',
        state = NULL
    WHERE user_id = p_user_id;

    -- Delete sensitive data
    DELETE FROM user_kyc_documents WHERE user_id = p_user_id;
    DELETE FROM user_sessions WHERE user_id = p_user_id;
    DELETE FROM push_tokens WHERE user_id = p_user_id;

    -- Log the deletion
    INSERT INTO compliance_events (
        user_id, event_type, severity, description,
        regulatory_flags
    ) VALUES (
        p_user_id,
        'data_deleted',
        'high',
        'User data anonymized per GDPR request',
        ARRAY['gdpr']
    );

    RETURN TRUE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- END OF 015_functions.sql
-- ============================================================================
