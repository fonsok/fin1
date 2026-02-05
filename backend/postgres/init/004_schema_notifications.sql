-- ============================================================================
-- DATABASE SCHEMA
-- 004_schema_notifications.sql - Notification System
-- ============================================================================
--
-- Dieses Schema verwaltet alle Benachrichtigungen (In-App, Push, E-Mail).
--
-- Tabellen (4):
--   1. notifications              - Alle Benachrichtigungen
--   2. notification_preferences   - User-spezifische Einstellungen
--   3. notification_templates     - Vorlagen für Benachrichtigungen
--   4. notification_delivery_log  - Delivery-Tracking
--
-- ============================================================================

-- ============================================================================
-- 1. NOTIFICATIONS
-- ============================================================================
-- Alle Benachrichtigungen (In-App und Push)

CREATE TABLE IF NOT EXISTS notifications (
    id BIGSERIAL PRIMARY KEY,

    -- Empfänger
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,

    -- Typ und Kategorie
    type VARCHAR(50) NOT NULL CHECK (type IN (
        -- Investment
        'investment_created',
        'investment_activated',
        'investment_profit',
        'investment_completed',
        'investment_cancelled',

        -- Trading
        'order_submitted',
        'order_executed',
        'order_cancelled',
        'trade_completed',
        'price_alert_triggered',

        -- Documents
        'document_available',
        'document_expiring',
        'statement_ready',
        'invoice_created',

        -- Account
        'kyc_approved',
        'kyc_rejected',
        'kyc_expiring',
        'password_changed',
        'login_new_device',

        -- Wallet
        'deposit_received',
        'withdrawal_completed',
        'withdrawal_failed',

        -- Support
        'ticket_created',
        'ticket_response',
        'ticket_resolved',

        -- System
        'system_maintenance',
        'security_alert',
        'announcement',
        'marketing'
    )),

    category VARCHAR(30) NOT NULL CHECK (category IN (
        'investment', 'trading', 'document', 'account',
        'wallet', 'support', 'system', 'marketing'
    )),

    -- Priorität
    priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN (
        'low', 'normal', 'high', 'urgent'
    )),

    -- Inhalt
    title VARCHAR(200) NOT NULL,
    title_de VARCHAR(200),
    title_en VARCHAR(200),
    message TEXT NOT NULL,
    message_de TEXT,
    message_en TEXT,

    -- Rich Content
    image_url TEXT,
    action_url TEXT,  -- Deep Link
    action_label VARCHAR(100),

    -- Referenz
    reference_type VARCHAR(50),  -- 'investment', 'trade', 'document', 'ticket'
    reference_id VARCHAR(100),   -- ID des referenzierten Objekts

    -- Metadata
    metadata JSONB,  -- Zusätzliche typ-spezifische Daten

    -- Status
    is_read BOOLEAN DEFAULT false,
    read_at TIMESTAMP WITH TIME ZONE,
    is_archived BOOLEAN DEFAULT false,
    archived_at TIMESTAMP WITH TIME ZONE,

    -- Delivery
    channels TEXT[] DEFAULT ARRAY['in_app'],  -- ['in_app', 'push', 'email', 'sms']
    push_sent BOOLEAN DEFAULT false,
    push_sent_at TIMESTAMP WITH TIME ZONE,
    email_sent BOOLEAN DEFAULT false,
    email_sent_at TIMESTAMP WITH TIME ZONE,

    -- Scheduling
    scheduled_for TIMESTAMP WITH TIME ZONE,  -- NULL = sofort
    expires_at TIMESTAMP WITH TIME ZONE,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID  -- NULL = System, UUID = Admin
);

COMMENT ON TABLE notifications IS 'Alle Benutzerbenachrichtigungen (In-App, Push, E-Mail)';
COMMENT ON COLUMN notifications.reference_type IS 'Typ des referenzierten Objekts für Deep Linking';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_unread
    ON notifications(user_id, is_read) WHERE is_read = false;
CREATE INDEX IF NOT EXISTS idx_notifications_category ON notifications(category);
CREATE INDEX IF NOT EXISTS idx_notifications_created ON notifications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notifications_reference
    ON notifications(reference_type, reference_id);

-- ============================================================================
-- 2. NOTIFICATION_PREFERENCES
-- ============================================================================
-- User-spezifische Benachrichtigungseinstellungen

