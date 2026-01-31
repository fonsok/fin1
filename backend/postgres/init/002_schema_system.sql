-- ============================================================================
-- FIN1 DATABASE SCHEMA
-- 002_schema_system.sql - App & System Management
-- ============================================================================
--
-- Dieses Schema verwaltet App-Versionen, Force-Updates, Ankündigungen
-- und systemweite Einstellungen.
--
-- Tabellen:
--   1. app_versions              - App-Versionen und Changelogs
--   2. force_update_rules        - Regeln für erzwungene Updates
--   3. announcements             - Systemweite Ankündigungen/Banner
--   4. announcement_dismissals   - Welche User welche Ankündigungen gesehen haben
--
-- ============================================================================

-- ============================================================================
-- 1. APP_VERSIONS
-- ============================================================================
-- Tracking aller App-Versionen mit Changelogs

CREATE TABLE IF NOT EXISTS app_versions (
    id SERIAL PRIMARY KEY,

    -- Version
    version VARCHAR(20) NOT NULL,  -- Semantic Versioning: 1.2.3
    build_number INTEGER NOT NULL,

    -- Plattform
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'macos', 'android', 'web')),

    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN (
        'development', 'beta', 'active', 'deprecated', 'blocked'
    )),

    -- Release Info
    release_date TIMESTAMP WITH TIME ZONE,
    release_notes TEXT,
    release_notes_de TEXT,
    release_notes_en TEXT,

    -- Requirements
    min_os_version VARCHAR(20),  -- z.B. "14.0" für iOS

    -- Download
    download_url TEXT,
    app_store_url TEXT,

    -- Flags
    is_mandatory BOOLEAN DEFAULT false,  -- Muss installiert werden
    is_beta BOOLEAN DEFAULT false,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    UNIQUE(platform, version, build_number)
);

COMMENT ON TABLE app_versions IS 'Alle veröffentlichten App-Versionen mit Changelogs';
COMMENT ON COLUMN app_versions.is_mandatory IS 'Bei true müssen ältere Versionen updaten';

-- Index
CREATE INDEX IF NOT EXISTS idx_app_versions_platform_status
    ON app_versions(platform, status);

-- ============================================================================
-- 2. FORCE_UPDATE_RULES
-- ============================================================================
-- Regeln für erzwungene Updates (z.B. bei kritischen Security-Fixes)

