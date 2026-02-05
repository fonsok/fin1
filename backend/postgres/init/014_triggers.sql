-- ============================================================================
-- DATABASE SCHEMA
-- 014_triggers.sql - Additional Audit Triggers & Business Logic
-- ============================================================================
--
-- Zusätzliche Trigger für:
--   1. Automatische Audit-Logs
--   2. Business Logic Enforcement
--   3. Datenintegrität
--
-- Basis-Triggers (updated_at) sind bereits in den Schema-Dateien.
--
-- ============================================================================

-- ============================================================================
-- GENERIC AUDIT TRIGGER FUNCTION
-- ============================================================================

CREATE OR REPLACE FUNCTION generic_audit_trigger()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_old_data JSONB;
    v_new_data JSONB;
    v_changed_fields TEXT[];
BEGIN
    -- Versuche user_id aus Session zu holen (wenn gesetzt)
    BEGIN
        v_user_id := current_setting('app.current_user_id')::UUID;
    EXCEPTION WHEN OTHERS THEN
        v_user_id := NULL;
    END;

    IF TG_OP = 'DELETE' THEN
        v_old_data := to_jsonb(OLD);
        v_new_data := NULL;
    ELSIF TG_OP = 'INSERT' THEN
        v_old_data := NULL;
        v_new_data := to_jsonb(NEW);
    ELSE -- UPDATE
        v_old_data := to_jsonb(OLD);
        v_new_data := to_jsonb(NEW);

        -- Ermittle geänderte Felder
        SELECT ARRAY_AGG(key) INTO v_changed_fields
        FROM jsonb_each(v_old_data) o
        FULL OUTER JOIN jsonb_each(v_new_data) n USING (key)
        WHERE o.value IS DISTINCT FROM n.value;
    END IF;

    INSERT INTO audit_logs (
        log_type, action, action_category,
        user_id, resource_type, resource_id,
        old_values, new_values, metadata
    ) VALUES (
        'action',
        TG_OP,
        TG_TABLE_NAME,
        v_user_id,
        TG_TABLE_NAME,
        CASE
            WHEN TG_OP = 'DELETE' THEN (OLD.id)::TEXT
            ELSE (NEW.id)::TEXT
        END,
        v_old_data,
        v_new_data,
        jsonb_build_object('changed_fields', v_changed_fields)
    );

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- USER AUDIT TRIGGERS
-- ============================================================================