CREATE TABLE IF NOT EXISTS notification_preferences (
    id SERIAL PRIMARY KEY,
    user_id UUID NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,

    -- Globale Einstellungen
    notifications_enabled BOOLEAN DEFAULT true,

    -- Kanal-Einstellungen
    in_app_enabled BOOLEAN DEFAULT true,
    push_enabled BOOLEAN DEFAULT true,
    email_enabled BOOLEAN DEFAULT true,
    sms_enabled BOOLEAN DEFAULT false,

    -- Kategorie-Einstellungen (JSON für Flexibilität)
    category_settings JSONB DEFAULT '{
        "investment": {"in_app": true, "push": true, "email": true},
        "trading": {"in_app": true, "push": true, "email": false},
        "document": {"in_app": true, "push": false, "email": true},
        "account": {"in_app": true, "push": true, "email": true},
        "wallet": {"in_app": true, "push": true, "email": true},
        "support": {"in_app": true, "push": true, "email": true},
        "system": {"in_app": true, "push": true, "email": false},
        "marketing": {"in_app": false, "push": false, "email": false}
    }'::jsonb,

    -- Quiet Hours (Do Not Disturb)
    quiet_hours_enabled BOOLEAN DEFAULT false,
    quiet_hours_start TIME,  -- z.B. 22:00
    quiet_hours_end TIME,    -- z.B. 07:00
    quiet_hours_timezone VARCHAR(50) DEFAULT 'Europe/Berlin',

    -- Wochenende
    quiet_on_weekends BOOLEAN DEFAULT false,

    -- Frequenz
    email_digest_enabled BOOLEAN DEFAULT false,
    email_digest_frequency VARCHAR(20) CHECK (email_digest_frequency IN (
        'immediate', 'hourly', 'daily', 'weekly'
    )),
    email_digest_time TIME DEFAULT '09:00',

    -- Minimum Priorität für Push
    min_push_priority VARCHAR(20) DEFAULT 'normal' CHECK (min_push_priority IN (
        'low', 'normal', 'high', 'urgent'
    )),

    -- Sound und Vibration
    sound_enabled BOOLEAN DEFAULT true,
    vibration_enabled BOOLEAN DEFAULT true,
    badge_enabled BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE notification_preferences IS 'Benutzer-spezifische Benachrichtigungseinstellungen';
COMMENT ON COLUMN notification_preferences.category_settings IS 'Kanal-Einstellungen pro Kategorie als JSON';

-- ============================================================================
-- 3. NOTIFICATION_TEMPLATES
-- ============================================================================
-- Vorlagen für Benachrichtigungen (Admin-verwaltet)

CREATE TABLE IF NOT EXISTS notification_templates (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    type VARCHAR(50) NOT NULL,  -- Entspricht notifications.type
    channel VARCHAR(20) NOT NULL CHECK (channel IN ('in_app', 'push', 'email', 'sms')),

    -- Templates (mit Platzhaltern)
    title_template VARCHAR(500) NOT NULL,
    title_template_de VARCHAR(500),
    title_template_en VARCHAR(500),

    body_template TEXT NOT NULL,
    body_template_de TEXT,
    body_template_en TEXT,

    -- E-Mail spezifisch
    email_subject_template VARCHAR(200),
    email_html_template TEXT,
    email_from_name VARCHAR(100),
    email_from_address VARCHAR(255),

    -- Push spezifisch
    push_sound VARCHAR(100),
    push_badge_increment INTEGER DEFAULT 1,
    push_category VARCHAR(50),  -- iOS Action Category

    -- Deep Link Template
    action_url_template TEXT,

    -- Verfügbare Variablen
    available_variables TEXT[],  -- ['{{user_name}}', '{{amount}}', '{{trade_id}}']

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,

    UNIQUE(type, channel)
);

COMMENT ON TABLE notification_templates IS 'Benachrichtigungsvorlagen mit Platzhaltern';
COMMENT ON COLUMN notification_templates.available_variables IS 'Liste der verfügbaren Platzhalter';

-- ============================================================================
-- 4. NOTIFICATION_DELIVERY_LOG
-- ============================================================================
-- Delivery-Tracking für alle versendeten Benachrichtigungen

