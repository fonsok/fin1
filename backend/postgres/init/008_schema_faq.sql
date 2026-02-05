-- ============================================================================
-- DATABASE SCHEMA
-- 008_schema_faq.sql - FAQ & Help System
-- ============================================================================
--
-- Dieses Schema verwaltet alle FAQ-Inhalte für Landing Page, User Help Center
-- und CSR Knowledge Base - unified in einer Struktur mit Visibility-Flags.
--
-- Tabellen (4):
--   1. faq_categories  - FAQ-Kategorien
--   2. faqs            - FAQ-Artikel (unified)
--   3. faq_feedback    - Feedback zu FAQs
--   4. faq_views       - View-Tracking
--
-- ============================================================================

-- ============================================================================
-- 1. FAQ_CATEGORIES
-- ============================================================================
-- Kategorien für FAQs (einheitlich für alle Systeme)

CREATE TABLE IF NOT EXISTS faq_categories (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    slug VARCHAR(50) NOT NULL UNIQUE,  -- z.B. 'getting_started'

    -- Namen (mehrsprachig)
    name VARCHAR(100) NOT NULL,
    name_de VARCHAR(100),
    name_en VARCHAR(100),

    -- Beschreibung
    description TEXT,
    description_de TEXT,
    description_en TEXT,

    -- Icon
    icon VARCHAR(50),  -- SF Symbol Name
    color VARCHAR(7),  -- Hex color

    -- Sichtbarkeit
    show_on_landing BOOLEAN DEFAULT false,     -- Öffentlich (vor Login)
    show_in_help_center BOOLEAN DEFAULT true,  -- User Help Center
    show_for_csr BOOLEAN DEFAULT true,         -- CSR Knowledge Base

    -- Zielgruppe
    target_roles TEXT[],  -- NULL = alle, ['investor', 'trader']

    -- Sortierung
    sort_order INTEGER DEFAULT 0,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Hierarchie (optional)
    parent_category_id INTEGER REFERENCES faq_categories(id),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE faq_categories IS 'Kategorien für FAQs (unified für Landing, Help Center, CSR)';
COMMENT ON COLUMN faq_categories.slug IS 'URL-freundlicher Identifier';

-- Index
CREATE INDEX IF NOT EXISTS idx_faq_categories_active
    ON faq_categories(is_active, sort_order) WHERE is_active = true;

-- ============================================================================
-- 2. FAQS
-- ============================================================================
-- Alle FAQ-Artikel (unified mit Visibility-Flags)

CREATE TABLE IF NOT EXISTS faqs (
    id SERIAL PRIMARY KEY,

    -- Kategorie
    category_id INTEGER NOT NULL REFERENCES faq_categories(id) ON DELETE CASCADE,

    -- Frage (mehrsprachig)
    question TEXT NOT NULL,
    question_de TEXT,
    question_en TEXT,

    -- Antwort (mehrsprachig, unterstützt Markdown)
    answer TEXT NOT NULL,
    answer_de TEXT,
    answer_en TEXT,

    -- Kurzantwort (für Vorschau)
    short_answer VARCHAR(500),
    short_answer_de VARCHAR(500),
    short_answer_en VARCHAR(500),

    -- Sichtbarkeit
    is_public BOOLEAN DEFAULT false,      -- Landing Page (öffentlich)
    is_user_visible BOOLEAN DEFAULT true, -- Help Center (eingeloggt)
    is_csr_visible BOOLEAN DEFAULT true,  -- CSR Knowledge Base (intern)

    -- Zielgruppe
    target_roles TEXT[],  -- NULL = alle, ['investor', 'trader']

    -- Sprache (Primärsprache)
    primary_language VARCHAR(5) DEFAULT 'de',

    -- Tags und Keywords
    tags TEXT[],
    keywords TEXT[],  -- Für Suche

    -- Analytics
    view_count INTEGER DEFAULT 0,
    helpful_count INTEGER DEFAULT 0,
    not_helpful_count INTEGER DEFAULT 0,
    search_count INTEGER DEFAULT 0,  -- Wie oft in Suchergebnissen

    -- Sortierung und Hervorhebung
    sort_order INTEGER DEFAULT 0,
    is_featured BOOLEAN DEFAULT false,
    is_pinned BOOLEAN DEFAULT false,

    -- Status
    is_published BOOLEAN DEFAULT true,
    is_archived BOOLEAN DEFAULT false,

    -- Quelle (für von CSR erstellte Artikel)
    source_ticket_id INTEGER,  -- FK zu support_tickets (später)
    source_type VARCHAR(20) CHECK (source_type IN (
        'manual',       -- Manuell erstellt
        'from_ticket',  -- Aus Ticket erstellt
        'imported'      -- Importiert
    )),

    -- Autor
    created_by UUID REFERENCES users(id),
    updated_by UUID REFERENCES users(id),

    -- Review
    needs_review BOOLEAN DEFAULT false,
    last_reviewed_at TIMESTAMP WITH TIME ZONE,
    last_reviewed_by UUID,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    published_at TIMESTAMP WITH TIME ZONE,
    archived_at TIMESTAMP WITH TIME ZONE
);

COMMENT ON TABLE faqs IS 'Unified FAQ-Artikel für Landing, Help Center und CSR';
COMMENT ON COLUMN faqs.is_public IS 'Sichtbar auf Landing Page (vor Login)';
COMMENT ON COLUMN faqs.is_user_visible IS 'Sichtbar im User Help Center';
COMMENT ON COLUMN faqs.is_csr_visible IS 'Sichtbar in CSR Knowledge Base';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_faqs_category ON faqs(category_id);
CREATE INDEX IF NOT EXISTS idx_faqs_public
    ON faqs(is_public, is_published) WHERE is_public = true AND is_published = true;
CREATE INDEX IF NOT EXISTS idx_faqs_user_visible
    ON faqs(is_user_visible, is_published) WHERE is_user_visible = true AND is_published = true;
CREATE INDEX IF NOT EXISTS idx_faqs_csr_visible
    ON faqs(is_csr_visible, is_published) WHERE is_csr_visible = true AND is_published = true;
CREATE INDEX IF NOT EXISTS idx_faqs_tags ON faqs USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_faqs_keywords ON faqs USING GIN(keywords);

-- ============================================================================
-- 3. FAQ_FEEDBACK
-- ============================================================================
-- Feedback zu FAQs (Helpful/Not Helpful + Kommentare)

CREATE TABLE IF NOT EXISTS faq_feedback (
    id SERIAL PRIMARY KEY,

    -- Beziehungen
    faq_id INTEGER NOT NULL REFERENCES faqs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),  -- NULL für anonyme (Landing)

    -- Feedback
    is_helpful BOOLEAN NOT NULL,

    -- Optional: Grund
    feedback_reason VARCHAR(50) CHECK (feedback_reason IN (
        'solved_problem',     -- Hat Problem gelöst
        'clear_explanation',  -- Klare Erklärung
        'incomplete',         -- Unvollständig
        'outdated',           -- Veraltet
        'confusing',          -- Verwirrend
        'wrong_answer',       -- Falsche Antwort
        'other'
    )),

    -- Kommentar
    comment TEXT,

    -- Kontext
    source VARCHAR(20) NOT NULL CHECK (source IN (
        'landing',      -- Landing Page
        'help_center',  -- User Help Center
        'csr'           -- CSR Knowledge Base
    )),

    -- Session-Tracking (für anonyme)
    session_id VARCHAR(100),

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Ein User kann nur einmal pro FAQ Feedback geben
    UNIQUE(faq_id, user_id) WHERE user_id IS NOT NULL
);