CREATE TABLE IF NOT EXISTS force_update_rules (
    id SERIAL PRIMARY KEY,

    -- Ziel
    platform VARCHAR(20) NOT NULL CHECK (platform IN ('ios', 'macos', 'android', 'web', 'all')),

    -- Version Range
    min_affected_version VARCHAR(20),  -- Ab dieser Version betroffen
    max_affected_version VARCHAR(20),  -- Bis zu dieser Version betroffen

    -- Aktion
    action VARCHAR(20) NOT NULL CHECK (action IN (
        'suggest',    -- Vorschlag zum Update
        'recommend',  -- Empfehlung mit Hinweis
        'require',    -- Erforderlich, aber App nutzbar
        'force'       -- App blockiert bis Update
    )),

    -- Nachricht
    title VARCHAR(200) NOT NULL,
    title_de VARCHAR(200),
    title_en VARCHAR(200),
    message TEXT NOT NULL,
    message_de TEXT,
    message_en TEXT,

    -- Zielversion
    target_version VARCHAR(20),  -- Empfohlene Zielversion

    -- Gültigkeit
    is_active BOOLEAN DEFAULT true,
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,

    -- Grund
    reason VARCHAR(100),  -- 'security', 'api_change', 'bug_fix', 'feature'

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

COMMENT ON TABLE force_update_rules IS 'Regeln für Update-Aufforderungen und App-Blockaden';
COMMENT ON COLUMN force_update_rules.action IS 'suggest=optional, recommend=empfohlen, require=erforderlich, force=blockiert';

-- Index für schnelle Lookup
CREATE INDEX IF NOT EXISTS idx_force_update_active
    ON force_update_rules(platform, is_active, starts_at, expires_at);

-- ============================================================================
-- 3. ANNOUNCEMENTS
-- ============================================================================
-- Systemweite Ankündigungen (Banner, Wartungsmeldungen, etc.)

CREATE TABLE IF NOT EXISTS announcements (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    slug VARCHAR(100) UNIQUE,  -- Für programmatischen Zugriff

    -- Inhalt
    title VARCHAR(200) NOT NULL,
    title_de VARCHAR(200),
    title_en VARCHAR(200),
    message TEXT NOT NULL,
    message_de TEXT,
    message_en TEXT,

    -- Typ und Darstellung
    type VARCHAR(30) NOT NULL CHECK (type IN (
        'info',           -- Informativ (blau)
        'success',        -- Erfolg (grün)
        'warning',        -- Warnung (gelb)
        'error',          -- Fehler/Kritisch (rot)
        'maintenance',    -- Wartung (orange)
        'feature',        -- Neues Feature (lila)
        'promotion'       -- Promotion (gold)
    )),

    -- Anzeigeort
    display_location VARCHAR(30) DEFAULT 'banner' CHECK (display_location IN (
        'banner',         -- Top-Banner in der App
        'modal',          -- Modal-Dialog
        'dashboard',      -- Nur auf Dashboard
        'login',          -- Nur auf Login-Screen
        'all'             -- Überall
    )),

    -- Zielgruppe
    target_roles TEXT[],  -- NULL = alle, ['investor', 'trader']
    target_platforms TEXT[],  -- NULL = alle, ['ios', 'macos']
    min_app_version VARCHAR(20),
    max_app_version VARCHAR(20),

    -- Link/Action
    action_url TEXT,
    action_label VARCHAR(100),
    action_label_de VARCHAR(100),
    action_label_en VARCHAR(100),

    -- Verhalten
    is_dismissible BOOLEAN DEFAULT true,  -- Kann weggeklickt werden
    show_once BOOLEAN DEFAULT false,  -- Nur einmal anzeigen
    priority INTEGER DEFAULT 0,  -- Höher = wichtiger

    -- Gültigkeit
    is_active BOOLEAN DEFAULT true,
    starts_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    expires_at TIMESTAMP WITH TIME ZONE,

    -- Statistiken
    view_count INTEGER DEFAULT 0,
    click_count INTEGER DEFAULT 0,
    dismiss_count INTEGER DEFAULT 0,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID
);

COMMENT ON TABLE announcements IS 'Systemweite Ankündigungen und Banner-Nachrichten';
COMMENT ON COLUMN announcements.slug IS 'Eindeutiger Bezeichner für programmatischen Zugriff';
COMMENT ON COLUMN announcements.show_once IS 'Wird nur einmal pro User angezeigt';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_announcements_active
    ON announcements(is_active, starts_at, expires_at);
CREATE INDEX IF NOT EXISTS idx_announcements_type
    ON announcements(type) WHERE is_active = true;

-- ============================================================================
-- 4. ANNOUNCEMENT_DISMISSALS
-- ============================================================================
-- Tracking welche User welche Ankündigungen dismissed haben

CREATE TABLE IF NOT EXISTS announcement_dismissals (
    id SERIAL PRIMARY KEY,
    announcement_id INTEGER NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,

    -- Aktion
    action VARCHAR(20) NOT NULL CHECK (action IN (
        'dismissed',  -- Weggeklickt
        'clicked',    -- Auf Action geklickt
        'viewed'      -- Nur angesehen
    )),

    -- Kontext
    platform VARCHAR(20),
    app_version VARCHAR(20),

    -- Zeitpunkt
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ein User kann eine Ankündigung nur einmal dismissen
    UNIQUE(announcement_id, user_id, action)
);

COMMENT ON TABLE announcement_dismissals IS 'Tracking von Nutzer-Interaktionen mit Ankündigungen';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_announcement_dismissals_user
    ON announcement_dismissals(user_id);
CREATE INDEX IF NOT EXISTS idx_announcement_dismissals_announcement
    ON announcement_dismissals(announcement_id);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- View für aktive Ankündigungen
CREATE OR REPLACE VIEW v_active_announcements AS
SELECT
    a.*,
    (SELECT COUNT(*) FROM announcement_dismissals ad
     WHERE ad.announcement_id = a.id AND ad.action = 'dismissed') AS total_dismissals,
    (SELECT COUNT(*) FROM announcement_dismissals ad
     WHERE ad.announcement_id = a.id AND ad.action = 'clicked') AS total_clicks
FROM announcements a
WHERE a.is_active = true
    AND a.starts_at <= NOW()
    AND (a.expires_at IS NULL OR a.expires_at > NOW())
ORDER BY a.priority DESC, a.created_at DESC;

-- View für Update-Check
CREATE OR REPLACE VIEW v_update_requirements AS
SELECT
    fur.platform,
    fur.action,
    fur.title,
    fur.message,
    fur.target_version,
    fur.reason,
    av.version AS latest_version,
    av.download_url,
    av.app_store_url
FROM force_update_rules fur
LEFT JOIN LATERAL (
    SELECT * FROM app_versions
    WHERE platform = fur.platform
    AND status = 'active'
    ORDER BY build_number DESC
    LIMIT 1
) av ON true
WHERE fur.is_active = true
    AND fur.starts_at <= NOW()
    AND (fur.expires_at IS NULL OR fur.expires_at > NOW());

-- ============================================================================
-- TRIGGER: Update Statistics
-- ============================================================================

CREATE OR REPLACE FUNCTION update_announcement_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.action = 'viewed' THEN
            UPDATE announcements SET view_count = view_count + 1 WHERE id = NEW.announcement_id;
        ELSIF NEW.action = 'clicked' THEN
            UPDATE announcements SET click_count = click_count + 1 WHERE id = NEW.announcement_id;
        ELSIF NEW.action = 'dismissed' THEN
            UPDATE announcements SET dismiss_count = dismiss_count + 1 WHERE id = NEW.announcement_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER announcement_stats_trigger
    AFTER INSERT ON announcement_dismissals
    FOR EACH ROW EXECUTE FUNCTION update_announcement_stats();

-- ============================================================================
-- INITIAL DATA
-- ============================================================================

-- Beispiel: Wartungsmodus-Ankündigung (initial deaktiviert)
INSERT INTO announcements (
    slug,
    title, title_de, title_en,
    message, message_de, message_en,
    type, display_location, is_dismissible, is_active
) VALUES (
    'maintenance_mode',
    'Scheduled Maintenance',
    'Geplante Wartung',
    'Scheduled Maintenance',
    'The system is undergoing maintenance. Some features may be temporarily unavailable.',
    'Das System wird gewartet. Einige Funktionen sind vorübergehend nicht verfügbar.',
    'The system is undergoing maintenance. Some features may be temporarily unavailable.',
    'maintenance',
    'banner',
    false,
    false  -- Deaktiviert bis benötigt
) ON CONFLICT (slug) DO NOTHING;

-- ============================================================================
-- END OF 002_schema_system.sql
-- ============================================================================
