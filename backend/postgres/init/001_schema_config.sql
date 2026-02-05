-- ============================================================================
-- DATABASE SCHEMA
-- 001_schema_config.sql - Configuration Management
-- ============================================================================
--
-- Dieses Schema verwaltet die zentrale Konfiguration der Plattform.
-- Alle App-weiten Einstellungen werden hier gespeichert und können zur
-- Laufzeit geändert werden, ohne einen App-Rebuild zu erfordern.
--
-- Tabellen:
--   1. environments        - Umgebungen (Development, Staging, Production)
--   2. config_categories   - Konfigurationskategorien
--   3. config_items        - Konfigurationsschema (Metadaten)
--   4. config_values       - Aktuelle Werte pro Umgebung
--   5. config_audit_log    - Änderungshistorie (Compliance)
--
-- ============================================================================

-- Aktiviere UUID-Erweiterung falls nicht vorhanden
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================================
-- 1. ENVIRONMENTS
-- ============================================================================
-- Definiert die verschiedenen Umgebungen (Dev, Staging, Production)

CREATE TABLE IF NOT EXISTS environments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE,
    display_name VARCHAR(100),
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,
    color_code VARCHAR(7),  -- Hex color für UI (#FF0000)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT env_name_format CHECK (name ~ '^[a-z][a-z0-9_]*$')
);

COMMENT ON TABLE environments IS 'Definiert Deployment-Umgebungen (Development, Staging, Production)';
COMMENT ON COLUMN environments.name IS 'Technischer Name (lowercase, underscore)';
COMMENT ON COLUMN environments.is_default IS 'Standard-Umgebung für neue Konfigurationen';

-- ============================================================================
-- 2. CONFIG_CATEGORIES
-- ============================================================================
-- Kategorisiert Konfigurationseinstellungen für bessere Organisation