-- Audit wichtige User-Änderungen
CREATE OR REPLACE FUNCTION audit_user_changes()
RETURNS TRIGGER AS $$
BEGIN
    -- Nur bei wichtigen Änderungen
    IF OLD.status != NEW.status
       OR OLD.email != NEW.email
       OR OLD.role != NEW.role
       OR OLD.kyc_status != NEW.kyc_status THEN

        INSERT INTO user_audit_log (
            user_id, table_name, record_id, action,
            old_values, new_values, changed_fields
        ) VALUES (
            NEW.id,
            'users',
            NULL,
            CASE
                WHEN OLD.status != NEW.status THEN 'update'
                WHEN OLD.email != NEW.email THEN 'email_change'
                ELSE 'update'
            END,
            jsonb_build_object(
                'status', OLD.status,
                'email', OLD.email,
                'role', OLD.role,
                'kyc_status', OLD.kyc_status
            ),
            jsonb_build_object(
                'status', NEW.status,
                'email', NEW.email,
                'role', NEW.role,
                'kyc_status', NEW.kyc_status
            ),
            ARRAY_REMOVE(ARRAY[
                CASE WHEN OLD.status != NEW.status THEN 'status' END,
                CASE WHEN OLD.email != NEW.email THEN 'email' END,
                CASE WHEN OLD.role != NEW.role THEN 'role' END,
                CASE WHEN OLD.kyc_status != NEW.kyc_status THEN 'kyc_status' END
            ], NULL)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER users_audit_changes
    AFTER UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION audit_user_changes();

-- ============================================================================
-- COMPLIANCE TRIGGERS
-- ============================================================================

-- Automatisch Compliance-Event bei großen Transaktionen
CREATE OR REPLACE FUNCTION check_transaction_compliance()
RETURNS TRIGGER AS $$
BEGIN
    -- Große Transaktion (> 10.000 €)
    IF NEW.status = 'completed'
       AND ABS(NEW.amount) >= 10000
       AND NEW.transaction_type IN ('deposit', 'withdrawal') THEN

        INSERT INTO compliance_events (
            user_id, event_type, severity, description,
            metadata, regulatory_flags, requires_review
        ) VALUES (
            NEW.user_id,
            'large_transaction',
            'medium',
            'Transaction over €10,000 threshold',
            jsonb_build_object(
                'transaction_id', NEW.id,
                'transaction_number', NEW.transaction_number,
                'amount', NEW.amount,
                'type', NEW.transaction_type
            ),
            ARRAY['gwg', 'aml'],
            CASE WHEN ABS(NEW.amount) >= 15000 THEN true ELSE false END
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER wallet_tx_compliance_check
    AFTER INSERT OR UPDATE ON wallet_transactions
    FOR EACH ROW EXECUTE FUNCTION check_transaction_compliance();

-- KYC-Ablauf prüfen
CREATE OR REPLACE FUNCTION check_kyc_expiry()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.expiry_date IS NOT NULL AND NEW.expiry_date <= CURRENT_DATE + INTERVAL '30 days' THEN
        -- Benachrichtigung erstellen
        INSERT INTO notifications (
            user_id, type, category, priority,
            title, message, reference_type, reference_id
        ) VALUES (
            NEW.user_id,
            'kyc_expiring',
            'account',
            'high',
            'KYC-Dokument läuft ab',
            'Ihr ' || NEW.document_type || ' läuft am ' || NEW.expiry_date || ' ab. Bitte aktualisieren Sie Ihre Dokumente.',
            'kyc_document',
            NEW.id::TEXT
        );

        -- Compliance Event
        IF NEW.expiry_date <= CURRENT_DATE THEN
            INSERT INTO compliance_events (
                user_id, event_type, severity, description,
                reference_type, reference_id
            ) VALUES (
                NEW.user_id,
                'kyc_expired',
                'high',
                'KYC document has expired',
                'kyc_document',
                NEW.id::TEXT
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER kyc_document_expiry_check
    AFTER INSERT OR UPDATE ON user_kyc_documents
    FOR EACH ROW EXECUTE FUNCTION check_kyc_expiry();

-- ============================================================================
-- BUSINESS LOGIC TRIGGERS
-- ============================================================================

-- Investment Status nach Trade-Änderung aktualisieren
CREATE OR REPLACE FUNCTION update_investment_after_trade()
RETURNS TRIGGER AS $$
BEGIN
    -- Wenn Trade abgeschlossen wird, update zugehörige Investments
    IF NEW.status = 'completed' AND OLD.status != 'completed' THEN
        UPDATE pool_trade_participations
        SET is_settled = true, settled_at = NOW()
        WHERE trade_id = NEW.id AND is_settled = false;

        -- Update Investment-Statistiken
        UPDATE investments i
        SET
            number_of_trades = (
                SELECT COUNT(DISTINCT ptp.trade_id)
                FROM pool_trade_participations ptp
                WHERE ptp.investment_id = i.id
            ),
            updated_at = NOW()
        FROM pool_trade_participations ptp
        WHERE ptp.trade_id = NEW.id AND ptp.investment_id = i.id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trade_completion_update_investments
    AFTER UPDATE ON trades
    FOR EACH ROW EXECUTE FUNCTION update_investment_after_trade();

-- Order Status Tracking
CREATE OR REPLACE FUNCTION track_order_status_change()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        -- Log in trade_audit_log wenn Trade existiert
        IF NEW.trade_id IS NOT NULL THEN
            INSERT INTO trade_audit_log (
                trade_id, action, old_status, new_status, order_id, notes
            ) VALUES (
                NEW.trade_id,
                CASE
                    WHEN NEW.status = 'executed' AND NEW.side = 'sell' THEN 'sell_executed'
                    WHEN NEW.status = 'executed' AND NEW.side = 'buy' THEN 'buy_executed'
                    ELSE 'order_status_change'
                END,
                OLD.status,
                NEW.status,
                NEW.id,
                'Order ' || NEW.order_number || ' status changed'
            );
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER order_status_tracking
    AFTER UPDATE ON orders
    FOR EACH ROW EXECUTE FUNCTION track_order_status_change();

-- ============================================================================
-- NOTIFICATION TRIGGERS
-- ============================================================================

-- Automatische Benachrichtigung bei wichtigen Events
CREATE OR REPLACE FUNCTION create_investment_notification()
RETURNS TRIGGER AS $$
BEGIN
    -- Investor benachrichtigen bei Status-Änderung
    IF OLD.status IS DISTINCT FROM NEW.status THEN
        INSERT INTO notifications (
            user_id, type, category, priority,
            title, message, reference_type, reference_id
        ) VALUES (
            NEW.investor_id,
            CASE NEW.status
                WHEN 'active' THEN 'investment_activated'
                WHEN 'completed' THEN 'investment_completed'
                WHEN 'cancelled' THEN 'investment_cancelled'
                ELSE 'investment_created'
            END,
            'investment',
            CASE WHEN NEW.status = 'cancelled' THEN 'high' ELSE 'normal' END,
            CASE NEW.status
                WHEN 'active' THEN 'Investment aktiviert'
                WHEN 'completed' THEN 'Investment abgeschlossen'
                WHEN 'cancelled' THEN 'Investment storniert'
                ELSE 'Investment erstellt'
            END,
            'Ihr Investment #' || NEW.investment_number || ' bei ' || COALESCE(NEW.trader_name, 'Trader') ||
            ' ist nun ' || NEW.status || '.',
            'investment',
            NEW.id::TEXT
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER investment_notification_trigger
    AFTER UPDATE ON investments
    FOR EACH ROW EXECUTE FUNCTION create_investment_notification();

-- ============================================================================
-- DATA INTEGRITY TRIGGERS
-- ============================================================================

-- Prevent deletion of users with active investments/trades
CREATE OR REPLACE FUNCTION prevent_user_deletion()
RETURNS TRIGGER AS $$
BEGIN
    -- Check for active investments
    IF EXISTS (
        SELECT 1 FROM investments
        WHERE (investor_id = OLD.id OR trader_id = OLD.id)
        AND status IN ('active', 'executing')
    ) THEN
        RAISE EXCEPTION 'Cannot delete user with active investments';
    END IF;

    -- Check for active trades
    IF EXISTS (
        SELECT 1 FROM trades
        WHERE trader_id = OLD.id
        AND status IN ('pending', 'active', 'partial')
    ) THEN
        RAISE EXCEPTION 'Cannot delete user with active trades';
    END IF;

    -- Check for pending transactions
    IF EXISTS (
        SELECT 1 FROM wallet_transactions
        WHERE user_id = OLD.id
        AND status IN ('pending', 'processing')
    ) THEN
        RAISE EXCEPTION 'Cannot delete user with pending transactions';
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER prevent_user_hard_delete
    BEFORE DELETE ON users
    FOR EACH ROW EXECUTE FUNCTION prevent_user_deletion();

-- Validate investment amount
CREATE OR REPLACE FUNCTION validate_investment()
RETURNS TRIGGER AS $$
DECLARE
    v_min_investment DECIMAL := 100;
    v_investor_balance DECIMAL;
BEGIN
    -- Check minimum investment
    IF NEW.amount < v_min_investment THEN
        RAISE EXCEPTION 'Investment amount must be at least € %', v_min_investment;
    END IF;

    -- Check if investor is not the same as trader
    IF NEW.investor_id = NEW.trader_id THEN
        RAISE EXCEPTION 'Investor cannot invest in their own pool';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER validate_investment_trigger
    BEFORE INSERT ON investments
    FOR EACH ROW EXECUTE FUNCTION validate_investment();

-- ============================================================================
-- SLA TRIGGERS
-- ============================================================================

-- Auto-create SLA tracking for new tickets
CREATE OR REPLACE FUNCTION create_ticket_sla()
RETURNS TRIGGER AS $$
DECLARE
    v_first_response_hours INTEGER;
    v_resolution_hours INTEGER;
BEGIN
    -- SLA-Zeiten basierend auf Priorität
    CASE NEW.priority
        WHEN 'urgent' THEN
            v_first_response_hours := 1;
            v_resolution_hours := 4;
        WHEN 'high' THEN
            v_first_response_hours := 4;
            v_resolution_hours := 24;
        WHEN 'medium' THEN
            v_first_response_hours := 8;
            v_resolution_hours := 48;
        ELSE  -- low
            v_first_response_hours := 24;
            v_resolution_hours := 72;
    END CASE;

    INSERT INTO ticket_sla_tracking (
        ticket_id,
        first_response_target,
        resolution_target,
        sla_status
    ) VALUES (
        NEW.id,
        NEW.created_at + (v_first_response_hours || ' hours')::INTERVAL,
        NEW.created_at + (v_resolution_hours || ' hours')::INTERVAL,
        'on_track'
    );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ticket_create_sla
    AFTER INSERT ON support_tickets
    FOR EACH ROW EXECUTE FUNCTION create_ticket_sla();

-- Update SLA on ticket response
CREATE OR REPLACE FUNCTION update_sla_on_response()
RETURNS TRIGGER AS $$
BEGIN
    -- Nur Agent-Antworten (keine internen Notizen)
    IF NEW.agent_id IS NOT NULL AND NEW.response_type = 'message' AND NOT NEW.is_internal THEN
        UPDATE ticket_sla_tracking
        SET
            first_response_actual = COALESCE(first_response_actual, NOW()),
            first_response_breached = CASE
                WHEN first_response_actual IS NULL AND NOW() > first_response_target
                THEN true
                ELSE first_response_breached
            END,
            sla_status = CASE
                WHEN NOW() > resolution_target THEN 'breached'
                WHEN NOW() > resolution_target - (resolution_target - first_response_target) * 0.25 THEN 'warning'
                ELSE 'on_track'
            END,
            updated_at = NOW()
        WHERE ticket_id = NEW.ticket_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ticket_response_sla_update
    AFTER INSERT ON ticket_responses
    FOR EACH ROW EXECUTE FUNCTION update_sla_on_response();

-- ============================================================================
-- END OF 014_triggers.sql
-- ============================================================================
