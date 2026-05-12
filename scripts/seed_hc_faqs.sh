#!/bin/bash
# Seed Help Center FAQs via Parse REST API
# Usage: ssh io@192.168.178.20 'bash /tmp/seed_hc_faqs.sh'

BASE="http://127.0.0.1/parse"
APP_ID="fin1-app-id"
MASTER="fin1-master-key"

# Get category map (slug -> objectId)
echo "Fetching categories..."
CATS=$(curl -s "$BASE/classes/FAQCategory?limit=100" \
  -H "X-Parse-Application-Id: $APP_ID" \
  -H "X-Parse-Master-Key: $MASTER")

get_cat_id() {
  echo "$CATS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for r in data.get('results', []):
    if r.get('slug') == '$1':
        print(r['objectId'])
        break
"
}

CAT_SECURITY=$(get_cat_id security)
CAT_INVESTMENTS=$(get_cat_id investments)
CAT_INVESTOR_PORTFOLIO=$(get_cat_id investor_portfolio)
CAT_TRADING=$(get_cat_id trading)
CAT_TRADER_POOLS=$(get_cat_id trader_pools)
CAT_INVOICES=$(get_cat_id invoices)
CAT_NOTIFICATIONS=$(get_cat_id notifications)
CAT_TECHNICAL=$(get_cat_id technical)

echo "Categories:"
echo "  security=$CAT_SECURITY"
echo "  investments=$CAT_INVESTMENTS"
echo "  investor_portfolio=$CAT_INVESTOR_PORTFOLIO"
echo "  trading=$CAT_TRADING"
echo "  trader_pools=$CAT_TRADER_POOLS"
echo "  invoices=$CAT_INVOICES"
echo "  notifications=$CAT_NOTIFICATIONS"
echo "  technical=$CAT_TECHNICAL"

create_faq() {
  local faq_id="$1"
  local question="$2"
  local answer="$3"
  local cat_id="$4"
  local sort_order="$5"
  local target_roles="$6"

  if [ -z "$cat_id" ]; then
    echo "SKIP (no category): $question"
    return
  fi

  # Check existing
  local existing=$(curl -s "$BASE/classes/FAQ?where=%7B%22faqId%22%3A%22$faq_id%22%7D&limit=1" \
    -H "X-Parse-Application-Id: $APP_ID" \
    -H "X-Parse-Master-Key: $MASTER" | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d.get('results',[])))")

  if [ "$existing" != "0" ]; then
    echo "SKIP (exists): $faq_id"
    return
  fi

  curl -s -X POST "$BASE/classes/FAQ" \
    -H "X-Parse-Application-Id: $APP_ID" \
    -H "X-Parse-Master-Key: $MASTER" \
    -H "Content-Type: application/json" \
    -d "{
      \"faqId\": \"$faq_id\",
      \"question\": $(python3 -c "import json; print(json.dumps('$question'))"),
      \"questionDe\": $(python3 -c "import json; print(json.dumps('$question'))"),
      \"answer\": $(python3 -c "import json; print(json.dumps('$answer'))"),
      \"answerDe\": $(python3 -c "import json; print(json.dumps('$answer'))"),
      \"categoryId\": \"$cat_id\",
      \"sortOrder\": $sort_order,
      \"isPublished\": true,
      \"isArchived\": false,
      \"isPublic\": false,
      \"isUserVisible\": true,
      \"targetRoles\": $target_roles
    }" > /dev/null

  echo "Created: $faq_id"
}

echo ""
echo "Creating Help Center FAQs..."

# Security (all)
create_faq "hc_security_1" "Wie kann ich mein Passwort ändern?" "Gehe zu **Profil > Einstellungen > Passwort ändern**. Du benötigst dein aktuelles Passwort und ein neues Passwort mit mindestens 8 Zeichen, einer Zahl und einem Sonderzeichen." "$CAT_SECURITY" 1 '["all"]'
create_faq "hc_security_2" "Was ist Zwei-Faktor-Authentifizierung (2FA)?" "2FA fügt eine zusätzliche Sicherheitsebene hinzu. Nach der Passworteingabe wird ein einmaliger Code per E-Mail oder SMS gesendet, den du eingeben musst." "$CAT_SECURITY" 2 '["all"]'
create_faq "hc_security_3" "Mein Account wurde gesperrt — was tun?" "Dein Account wird nach mehreren fehlgeschlagenen Anmeldeversuchen automatisch gesperrt. Warte 30 Minuten oder kontaktiere den Support über **Hilfe > Kontakt**." "$CAT_SECURITY" 3 '["all"]'

# Investments (all)
create_faq "hc_investments_1" "Wie investiere ich in einen Trading-Pool?" "Navigiere zu **Trader entdecken**, wähle einen Trader aus und tippe auf **Investieren**. Gib den gewünschten Betrag ein und bestätige deine Investition." "$CAT_INVESTMENTS" 1 '["all"]'
create_faq "hc_investments_2" "Wie sehe ich meine aktuelle Rendite?" "Deine aktuelle Rendite findest du unter **Investments**. Dort siehst du den aktuellen Wert, die Gesamtrendite und die Performance-Historie." "$CAT_INVESTMENTS" 2 '["all"]'
create_faq "hc_investments_3" "Kann ich mein Investment vorzeitig beenden?" "Ja. Gehe zu **Investments > Investment auswählen > Auszahlung anfordern**. Je nach Pool-Bedingungen kann eine Mindestanlagedauer gelten." "$CAT_INVESTMENTS" 3 '["all"]'