CREATE TABLE IF NOT EXISTS config_categories (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL UNIQUE,
    display_name VARCHAR(200),
    display_name_de VARCHAR(200),  -- German
    display_name_en VARCHAR(200),  -- English
    description TEXT,
    icon VARCHAR(50),  -- SF Symbol oder Icon-Name
    color VARCHAR(7),  -- Hex color für UI
    sort_order INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    parent_category_id INTEGER REFERENCES config_categories(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT category_name_format CHECK (name ~ '^[a-z][a-z0-9_]*$')
);

COMMENT ON TABLE config_categories IS 'Kategorien für Konfigurationseinstellungen';
COMMENT ON COLUMN config_categories.icon IS 'SF Symbol Name für iOS/macOS UI';
COMMENT ON COLUMN config_categories.parent_category_id IS 'Ermöglicht hierarchische Kategorien';

-- ============================================================================
-- 3. CONFIG_ITEMS
-- ============================================================================
-- Schema-Definition für einzelne Konfigurationswerte

CREATE TABLE IF NOT EXISTS config_items (
    id SERIAL PRIMARY KEY,
    category_id INTEGER NOT NULL REFERENCES config_categories(id) ON DELETE CASCADE,

    -- Identifikation
    key VARCHAR(100) NOT NULL,
    display_name VARCHAR(200) NOT NULL,
    display_name_de VARCHAR(200),
    display_name_en VARCHAR(200),
    description TEXT,
    description_de TEXT,
    description_en TEXT,

    -- Datentyp und Validierung
    data_type VARCHAR(20) NOT NULL CHECK (data_type IN (
        'string', 'number', 'integer', 'boolean', 'json',
        'array', 'date', 'datetime', 'url', 'email', 'enum'
    )),
    default_value JSONB,
    validation_rules JSONB,  -- {"min": 0, "max": 100, "pattern": "^https?://", "enum": ["a","b"]}

    -- UI-Hinweise
    ui_component VARCHAR(50),  -- 'textfield', 'slider', 'toggle', 'dropdown', 'colorpicker'
    ui_placeholder VARCHAR(200),
    ui_help_text TEXT,
    ui_group VARCHAR(100),  -- Gruppierung innerhalb der Kategorie

    -- Sicherheit und Flags
    is_sensitive BOOLEAN DEFAULT false,  -- Wird maskiert (Passwörter, API Keys)
    is_required BOOLEAN DEFAULT true,
    is_readonly BOOLEAN DEFAULT false,  -- Kann nicht über UI geändert werden
    is_deprecated BOOLEAN DEFAULT false,
    deprecated_message TEXT,
    requires_restart BOOLEAN DEFAULT false,  -- App-Neustart erforderlich

    -- Berechtigungen
    min_role_to_view VARCHAR(50) DEFAULT 'admin',
    min_role_to_edit VARCHAR(50) DEFAULT 'admin',

    -- Sortierung und Anzeige
    sort_order INTEGER DEFAULT 0,
    is_visible BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,

    UNIQUE(category_id, key),
    CONSTRAINT config_key_format CHECK (key ~ '^[a-z][a-z0-9_]*$')
);

COMMENT ON TABLE config_items IS 'Schema-Definition für Konfigurationswerte';
COMMENT ON COLUMN config_items.validation_rules IS 'JSON mit Validierungsregeln: min, max, pattern, enum, etc.';
COMMENT ON COLUMN config_items.is_sensitive IS 'Sensible Daten werden in Logs/UI maskiert';
COMMENT ON COLUMN config_items.requires_restart IS 'Änderung erfordert App-Neustart';

-- ============================================================================
-- 4. CONFIG_VALUES
-- ============================================================================
-- Aktuelle Werte pro Umgebung (mit Versionierung)

CREATE TABLE IF NOT EXISTS config_values (
    id SERIAL PRIMARY KEY,
    item_id INTEGER NOT NULL REFERENCES config_items(id) ON DELETE CASCADE,
    environment_id INTEGER NOT NULL REFERENCES environments(id) ON DELETE CASCADE,

    -- Wert
    value JSONB NOT NULL,

    -- Gültigkeit
    is_active BOOLEAN DEFAULT true,
    valid_from TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    valid_until TIMESTAMP WITH TIME ZONE,  -- NULL = unbegrenzt gültig

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID,
    updated_by UUID,
    update_reason TEXT,

    -- Nur ein aktiver Wert pro Item und Environment
    UNIQUE(item_id, environment_id, valid_from)
);

COMMENT ON TABLE config_values IS 'Konfigurationswerte pro Umgebung mit Versionierung';
COMMENT ON COLUMN config_values.valid_until IS 'NULL bedeutet unbegrenzt gültig';
COMMENT ON COLUMN config_values.update_reason IS 'Grund für die Änderung (für Audit)';

-- Index für schnellen Zugriff auf aktuelle Werte
CREATE INDEX IF NOT EXISTS idx_config_values_active
    ON config_values(item_id, environment_id)
    WHERE is_active = true AND (valid_until IS NULL OR valid_until > NOW());

-- ============================================================================
-- 5. CONFIG_AUDIT_LOG
-- ============================================================================
-- Unveränderliche Änderungshistorie (10 Jahre Aufbewahrung für Compliance)

CREATE TABLE IF NOT EXISTS config_audit_log (
    id BIGSERIAL PRIMARY KEY,

    -- Referenzen (denormalisiert für Audit-Beständigkeit)
    value_id INTEGER,  -- Kann NULL sein nach Löschung
    item_key VARCHAR(100) NOT NULL,
    item_display_name VARCHAR(200),
    category_name VARCHAR(100),
    environment_name VARCHAR(50) NOT NULL,

    -- Änderung
    action VARCHAR(20) NOT NULL CHECK (action IN (
        'create', 'update', 'delete', 'rollback', 'import', 'export'
    )),
    old_value JSONB,
    new_value JSONB,

    -- Wer und Wann
    changed_by UUID,
    changed_by_username VARCHAR(100),
    changed_by_role VARCHAR(50),
    changed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Kontext
    reason TEXT,
    ip_address INET,
    user_agent TEXT,
    request_id VARCHAR(100),  -- Correlation ID für Request-Tracking

    -- Compliance
    retention_until DATE DEFAULT (CURRENT_DATE + INTERVAL '10 years')
);

-- Partitionierung nach Jahr für bessere Performance (optional)
-- CREATE TABLE config_audit_log_2024 PARTITION OF config_audit_log
--     FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');

COMMENT ON TABLE config_audit_log IS 'Unveränderliche Audit-Historie für Konfigurationsänderungen (10 Jahre)';
COMMENT ON COLUMN config_audit_log.retention_until IS 'Aufbewahrungsfrist nach deutschem Handelsrecht';

-- Indexes für häufige Abfragen
CREATE INDEX IF NOT EXISTS idx_config_audit_item ON config_audit_log(item_key);
CREATE INDEX IF NOT EXISTS idx_config_audit_env ON config_audit_log(environment_name);
CREATE INDEX IF NOT EXISTS idx_config_audit_time ON config_audit_log(changed_at DESC);
CREATE INDEX IF NOT EXISTS idx_config_audit_user ON config_audit_log(changed_by);

-- ============================================================================
-- TRIGGER: Auto-Update updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER environments_updated_at
    BEFORE UPDATE ON environments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER config_categories_updated_at
    BEFORE UPDATE ON config_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER config_items_updated_at
    BEFORE UPDATE ON config_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER config_values_updated_at
    BEFORE UPDATE ON config_values
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- TRIGGER: Audit Log für Config Changes
-- ============================================================================

CREATE OR REPLACE FUNCTION log_config_change()
RETURNS TRIGGER AS $$
DECLARE
    v_item_key VARCHAR(100);
    v_item_name VARCHAR(200);
    v_category_name VARCHAR(100);
    v_env_name VARCHAR(50);
BEGIN
    -- Hole Metadaten
    SELECT ci.key, ci.display_name, cc.name INTO v_item_key, v_item_name, v_category_name
    FROM config_items ci
    JOIN config_categories cc ON ci.category_id = cc.id
    WHERE ci.id = COALESCE(NEW.item_id, OLD.item_id);

    SELECT e.name INTO v_env_name
    FROM environments e
    WHERE e.id = COALESCE(NEW.environment_id, OLD.environment_id);

    IF TG_OP = 'INSERT' THEN
        INSERT INTO config_audit_log (
            value_id, item_key, item_display_name, category_name, environment_name,
            action, new_value, changed_by, reason
        ) VALUES (
            NEW.id, v_item_key, v_item_name, v_category_name, v_env_name,
            'create', NEW.value, NEW.created_by, NEW.update_reason
        );
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.value IS DISTINCT FROM NEW.value THEN
            INSERT INTO config_audit_log (
                value_id, item_key, item_display_name, category_name, environment_name,
                action, old_value, new_value, changed_by, reason
            ) VALUES (
                NEW.id, v_item_key, v_item_name, v_category_name, v_env_name,
                'update', OLD.value, NEW.value, NEW.updated_by, NEW.update_reason
            );
        END IF;
        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO config_audit_log (
            value_id, item_key, item_display_name, category_name, environment_name,
            action, old_value, changed_by
        ) VALUES (
            NULL, v_item_key, v_item_name, v_category_name, v_env_name,
            'delete', OLD.value, OLD.updated_by
        );
        RETURN OLD;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER config_values_audit
    AFTER INSERT OR UPDATE OR DELETE ON config_values
    FOR EACH ROW EXECUTE FUNCTION log_config_change();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View für aktuell gültige Konfiguration
CREATE OR REPLACE VIEW v_current_config AS
SELECT
    e.name AS environment,
    cc.name AS category,
    cc.display_name AS category_display,
    ci.key,
    ci.display_name,
    ci.data_type,
    ci.is_sensitive,
    CASE
        WHEN ci.is_sensitive THEN '"***"'::jsonb
        ELSE COALESCE(cv.value, ci.default_value)
    END AS value,
    ci.default_value,
    cv.valid_from,
    cv.updated_at,
    ci.description
FROM config_items ci
JOIN config_categories cc ON ci.category_id = cc.id
CROSS JOIN environments e
LEFT JOIN config_values cv ON ci.id = cv.item_id
    AND e.id = cv.environment_id
    AND cv.is_active = true
    AND (cv.valid_until IS NULL OR cv.valid_until > NOW())
WHERE ci.is_visible = true
    AND ci.is_deprecated = false
    AND cc.is_active = true
    AND e.is_active = true
ORDER BY cc.sort_order, ci.sort_order, e.name;

COMMENT ON VIEW v_current_config IS 'Aktuelle Konfigurationswerte aller Umgebungen';

-- ============================================================================
-- INITIAL DATA
-- ============================================================================

-- Environments
INSERT INTO environments (name, display_name, description, is_default, color_code) VALUES
    ('development', 'Development', 'Lokale Entwicklungsumgebung', false, '#10B981'),
    ('staging', 'Staging', 'Test- und QA-Umgebung', false, '#F59E0B'),
    ('production', 'Production', 'Produktionsumgebung', true, '#EF4444')
ON CONFLICT (name) DO NOTHING;

-- Config Categories
INSERT INTO config_categories (name, display_name, display_name_de, display_name_en, description, icon, sort_order) VALUES
    ('server', 'Server & Endpoints', 'Server & Endpunkte', 'Server & Endpoints', 'Server-Konfiguration und API-Endpunkte', 'server.rack', 1),
    ('financial', 'Financial Settings', 'Finanzeinstellungen', 'Financial Settings', 'Gebühren, Provisionen und finanzielle Parameter', 'eurosign.circle', 2),
    ('features', 'Feature Flags', 'Feature-Flags', 'Feature Flags', 'Aktivierung/Deaktivierung von Features', 'flag.fill', 3),
    ('company', 'Company Information', 'Firmendaten', 'Company Information', 'Rechtliche Firmendaten und Kontaktinformationen', 'building.2', 4),
    ('limits', 'Limits & Thresholds', 'Limits & Schwellwerte', 'Limits & Thresholds', 'Transaktionslimits und Schwellwerte', 'chart.bar.xaxis', 5),
    ('notifications', 'Notifications', 'Benachrichtigungen', 'Notifications', 'Benachrichtigungseinstellungen', 'bell.fill', 6),
    ('security', 'Security', 'Sicherheit', 'Security', 'Sicherheitseinstellungen', 'lock.shield', 7),
    ('maintenance', 'Maintenance', 'Wartung', 'Maintenance', 'Wartungsmodus und Systemstatus', 'wrench.and.screwdriver', 8)
ON CONFLICT (name) DO NOTHING;

-- ============================================================================
-- END OF 001_schema_config.sql
-- ============================================================================