COMMENT ON TABLE faq_feedback IS 'Benutzer-Feedback zu FAQs';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_faq_feedback_faq ON faq_feedback(faq_id);
CREATE INDEX IF NOT EXISTS idx_faq_feedback_user ON faq_feedback(user_id) WHERE user_id IS NOT NULL;

-- Trigger zum Aktualisieren der Counts
CREATE OR REPLACE FUNCTION update_faq_feedback_counts()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.is_helpful THEN
            UPDATE faqs SET helpful_count = helpful_count + 1, updated_at = NOW() WHERE id = NEW.faq_id;
        ELSE
            UPDATE faqs SET not_helpful_count = not_helpful_count + 1, updated_at = NOW() WHERE id = NEW.faq_id;
        END IF;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.is_helpful THEN
            UPDATE faqs SET helpful_count = GREATEST(helpful_count - 1, 0), updated_at = NOW() WHERE id = OLD.faq_id;
        ELSE
            UPDATE faqs SET not_helpful_count = GREATEST(not_helpful_count - 1, 0), updated_at = NOW() WHERE id = OLD.faq_id;
        END IF;
    ELSIF TG_OP = 'UPDATE' AND OLD.is_helpful != NEW.is_helpful THEN
        IF NEW.is_helpful THEN
            UPDATE faqs SET
                helpful_count = helpful_count + 1,
                not_helpful_count = GREATEST(not_helpful_count - 1, 0),
                updated_at = NOW()
            WHERE id = NEW.faq_id;
        ELSE
            UPDATE faqs SET
                helpful_count = GREATEST(helpful_count - 1, 0),
                not_helpful_count = not_helpful_count + 1,
                updated_at = NOW()
            WHERE id = NEW.faq_id;
        END IF;
    END IF;
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER faq_feedback_counts_trigger
    AFTER INSERT OR UPDATE OR DELETE ON faq_feedback
    FOR EACH ROW EXECUTE FUNCTION update_faq_feedback_counts();