# Investor: Investments & Performance (investor)
create_faq "hc_investor_portfolio_1" "Wie diversifiziere ich meine Investments?" "Wir empfehlen, in mehrere Trader mit unterschiedlichen Handelsstrategien zu investieren. Unter **Trader entdecken** kannst du nach Risikoprofil, Performance und Strategie filtern." "$CAT_INVESTOR_PORTFOLIO" 1 '["investor"]'
create_faq "hc_investor_portfolio_2" "Was bedeuten die verschiedenen Risikostufen?" "**Konservativ**: Niedrigere, stabilere Renditen. **Moderat**: Ausgewogenes Verhältnis. **Aggressiv**: Höheres Renditepotenzial bei höherem Risiko." "$CAT_INVESTOR_PORTFOLIO" 2 '["investor"]'

# Trading (trader) — Produkt: strukturierte Derivate
create_faq "hc_trading_1" "Wie erstelle ich eine neue Order?" "Gehe zu **Trading > Neue Order**. Suche **Derivate** (z. B. Optionsscheine, Zertifikate) per WKN, ISIN oder Name. **Kein** Kassamarkthandel mit Aktien oder Spot-Devisen. Wähle Ordertyp (Market, Limit, Stop), Menge, bestätige." "$CAT_TRADING" 1 '["trader"]'
create_faq "hc_trading_2" "Was sind die Handelszeiten?" "Handel mit Derivaten nach relevanten Börsenzeiten (z. B. Mo–Fr). Außerhalb: Orders in Warteschlange, Ausführung bei Marktöffnung wenn Kurs erreicht." "$CAT_TRADING" 2 '["trader"]'
create_faq "hc_trading_3" "Wie funktionieren Stop-Loss Orders?" "Eine Stop-Loss Order wird automatisch als Market-Order ausgeführt, wenn der Kurs einen bestimmten Preis erreicht, um Verluste zu begrenzen." "$CAT_TRADING" 3 '["trader"]'

# Trader Pools (trader)
create_faq "hc_trader_pools_1" "Wie erstelle ich einen Investment-Pool?" "Gehe zu **Mein Pool > Pool erstellen**. Definiere Name, Beschreibung, Mindestinvestition und Gebührenstruktur." "$CAT_TRADER_POOLS" 1 '["trader"]'
create_faq "hc_trader_pools_2" "Wie verwalte ich Investoren in meinem Pool?" "Unter **Mein Pool > Investoren** siehst du alle aktiven Investoren, deren Investitionsbeträge und Aktivitäten." "$CAT_TRADER_POOLS" 2 '["trader"]'

# Invoices (all)
create_faq "hc_invoices_1" "Wo finde ich meine Rechnungen?" "Gehe zu **Profil > Rechnungen & Abrechnungen**. Dort kannst du alle Rechnungen als PDF herunterladen." "$CAT_INVOICES" 1 '["all"]'
create_faq "hc_invoices_2" "Wie exportiere ich Unterlagen für die Steuererklärung?" "Unter **Profil > Rechnungen > Steuerexport** kannst du eine Jahresübersicht als PDF oder CSV exportieren." "$CAT_INVOICES" 2 '["all"]'

# Notifications (all)
create_faq "hc_notifications_1" "Wie ändere ich meine Benachrichtigungseinstellungen?" "Gehe zu **Profil > Einstellungen > Benachrichtigungen**. Push, E-Mail und SMS einzeln konfigurieren." "$CAT_NOTIFICATIONS" 1 '["all"]'
create_faq "hc_notifications_2" "Warum erhalte ich keine Push-Benachrichtigungen?" "Prüfe die Geräte-Einstellungen und die In-App-Einstellungen. Bei weiterem Problem: App neu installieren." "$CAT_NOTIFICATIONS" 2 '["all"]'

# Technical (all)
create_faq "hc_technical_1" "Die App lässt sich nicht starten — was tun?" "Versuche: 1) App schließen und neu starten. 2) Gerät neu starten. 3) App löschen und neu installieren. 4) Speicherplatz prüfen." "$CAT_TECHNICAL" 1 '["all"]'
create_faq "hc_technical_2" "Welche Geräte werden unterstützt?" "{{APP_NAME}} unterstützt iPhones ab iPhone 12 mit iOS 16 oder neuer." "$CAT_TECHNICAL" 2 '["all"]'
create_faq "hc_technical_3" "Meine Verbindung zum Server ist instabil" "Prüfe deine Internetverbindung und versuche, zwischen WLAN und Mobilfunk zu wechseln." "$CAT_TECHNICAL" 3 '["all"]'

echo ""
echo "Done!"