CREATE TABLE IF NOT EXISTS notification_delivery_log (
    id BIGSERIAL PRIMARY KEY,
    notification_id BIGINT NOT NULL REFERENCES notifications(id) ON DELETE CASCADE,

    -- Kanal
    channel VARCHAR(20) NOT NULL CHECK (channel IN ('in_app', 'push', 'email', 'sms')),

    -- Status
    status VARCHAR(20) NOT NULL CHECK (status IN (
        'pending',     -- Wartet auf Versand
        'sent',        -- Versendet
        'delivered',   -- Zugestellt (bestätigt)
        'read',        -- Gelesen
        'failed',      -- Fehlgeschlagen
        'bounced',     -- Zurückgewiesen (E-Mail)
        'unsubscribed' -- Abgemeldet
    )),

    -- Zeitstempel
    queued_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    sent_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    read_at TIMESTAMP WITH TIME ZONE,
    failed_at TIMESTAMP WITH TIME ZONE,

    -- Provider Info
    provider VARCHAR(50),  -- 'apns', 'fcm', 'sendgrid', 'twilio'
    provider_message_id VARCHAR(255),

    -- Fehler
    error_code VARCHAR(50),
    error_message TEXT,
    retry_count INTEGER DEFAULT 0,
    next_retry_at TIMESTAMP WITH TIME ZONE,

    -- Device Info (für Push)
    device_id INTEGER REFERENCES user_devices(id),
    push_token_id INTEGER REFERENCES push_tokens(id),

    -- E-Mail spezifisch
    email_address VARCHAR(255),
    email_opened BOOLEAN DEFAULT false,
    email_clicked BOOLEAN DEFAULT false,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE notification_delivery_log IS 'Tracking aller Benachrichtigungszustellungen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_delivery_log_notification ON notification_delivery_log(notification_id);
CREATE INDEX IF NOT EXISTS idx_delivery_log_status ON notification_delivery_log(status) WHERE status IN ('pending', 'failed');
CREATE INDEX IF NOT EXISTS idx_delivery_log_channel ON notification_delivery_log(channel);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Funktion zum Markieren als gelesen
CREATE OR REPLACE FUNCTION mark_notification_read(p_notification_id BIGINT, p_user_id UUID)
RETURNS BOOLEAN AS $$
DECLARE
    v_updated BOOLEAN;
BEGIN
    UPDATE notifications
    SET is_read = true, read_at = NOW()
    WHERE id = p_notification_id
      AND user_id = p_user_id
      AND is_read = false;

    GET DIAGNOSTICS v_updated = ROW_COUNT;

    -- Update delivery log
    UPDATE notification_delivery_log
    SET status = 'read', read_at = NOW()
    WHERE notification_id = p_notification_id AND channel = 'in_app';

    RETURN v_updated > 0;
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Abrufen ungelesener Anzahl
CREATE OR REPLACE FUNCTION get_unread_notification_count(p_user_id UUID)
RETURNS TABLE(total BIGINT, by_category JSONB) AS $$
BEGIN
    RETURN QUERY
    SELECT
        COUNT(*)::BIGINT AS total,
        jsonb_object_agg(category, cnt) AS by_category
    FROM (
        SELECT category, COUNT(*) AS cnt
        FROM notifications
        WHERE user_id = p_user_id
          AND is_read = false
          AND is_archived = false
          AND (expires_at IS NULL OR expires_at > NOW())
        GROUP BY category
    ) sub;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Aktive Benachrichtigungen pro User
CREATE OR REPLACE VIEW v_active_notifications AS
SELECT
    n.*,
    u.email,
    up.first_name,
    up.preferred_language
FROM notifications n
JOIN users u ON n.user_id = u.id
LEFT JOIN user_profiles up ON n.user_id = up.user_id
WHERE n.is_archived = false
    AND (n.expires_at IS NULL OR n.expires_at > NOW())
ORDER BY n.created_at DESC;

-- Delivery Statistiken
CREATE OR REPLACE VIEW v_notification_stats AS
SELECT
    n.type,
    n.category,
    dl.channel,
    dl.status,
    COUNT(*) AS count,
    DATE_TRUNC('day', dl.created_at) AS day
FROM notification_delivery_log dl
JOIN notifications n ON dl.notification_id = n.id
WHERE dl.created_at >= NOW() - INTERVAL '30 days'
GROUP BY n.type, n.category, dl.channel, dl.status, DATE_TRUNC('day', dl.created_at);

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER notification_preferences_updated_at
    BEFORE UPDATE ON notification_preferences
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER notification_templates_updated_at
    BEFORE UPDATE ON notification_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INITIAL DATA - Notification Templates
-- ============================================================================

INSERT INTO notification_templates (type, channel, title_template, body_template, available_variables) VALUES
-- Investment
('investment_created', 'push',
 'Investment erstellt',
 'Ihr Investment über {{amount}} € bei {{trader_name}} wurde erstellt.',
 ARRAY['{{amount}}', '{{trader_name}}', '{{investment_id}}']),

('investment_profit', 'push',
 'Gewinn erzielt!',
 'Ihr Investment hat einen Gewinn von {{profit}} € erzielt.',
 ARRAY['{{profit}}', '{{trader_name}}', '{{investment_id}}']),

-- Trading
('order_executed', 'push',
 'Order ausgeführt',
 'Ihre {{order_type}}-Order für {{symbol}} wurde zu {{price}} € ausgeführt.',
 ARRAY['{{order_type}}', '{{symbol}}', '{{price}}', '{{quantity}}']),

('price_alert_triggered', 'push',
 'Preisalarm: {{symbol}}',
 '{{symbol}} hat den Preis von {{threshold}} € {{direction}}.',
 ARRAY['{{symbol}}', '{{threshold}}', '{{direction}}', '{{current_price}}']),

-- Account
('login_new_device', 'push',
 'Neuer Login erkannt',
 'Ein Login von einem neuen Gerät wurde erkannt: {{device_name}} ({{location}}).',
 ARRAY['{{device_name}}', '{{location}}', '{{ip_address}}']),

-- System
('system_maintenance', 'push',
 'Geplante Wartung',
 'Wartung geplant: {{start_time}} - {{end_time}}. Einige Funktionen sind möglicherweise nicht verfügbar.',
 ARRAY['{{start_time}}', '{{end_time}}', '{{affected_services}}'])

ON CONFLICT (type, channel) DO NOTHING;

-- ============================================================================
-- END OF 004_schema_notifications.sql
-- ============================================================================