-- ============================================================================
-- 4. FAQ_VIEWS
-- ============================================================================
-- View-Tracking für FAQs (für Analytics)

CREATE TABLE IF NOT EXISTS faq_views (
    id BIGSERIAL PRIMARY KEY,

    -- Beziehungen
    faq_id INTEGER NOT NULL REFERENCES faqs(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id),  -- NULL für anonyme

    -- Kontext
    source VARCHAR(20) NOT NULL CHECK (source IN (
        'landing', 'help_center', 'csr', 'search', 'suggestion'
    )),

    -- Suche (falls über Suche gefunden)
    search_query TEXT,
    search_position INTEGER,  -- Position in Suchergebnissen

    -- Session
    session_id VARCHAR(100),

    -- Engagement
    time_spent_seconds INTEGER,  -- Zeit auf der FAQ
    scrolled_to_end BOOLEAN,
    clicked_related BOOLEAN,

    -- Zeitpunkt
    viewed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE faq_views IS 'View-Tracking für FAQ-Analytics';

-- Indexes (partitioniert nach Zeit empfohlen für große Datenmengen)
CREATE INDEX IF NOT EXISTS idx_faq_views_faq ON faq_views(faq_id);
CREATE INDEX IF NOT EXISTS idx_faq_views_time ON faq_views(viewed_at DESC);

-- Trigger zum Aktualisieren des View-Counts
CREATE OR REPLACE FUNCTION update_faq_view_count()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE faqs SET
        view_count = view_count + 1,
        search_count = CASE WHEN NEW.source = 'search' THEN search_count + 1 ELSE search_count END
    WHERE id = NEW.faq_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER faq_views_count_trigger
    AFTER INSERT ON faq_views
    FOR EACH ROW EXECUTE FUNCTION update_faq_view_count();

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Landing Page FAQs
CREATE OR REPLACE VIEW v_landing_faqs AS
SELECT
    f.id,
    fc.slug AS category_slug,
    fc.name AS category_name,
    fc.icon AS category_icon,
    f.question,
    f.answer,
    f.short_answer,
    f.tags,
    f.sort_order,
    f.is_featured
FROM faqs f
JOIN faq_categories fc ON f.category_id = fc.id
WHERE f.is_public = true
    AND f.is_published = true
    AND NOT f.is_archived
    AND fc.show_on_landing = true
    AND fc.is_active = true
ORDER BY fc.sort_order, f.sort_order, f.view_count DESC;

-- Help Center FAQs
CREATE OR REPLACE VIEW v_help_center_faqs AS
SELECT
    f.id,
    fc.slug AS category_slug,
    fc.name AS category_name,
    fc.icon AS category_icon,
    f.question,
    f.answer,
    f.short_answer,
    f.tags,
    f.keywords,
    f.view_count,
    f.helpful_count,
    f.not_helpful_count,
    CASE
        WHEN (f.helpful_count + f.not_helpful_count) > 0
        THEN ROUND(f.helpful_count::numeric / (f.helpful_count + f.not_helpful_count) * 100, 1)
        ELSE NULL
    END AS helpfulness_rate,
    f.sort_order,
    f.is_featured,
    f.target_roles
FROM faqs f
JOIN faq_categories fc ON f.category_id = fc.id
WHERE f.is_user_visible = true
    AND f.is_published = true
    AND NOT f.is_archived
    AND fc.show_in_help_center = true
    AND fc.is_active = true
ORDER BY fc.sort_order, f.is_featured DESC, f.sort_order, f.view_count DESC;

-- CSR Knowledge Base FAQs
CREATE OR REPLACE VIEW v_csr_knowledge_base AS
SELECT
    f.*,
    fc.slug AS category_slug,
    fc.name AS category_name,
    CASE
        WHEN (f.helpful_count + f.not_helpful_count) > 0
        THEN ROUND(f.helpful_count::numeric / (f.helpful_count + f.not_helpful_count) * 100, 1)
        ELSE NULL
    END AS helpfulness_rate,
    (f.helpful_count + f.not_helpful_count) AS total_feedback
FROM faqs f
JOIN faq_categories fc ON f.category_id = fc.id
WHERE f.is_csr_visible = true
    AND NOT f.is_archived
    AND fc.show_for_csr = true
    AND fc.is_active = true
ORDER BY fc.sort_order, f.sort_order;

-- FAQ Statistiken
CREATE OR REPLACE VIEW v_faq_statistics AS
SELECT
    fc.id AS category_id,
    fc.name AS category_name,
    COUNT(f.id) AS total_faqs,
    COUNT(f.id) FILTER (WHERE f.is_published) AS published_faqs,
    SUM(f.view_count) AS total_views,
    SUM(f.helpful_count) AS total_helpful,
    SUM(f.not_helpful_count) AS total_not_helpful,
    CASE
        WHEN SUM(f.helpful_count + f.not_helpful_count) > 0
        THEN ROUND(SUM(f.helpful_count)::numeric / SUM(f.helpful_count + f.not_helpful_count) * 100, 1)
        ELSE NULL
    END AS avg_helpfulness_rate,
    COUNT(f.id) FILTER (WHERE f.needs_review) AS needs_review_count
FROM faq_categories fc
LEFT JOIN faqs f ON fc.id = f.category_id AND NOT f.is_archived
GROUP BY fc.id, fc.name
ORDER BY fc.sort_order;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE TRIGGER faq_categories_updated_at
    BEFORE UPDATE ON faq_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER faqs_updated_at
    BEFORE UPDATE ON faqs
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INITIAL DATA - FAQ Categories
-- ============================================================================

INSERT INTO faq_categories (slug, name, name_de, name_en, icon, show_on_landing, show_in_help_center, show_for_csr, sort_order) VALUES
-- Landing Page Kategorien
('platform_overview', 'Platform Overview', 'Plattform-Übersicht', 'Platform Overview', 'info.circle', true, false, true, 1),
('getting_started', 'Getting Started', 'Erste Schritte', 'Getting Started', 'play.circle', true, false, true, 2),

-- Help Center Kategorien
('investments', 'Investments', 'Investitionen', 'Investments', 'chart.line.uptrend.xyaxis', true, true, true, 3),
('trading', 'Trading', 'Trading', 'Trading', 'arrow.left.arrow.right', false, true, true, 4),
('portfolio', 'Portfolio & Performance', 'Portfolio & Performance', 'Portfolio & Performance', 'chart.pie', false, true, true, 5),
('invoices', 'Invoices & Statements', 'Rechnungen & Auszüge', 'Invoices & Statements', 'doc.text', false, true, true, 6),
('security', 'Security & Authentication', 'Sicherheit & Authentifizierung', 'Security & Authentication', 'lock.shield', false, true, true, 7),
('notifications', 'Notifications', 'Benachrichtigungen', 'Notifications', 'bell', false, true, true, 8),
('technical', 'Technical Support', 'Technischer Support', 'Technical Support', 'wrench.and.screwdriver', false, true, true, 9)
ON CONFLICT (slug) DO NOTHING;

-- ============================================================================
-- END OF 008_schema_faq.sql
-- ============================================================================
