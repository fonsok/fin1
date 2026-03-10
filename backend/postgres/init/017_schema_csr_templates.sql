-- ============================================================================
-- DATABASE SCHEMA
-- 017_schema_csr_templates.sql - CSR Response Templates & Email Templates
-- ============================================================================
--
-- Dieses Schema verwaltet zentrale Textbausteine und E-Mail-Vorlagen für
-- Customer Support Representatives (CSR). Templates werden im Backend
-- gespeichert für:
--   - Zentrale Verwaltung ohne App-Update
--   - Echtzeit-Updates
--   - Mandantenfähigkeit
--   - Analytics (Nutzungsstatistiken)
--   - Admin-Portal Integration
--
-- Tabellen (4):
--   1. csr_response_templates      - Textbausteine für CSR-Kommunikation
--   2. csr_email_templates         - E-Mail-Vorlagen (Ticket-Events)
--   3. csr_template_categories     - Kategorien für Templates
--   4. csr_template_usage_stats    - Nutzungsstatistiken
--
-- ============================================================================

-- ============================================================================
-- 1. CSR_TEMPLATE_CATEGORIES
-- ============================================================================
-- Kategorien für Textbausteine (erweiterbar über Admin-Portal)

CREATE TABLE IF NOT EXISTS csr_template_categories (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    key VARCHAR(50) NOT NULL UNIQUE,  -- z.B. 'account_issues', 'technical'

    -- Anzeige
    display_name VARCHAR(100) NOT NULL,
    display_name_de VARCHAR(100),
    display_name_en VARCHAR(100),

    -- Beschreibung
    description TEXT,

    -- Icon (SF Symbol Name)
    icon VARCHAR(50) DEFAULT 'doc.text',

    -- Sortierung
    sort_order INTEGER DEFAULT 100,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Metadaten
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE csr_template_categories IS 'Kategorien für CSR-Textbausteine';

-- ============================================================================
-- 2. CSR_RESPONSE_TEMPLATES
-- ============================================================================
-- Zentrale Textbausteine für CSR-Kommunikation

CREATE TABLE IF NOT EXISTS csr_response_templates (
    id SERIAL PRIMARY KEY,

    -- Identifikation
    template_key VARCHAR(100) UNIQUE,  -- Optional: für programmatischen Zugriff

    -- Inhalt
    title VARCHAR(200) NOT NULL,
    title_de VARCHAR(200),
    title_en VARCHAR(200),

    -- Kategorie
    category_id INTEGER REFERENCES csr_template_categories(id),
    category_key VARCHAR(50),  -- Fallback wenn category_id NULL

    -- E-Mail-spezifisch (falls isEmail = true)
    subject VARCHAR(300),
    subject_de VARCHAR(300),
    subject_en VARCHAR(300),

    -- Template-Body
    body TEXT NOT NULL,
    body_de TEXT,
    body_en TEXT,

    -- Typ
    is_email BOOLEAN DEFAULT false,  -- true = E-Mail-Template, false = Chat-Snippet

    -- Rollenbasierter Zugriff (Array von CSR-Rollen)
    available_for_roles TEXT[] DEFAULT ARRAY['level_1', 'level_2', 'teamlead'],

    -- Platzhalter
    placeholders TEXT[],  -- z.B. ['{{KUNDENNAME}}', '{{TICKETNUMMER}}']

    -- Shortcut für schnellen Zugriff
    shortcut VARCHAR(20),  -- z.B. '/hi', '/close'

    -- Nutzung
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP WITH TIME ZONE,

    -- Status
    is_active BOOLEAN DEFAULT true,
    is_default BOOLEAN DEFAULT false,  -- System-Template (nicht löschbar)

    -- Versionierung
    version INTEGER DEFAULT 1,

    -- Audit
    created_by UUID,
    updated_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE csr_response_templates IS 'Zentrale Textbausteine für CSR-Kommunikation';
COMMENT ON COLUMN csr_response_templates.placeholders IS 'Liste der verfügbaren Platzhalter im Template';
COMMENT ON COLUMN csr_response_templates.shortcut IS 'Tastenkürzel für schnellen Zugriff (z.B. /hi)';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_csr_response_templates_category ON csr_response_templates(category_id);
CREATE INDEX IF NOT EXISTS idx_csr_response_templates_active ON csr_response_templates(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_csr_response_templates_roles ON csr_response_templates USING GIN(available_for_roles);
CREATE INDEX IF NOT EXISTS idx_csr_response_templates_shortcut ON csr_response_templates(shortcut) WHERE shortcut IS NOT NULL;

-- ============================================================================
-- 3. CSR_EMAIL_TEMPLATES
-- ============================================================================
-- E-Mail-Vorlagen für automatische Ticket-Benachrichtigungen

CREATE TABLE IF NOT EXISTS csr_email_templates (
    id SERIAL PRIMARY KEY,

    -- Typ (entspricht Event-Typ)
    type VARCHAR(50) NOT NULL UNIQUE CHECK (type IN (
        'ticket_created',
        'ticket_response',
        'ticket_status_change',
        'ticket_resolved',
        'ticket_closed',
        'ticket_reopened',
        'survey_request',
        'sla_warning',
        'escalation_notice'
    )),

    -- Anzeigename
    display_name VARCHAR(100) NOT NULL,

    -- Icon (SF Symbol)
    icon VARCHAR(50),

    -- Betreff
    subject VARCHAR(300) NOT NULL,
    subject_de VARCHAR(300),
    subject_en VARCHAR(300),

    -- HTML-Body (mit Platzhaltern)
    body_template TEXT NOT NULL,
    body_template_de TEXT,
    body_template_en TEXT,

    -- Plain-Text Version
    body_plain TEXT,
    body_plain_de TEXT,
    body_plain_en TEXT,

    -- Verfügbare Platzhalter
    available_placeholders TEXT[] NOT NULL,

    -- Status
    is_active BOOLEAN DEFAULT true,

    -- Versionierung
    version INTEGER DEFAULT 1,

    -- Audit
    created_by UUID,
    updated_by UUID,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE csr_email_templates IS 'E-Mail-Vorlagen für Ticket-Benachrichtigungen';

-- ============================================================================
-- 4. CSR_TEMPLATE_USAGE_STATS
-- ============================================================================
-- Nutzungsstatistiken für Analytics

CREATE TABLE IF NOT EXISTS csr_template_usage_stats (
    id BIGSERIAL PRIMARY KEY,

    -- Template-Referenz
    template_id INTEGER REFERENCES csr_response_templates(id) ON DELETE CASCADE,
    email_template_id INTEGER REFERENCES csr_email_templates(id) ON DELETE CASCADE,

    -- Agent (stores user ID as string for flexibility)
    agent_id VARCHAR(100),

    -- Kontext (stores ticket ID as string for flexibility)
    ticket_id VARCHAR(100),

    -- Zeitstempel
    used_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    -- Constraint: Entweder template_id oder email_template_id
    CONSTRAINT check_template_reference CHECK (
        (template_id IS NOT NULL AND email_template_id IS NULL) OR
        (template_id IS NULL AND email_template_id IS NOT NULL)
    )
);

COMMENT ON TABLE csr_template_usage_stats IS 'Nutzungsstatistiken für Template-Analytics';

-- Indexes
CREATE INDEX IF NOT EXISTS idx_template_usage_template ON csr_template_usage_stats(template_id);
CREATE INDEX IF NOT EXISTS idx_template_usage_email ON csr_template_usage_stats(email_template_id);
CREATE INDEX IF NOT EXISTS idx_template_usage_agent ON csr_template_usage_stats(agent_id);
CREATE INDEX IF NOT EXISTS idx_template_usage_time ON csr_template_usage_stats(used_at DESC);

-- ============================================================================
-- VIEWS
-- ============================================================================

-- Templates mit Kategorie-Info
CREATE OR REPLACE VIEW v_csr_templates AS
SELECT
    t.id,
    t.template_key,
    t.title,
    t.title_de,
    COALESCE(c.display_name, t.category_key) AS category_name,
    COALESCE(c.display_name_de, t.category_key) AS category_name_de,
    c.icon AS category_icon,
    t.subject,
    t.body,
    t.body_de,
    t.is_email,
    t.available_for_roles,
    t.placeholders,
    t.shortcut,
    t.usage_count,
    t.is_active,
    t.is_default,
    t.version,
    t.created_at,
    t.updated_at
FROM csr_response_templates t
LEFT JOIN csr_template_categories c ON t.category_id = c.id
WHERE t.is_active = true
ORDER BY c.sort_order, t.title;

-- Template-Nutzungsstatistiken aggregiert (created after usage_stats table exists)
-- Note: This view will be created after the csr_template_usage_stats table is available

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Funktion zum Erhöhen des Usage-Counters
CREATE OR REPLACE FUNCTION increment_template_usage(
    p_template_id INTEGER,
    p_agent_id INTEGER DEFAULT NULL,
    p_ticket_id BIGINT DEFAULT NULL
) RETURNS void AS $$
BEGIN
    -- Update usage count
    UPDATE csr_response_templates
    SET usage_count = usage_count + 1,
        last_used_at = NOW()
    WHERE id = p_template_id;

    -- Insert usage stat
    INSERT INTO csr_template_usage_stats (template_id, agent_id, ticket_id)
    VALUES (p_template_id, p_agent_id, p_ticket_id);
END;
$$ LANGUAGE plpgsql;

-- Funktion zum Abrufen von Templates für eine Rolle
CREATE OR REPLACE FUNCTION get_templates_for_role(p_role VARCHAR)
RETURNS TABLE (
    id INTEGER,
    title VARCHAR,
    category_name VARCHAR,
    body TEXT,
    is_email BOOLEAN,
    placeholders TEXT[],
    shortcut VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        t.id,
        t.title,
        COALESCE(c.display_name_de, c.display_name, t.category_key)::VARCHAR,
        t.body,
        t.is_email,
        t.placeholders,
        t.shortcut
    FROM csr_response_templates t
    LEFT JOIN csr_template_categories c ON t.category_id = c.id
    WHERE t.is_active = true
        AND p_role = ANY(t.available_for_roles)
    ORDER BY c.sort_order, t.title;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- HELPER FUNCTION (if not exists)
-- ============================================================================

-- Create update_updated_at_column function if it doesn't exist
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- TRIGGERS
-- ============================================================================

DROP TRIGGER IF EXISTS csr_template_categories_updated_at ON csr_template_categories;
CREATE TRIGGER csr_template_categories_updated_at
    BEFORE UPDATE ON csr_template_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS csr_response_templates_updated_at ON csr_response_templates;
CREATE TRIGGER csr_response_templates_updated_at
    BEFORE UPDATE ON csr_response_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS csr_email_templates_updated_at ON csr_email_templates;
CREATE TRIGGER csr_email_templates_updated_at
    BEFORE UPDATE ON csr_email_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================================================
-- INITIAL DATA - Categories
-- ============================================================================

INSERT INTO csr_template_categories (key, display_name, display_name_de, icon, sort_order) VALUES
('greeting', 'Greeting', 'Begrüßung', 'hand.wave.fill', 10),
('closing', 'Closing', 'Abschluss', 'flag.checkered', 20),
('account_issues', 'Account Issues', 'Kontoprobleme', 'person.crop.circle.badge.exclamationmark', 30),
('kyc_onboarding', 'KYC & Onboarding', 'KYC & Onboarding', 'checkmark.shield.fill', 40),
('transactions', 'Transactions', 'Transaktionen', 'arrow.left.arrow.right', 50),
('technical', 'Technical Support', 'Technischer Support', 'wrench.and.screwdriver.fill', 60),
('billing', 'Billing', 'Abrechnung', 'creditcard.fill', 70),
('security', 'Security', 'Sicherheit', 'lock.shield.fill', 80),
('compliance', 'Compliance', 'Compliance', 'checkmark.seal.fill', 90),
('fraud', 'Fraud', 'Betrugsprävention', 'exclamationmark.triangle.fill', 100),
('escalation', 'Escalation', 'Eskalation', 'arrow.up.circle.fill', 110),
('general', 'General', 'Allgemein', 'doc.text.fill', 999)
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- INITIAL DATA - Default Response Templates (migrated from Swift)
-- ============================================================================

-- Greetings (from CommonTemplates.swift)
INSERT INTO csr_response_templates (
    template_key, title, title_de, category_key, body, body_de,
    available_for_roles, placeholders, shortcut, is_default
) VALUES
(
    'greeting_standard',
    'Standard Greeting',
    'Standard Begrüßung',
    'greeting',
    'Hello {{KUNDENNAME}},

Thank you for your message. I will take care of your request.

Best regards',
    'Guten Tag {{KUNDENNAME}},

vielen Dank für Ihre Nachricht. Ich werde mich um Ihr Anliegen kümmern.

Mit freundlichen Grüßen',
    ARRAY['level_1', 'level_2', 'fraud_analyst', 'compliance_officer', 'tech_support', 'teamlead'],
    ARRAY['{{KUNDENNAME}}'],
    '/hi',
    true
),
(
    'greeting_formal',
    'Formal Greeting',
    'Formelle Begrüßung',
    'greeting',
    'Dear {{KUNDENNAME}},

Thank you for contacting us regarding ticket {{TICKETNUMMER}}. I am happy to assist you.',
    'Sehr geehrte/r {{KUNDENNAME}},

vielen Dank für Ihre Kontaktaufnahme bezüglich Ticket {{TICKETNUMMER}}. Ich freue mich, Ihnen helfen zu können.',
    ARRAY['level_1', 'level_2', 'fraud_analyst', 'compliance_officer', 'tech_support', 'teamlead'],
    ARRAY['{{KUNDENNAME}}', '{{TICKETNUMMER}}'],
    '/formal',
    true
)
ON CONFLICT (template_key) DO NOTHING;

-- Closings (from CommonTemplates.swift)
INSERT INTO csr_response_templates (
    template_key, title, title_de, category_key, body, body_de,
    available_for_roles, placeholders, shortcut, is_default
) VALUES
(
    'closing_standard',
    'Standard Closing',
    'Standard Abschluss',
    'closing',
    'If you have any further questions, please do not hesitate to contact us.

Best regards,
{{AGENTNAME}}
Customer Support',
    'Bei weiteren Fragen stehe ich Ihnen gerne zur Verfügung.

Mit freundlichen Grüßen,
{{AGENTNAME}}
Kundensupport',
    ARRAY['level_1', 'level_2', 'fraud_analyst', 'compliance_officer', 'tech_support', 'teamlead'],
    ARRAY['{{AGENTNAME}}'],
    '/close',
    true
),
(
    'closing_resolved',
    'Issue Resolved',
    'Problem gelöst',
    'closing',
    'I am glad we could resolve your issue. If you need any further assistance, please let us know.

Best regards,
{{AGENTNAME}}',
    'Es freut mich, dass wir Ihr Anliegen lösen konnten. Falls Sie weitere Unterstützung benötigen, melden Sie sich gerne.

Mit freundlichen Grüßen,
{{AGENTNAME}}',
    ARRAY['level_1', 'level_2', 'fraud_analyst', 'compliance_officer', 'tech_support', 'teamlead'],
    ARRAY['{{AGENTNAME}}'],
    '/resolved',
    true
)
ON CONFLICT (template_key) DO NOTHING;

-- Account Issues (from Level1Templates.swift)
INSERT INTO csr_response_templates (
    template_key, title, title_de, category_key, body, body_de,
    available_for_roles, placeholders, is_default
) VALUES
(
    'password_reset_guide',
    'Password Reset Guide',
    'Passwort-Reset Anleitung',
    'account_issues',
    'Hello {{KUNDENNAME}},

To reset your password, please follow these steps:

1. Open the app
2. Tap "Sign In"
3. Select "Forgot Password?"
4. Enter your email address
5. You will receive a reset link via email

The link is valid for 24 hours. If you do not receive an email, please check your spam folder.

If you have any further questions, I am happy to help.',
    'Guten Tag {{KUNDENNAME}},

um Ihr Passwort zurückzusetzen, gehen Sie bitte wie folgt vor:

1. Öffnen Sie die App
2. Tippen Sie auf "Anmelden"
3. Wählen Sie "Passwort vergessen?"
4. Geben Sie Ihre E-Mail-Adresse ein
5. Sie erhalten einen Link zum Zurücksetzen per E-Mail

Der Link ist 24 Stunden gültig. Falls Sie keine E-Mail erhalten, prüfen Sie bitte auch Ihren Spam-Ordner.

Bei weiteren Fragen stehe ich Ihnen gerne zur Verfügung.',
    ARRAY['level_1', 'level_2', 'teamlead'],
    ARRAY['{{KUNDENNAME}}'],
    true
),
(
    'email_changed',
    'Email Address Changed',
    'E-Mail-Adresse geändert',
    'account_issues',
    'Hello {{KUNDENNAME}},

I have changed your email address to {{NEUE_EMAIL}} as requested.

Please note:
• You will receive a confirmation to your new email address
• Future notifications will be sent to the new address
• Your login credentials remain unchanged

The change is effective immediately.',
    'Guten Tag {{KUNDENNAME}},

ich habe Ihre E-Mail-Adresse wie gewünscht auf {{NEUE_EMAIL}} geändert.

Bitte beachten Sie:
• Sie erhalten eine Bestätigung an Ihre neue E-Mail-Adresse
• Künftige Benachrichtigungen gehen an die neue Adresse
• Ihre Login-Daten bleiben unverändert

Die Änderung ist sofort wirksam.',
    ARRAY['level_1', 'level_2', 'teamlead'],
    ARRAY['{{KUNDENNAME}}', '{{NEUE_EMAIL}}'],
    true
),
(
    'account_unlocked',
    'Account Unlocked',
    'Konto entsperrt',
    'account_issues',
    'Hello {{KUNDENNAME}},

Your account has been successfully unlocked. You can now log in again.

**Important Security Notes:**
• Use a strong, unique password
• Enable Two-Factor Authentication (2FA)
• Report suspicious activity immediately

If you did not initiate the lock, please contact us immediately.

Best regards,
{{AGENTNAME}}
Customer Support',
    'Guten Tag {{KUNDENNAME}},

Ihr Konto wurde erfolgreich entsperrt. Sie können sich jetzt wieder anmelden.

**Wichtige Sicherheitshinweise:**
• Verwenden Sie ein starkes, einzigartiges Passwort
• Aktivieren Sie die Zwei-Faktor-Authentifizierung (2FA)
• Melden Sie verdächtige Aktivitäten sofort

Falls Sie die Sperrung nicht veranlasst haben, kontaktieren Sie uns bitte umgehend.

Mit freundlichen Grüßen,
{{AGENTNAME}}
Kundensupport',
    ARRAY['level_2', 'teamlead'],
    ARRAY['{{KUNDENNAME}}', '{{AGENTNAME}}'],
    true
)
ON CONFLICT (template_key) DO NOTHING;

-- Technical Support (from TechSupportTemplates.swift)
INSERT INTO csr_response_templates (
    template_key, title, title_de, category_key, body, body_de,
    available_for_roles, placeholders, shortcut, is_default
) VALUES
(
    'app_update_required',
    'App Update Required',
    'App-Update erforderlich',
    'technical',
    'Hello {{KUNDENNAME}},

Please update the app to the latest version:

• iOS: App Store → Updates
• Android: Play Store → My Apps

The latest version fixes known issues and improves stability.',
    'Guten Tag {{KUNDENNAME}},

bitte aktualisieren Sie die App auf die neueste Version:

• iOS: App Store → Updates
• Android: Play Store → Meine Apps

Die neueste Version behebt bekannte Probleme und verbessert die Stabilität.',
    ARRAY['level_1', 'level_2', 'tech_support', 'teamlead'],
    ARRAY['{{KUNDENNAME}}'],
    '/update',
    true
),
(
    'clear_cache',
    'Clear Cache Instructions',
    'Cache leeren Anleitung',
    'technical',
    'Hello {{KUNDENNAME}},

Please try the following steps:

1. Close the app completely (not just minimize)
2. Go to Device Settings → Apps → [App Name] → Clear Cache
3. Restart the app

If the problem persists, please contact us again.',
    'Guten Tag {{KUNDENNAME}},

bitte versuchen Sie folgende Schritte:

1. App vollständig schließen (nicht nur minimieren)
2. In den Geräte-Einstellungen → Apps → [App-Name] → Cache leeren
3. App neu starten

Sollte das Problem weiterhin bestehen, melden Sie sich bitte erneut.',
    ARRAY['level_1', 'level_2', 'tech_support', 'teamlead'],
    ARRAY['{{KUNDENNAME}}'],
    '/cache',
    true
),
(
    'known_issue',
    'Known Issue',
    'Bekanntes Problem',
    'technical',
    'Hello {{KUNDENNAME}},

Thank you for your report. This is a known issue, and our development team is already working on a solution. We will inform you as soon as an update is available.',
    'Guten Tag {{KUNDENNAME}},

vielen Dank für Ihre Meldung. Dies ist uns als bekanntes Problem bewusst, und unser Entwicklerteam arbeitet bereits an einer Lösung. Wir werden Sie informieren, sobald ein Update verfügbar ist.',
    ARRAY['level_1', 'level_2', 'tech_support', 'teamlead'],
    ARRAY['{{KUNDENNAME}}'],
    '/known',
    true
)
ON CONFLICT (template_key) DO NOTHING;

-- KYC Templates (from Level2Templates.swift)
INSERT INTO csr_response_templates (
    template_key, title, title_de, category_key, subject, subject_de, body, body_de,
    is_email, available_for_roles, placeholders, is_default
) VALUES
(
    'kyc_documents_required',
    'KYC Documents Required',
    'KYC-Dokumente nachfordern',
    'kyc_onboarding',
    'Additional documents required for your account verification',
    'Zusätzliche Dokumente für Ihre Kontoverifizierung',
    'Hello {{KUNDENNAME}},

Thank you for your registration.

To complete your identity verification (KYC), we still need the following documents:

{{FEHLENDE_DOKUMENTE}}

**Document Requirements:**
• Clearly readable, not blurry
• Fully visible (all corners)
• Valid expiration date
• Maximum 10 MB per file (JPG, PNG or PDF)

Please upload the documents in the app under "Profile" → "Documents".

If you have any questions, we are happy to help.

Best regards,
{{AGENTNAME}}
Customer Support',
    'Guten Tag {{KUNDENNAME}},

vielen Dank für Ihre Registrierung.

Zur Vervollständigung Ihrer Identitätsprüfung (KYC) benötigen wir noch folgende Unterlagen:

{{FEHLENDE_DOKUMENTE}}

**Anforderungen an die Dokumente:**
• Gut lesbar, nicht verschwommen
• Vollständig sichtbar (alle Ecken)
• Gültiges Ablaufdatum
• Maximal 10 MB pro Datei (JPG, PNG oder PDF)

Bitte laden Sie die Dokumente in der App unter "Profil" → "Dokumente" hoch.

Bei Fragen stehen wir Ihnen gerne zur Verfügung.

Mit freundlichen Grüßen,
{{AGENTNAME}}
Kundensupport',
    true,
    ARRAY['level_2', 'compliance_officer', 'teamlead'],
    ARRAY['{{KUNDENNAME}}', '{{FEHLENDE_DOKUMENTE}}', '{{AGENTNAME}}'],
    true
)
ON CONFLICT (template_key) DO NOTHING;

-- Security Templates (from Level2Templates.swift)
INSERT INTO csr_response_templates (
    template_key, title, title_de, category_key, body, body_de,
    available_for_roles, placeholders, is_default
) VALUES
(
    'suspicious_activity_confirm',
    'Confirm Suspicious Activity',
    'Verdächtige Aktivität bestätigen',
    'security',
    'Hello {{KUNDENNAME}},

We have detected the following activity on your account:

• Date/Time: {{DATUM_UHRZEIT}}
• Activity: {{AKTIVITAET}}
• IP Address/Location: {{STANDORT}}

**Was this you?**

✅ Yes, that was me → Please reply with "Confirmed"
❌ No, that was not me → Please contact us immediately

Your security is our highest priority.',
    'Guten Tag {{KUNDENNAME}},

wir haben folgende Aktivität auf Ihrem Konto festgestellt:

• Datum/Uhrzeit: {{DATUM_UHRZEIT}}
• Aktivität: {{AKTIVITAET}}
• IP-Adresse/Standort: {{STANDORT}}

**Waren Sie das?**

✅ Ja, das war ich → Antworten Sie bitte mit "Bestätigt"
❌ Nein, das war ich nicht → Kontaktieren Sie uns sofort

Ihre Sicherheit hat für uns höchste Priorität.',
    ARRAY['fraud_analyst', 'level_2', 'teamlead'],
    ARRAY['{{KUNDENNAME}}', '{{DATUM_UHRZEIT}}', '{{AKTIVITAET}}', '{{STANDORT}}'],
    true
)
ON CONFLICT (template_key) DO NOTHING;

-- Transactions (from Level2Templates.swift)
INSERT INTO csr_response_templates (
    template_key, title, title_de, category_key, body, body_de,
    available_for_roles, placeholders, is_default
) VALUES
(
    'transaction_explanation',
    'Transaction Explanation',
    'Transaktion erklären',
    'transactions',
    'Hello {{KUNDENNAME}},

Regarding your inquiry about the transaction from {{DATUM}}:

**Transaction Details:**
• Amount: {{BETRAG}}
• Type: {{TRANSAKTIONSTYP}}
• Status: {{STATUS}}
• Reference: {{REFERENZ}}

{{ERKLAERUNG}}

If you have any further questions, I am happy to help.',
    'Guten Tag {{KUNDENNAME}},

bezüglich Ihrer Anfrage zur Transaktion vom {{DATUM}}:

**Transaktionsdetails:**
• Betrag: {{BETRAG}}
• Typ: {{TRANSAKTIONSTYP}}
• Status: {{STATUS}}
• Referenz: {{REFERENZ}}

{{ERKLAERUNG}}

Falls Sie weitere Fragen haben, helfe ich Ihnen gerne weiter.',
    ARRAY['level_2', 'fraud_analyst', 'compliance_officer', 'teamlead'],
    ARRAY['{{KUNDENNAME}}', '{{DATUM}}', '{{BETRAG}}', '{{TRANSAKTIONSTYP}}', '{{STATUS}}', '{{REFERENZ}}', '{{ERKLAERUNG}}'],
    true
),
(
    'refund_initiated',
    'Refund Initiated',
    'Rückerstattung eingeleitet',
    'billing',
    'Hello {{KUNDENNAME}},

I have initiated a refund for you. The amount will be credited to your account within 5-7 business days.',
    'Guten Tag {{KUNDENNAME}},

ich habe eine Rückerstattung für Sie eingeleitet. Der Betrag wird innerhalb von 5-7 Werktagen auf Ihrem Konto gutgeschrieben.',
    ARRAY['level_2', 'teamlead'],
    ARRAY['{{KUNDENNAME}}'],
    true
)
ON CONFLICT (template_key) DO NOTHING;

-- ============================================================================
-- INITIAL DATA - Email Templates
-- ============================================================================

INSERT INTO csr_email_templates (
    type, display_name, icon, subject, subject_de, body_template, body_template_de, available_placeholders
) VALUES
(
    'ticket_created',
    'Ticket Created',
    'plus.circle.fill',
    '[{{companyName}}] Ticket {{ticketNumber}} created',
    '[{{companyName}}] Ticket {{ticketNumber}} wurde erstellt',
    'Hello {{customerName}},

Thank you for your inquiry. We have successfully created your support ticket.

Ticket Details:
• Ticket Number: {{ticketNumber}}
• Subject: {{ticketSubject}}
• Priority: {{ticketPriority}}

Your concern:
{{ticketDescription}}

Our support team will get back to you as soon as possible.

Best regards,
Your {{companyName}} Support Team

---
You can track the status of your ticket at any time in the app.',
    'Guten Tag {{customerName}},

vielen Dank für Ihre Anfrage. Wir haben Ihr Support-Ticket erfolgreich erstellt.

Ticket-Details:
• Ticket-Nummer: {{ticketNumber}}
• Betreff: {{ticketSubject}}
• Priorität: {{ticketPriority}}

Ihr Anliegen:
{{ticketDescription}}

Unser Support-Team wird sich schnellstmöglich bei Ihnen melden.

Mit freundlichen Grüßen,
Ihr {{companyName}} Support-Team

---
Sie können den Status Ihres Tickets jederzeit in der App verfolgen.',
    ARRAY['customerName', 'ticketNumber', 'ticketSubject', 'ticketPriority', 'ticketDescription', 'companyName']
),
(
    'ticket_response',
    'New Response',
    'bubble.left.fill',
    '[{{companyName}}] New response to Ticket {{ticketNumber}}',
    '[{{companyName}}] Neue Antwort auf Ticket {{ticketNumber}}',
    'Hello {{customerName}},

You have received a new response to your support ticket.

Ticket: {{ticketNumber}} - {{ticketSubject}}

Response from {{agentName}}:
{{responseMessage}}

---

To reply, please open the app or respond directly to this email.

Best regards,
Your {{companyName}} Support Team',
    'Guten Tag {{customerName}},

Sie haben eine neue Antwort auf Ihr Support-Ticket erhalten.

Ticket: {{ticketNumber}} - {{ticketSubject}}

Antwort von {{agentName}}:
{{responseMessage}}

---

Um zu antworten, öffnen Sie bitte die App oder antworten Sie direkt auf diese E-Mail.

Mit freundlichen Grüßen,
Ihr {{companyName}} Support-Team',
    ARRAY['customerName', 'ticketNumber', 'ticketSubject', 'agentName', 'responseMessage', 'companyName']
),
(
    'ticket_resolved',
    'Ticket Resolved',
    'checkmark.circle.fill',
    '[{{companyName}}] Ticket {{ticketNumber}} resolved ✓',
    '[{{companyName}}] Ticket {{ticketNumber}} wurde gelöst ✓',
    'Hello {{customerName}},

Good news! Your support ticket has been resolved.

Ticket: {{ticketNumber}} - {{ticketSubject}}
Handled by: {{agentName}}

Resolution Summary:
{{resolutionSummary}}

If the problem persists, you can reopen this ticket within 7 days.

Best regards,
Your {{companyName}} Support Team',
    'Guten Tag {{customerName}},

gute Nachrichten! Ihr Support-Ticket wurde gelöst.

Ticket: {{ticketNumber}} - {{ticketSubject}}
Bearbeitet von: {{agentName}}

Zusammenfassung der Lösung:
{{resolutionSummary}}

Sollte das Problem weiterhin bestehen, können Sie dieses Ticket innerhalb von 7 Tagen wiedereröffnen.

Mit freundlichen Grüßen,
Ihr {{companyName}} Support-Team',
    ARRAY['customerName', 'ticketNumber', 'ticketSubject', 'agentName', 'resolutionSummary', 'companyName']
),
(
    'survey_request',
    'Survey Request',
    'star.fill',
    '[{{companyName}}] How was our support? ⭐',
    '[{{companyName}}] Wie war unser Support? ⭐',
    'Hello {{customerName}},

Your support ticket {{ticketNumber}} was handled by {{agentName}}.

We would be delighted if you could take a moment to rate our service.

Your feedback helps us continuously improve our support.

→ Rate now: {{surveyLink}}

Thank you for your support!

Best regards,
Your {{companyName}} Support Team',
    'Guten Tag {{customerName}},

Ihr Support-Ticket {{ticketNumber}} wurde von {{agentName}} bearbeitet.

Wir würden uns freuen, wenn Sie sich einen Moment Zeit nehmen könnten, um unseren Service zu bewerten.

Ihre Meinung hilft uns, unseren Support kontinuierlich zu verbessern.

→ Jetzt bewerten: {{surveyLink}}

Vielen Dank für Ihre Unterstützung!

Mit freundlichen Grüßen,
Ihr {{companyName}} Support-Team',
    ARRAY['customerName', 'ticketNumber', 'agentName', 'surveyLink', 'companyName']
),
(
    'sla_warning',
    'SLA Warning',
    'exclamationmark.triangle.fill',
    '⚠️ SLA Warning: Ticket {{ticketNumber}}',
    '⚠️ SLA-Warnung: Ticket {{ticketNumber}}',
    'Attention!

The following ticket is approaching its SLA deadline:

Ticket: {{ticketNumber}} - {{ticketSubject}}
Customer: {{customerName}}
Time Remaining: {{timeRemaining}}
Deadline: {{deadline}}

Please handle this ticket immediately.

---
This email was automatically generated.',
    'Achtung!

Das folgende Ticket nähert sich der SLA-Deadline:

Ticket: {{ticketNumber}} - {{ticketSubject}}
Kunde: {{customerName}}
Verbleibende Zeit: {{timeRemaining}}
Deadline: {{deadline}}

Bitte bearbeiten Sie dieses Ticket umgehend.

---
Diese E-Mail wurde automatisch generiert.',
    ARRAY['ticketNumber', 'ticketSubject', 'customerName', 'timeRemaining', 'deadline']
)
ON CONFLICT (type) DO NOTHING;

-- ============================================================================
-- END OF 017_schema_csr_templates.sql
-- ============================================================================
