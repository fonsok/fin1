#!/usr/bin/env python3
"""Seed Help Center FAQs via Parse REST API."""
import json
import time
import urllib.request

BASE = "http://127.0.0.1/parse"
APP_ID = "fin1-app-id"
MASTER = "fin1-master-key"

HEADERS = {
    "X-Parse-Application-Id": APP_ID,
    "X-Parse-Master-Key": MASTER,
    "Content-Type": "application/json",
}

def api_get(path):
    req = urllib.request.Request(f"{BASE}/{path}", headers=HEADERS)
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

def api_post(path, data):
    body = json.dumps(data).encode()
    req = urllib.request.Request(f"{BASE}/{path}", data=body, headers=HEADERS, method="POST")
    with urllib.request.urlopen(req) as resp:
        return json.loads(resp.read())

# Fetch category slug -> objectId map
cats_raw = api_get("classes/FAQCategory?limit=100")
cat_map = {r["slug"]: r["objectId"] for r in cats_raw.get("results", [])}
print("Categories:", ", ".join(f'{k}={v}' for k, v in cat_map.items()))

FAQS = [
    # Security (all)
    ("hc_security_1", "Wie kann ich mein Passwort ändern?",
     "Gehe zu **Profil > Einstellungen > Passwort ändern**. Du benötigst dein aktuelles Passwort und ein neues Passwort mit mindestens 8 Zeichen, einer Zahl und einem Sonderzeichen.",
     "security", 1, ["all"]),
    ("hc_security_2", "Was ist Zwei-Faktor-Authentifizierung (2FA)?",
     "2FA fügt eine zusätzliche Sicherheitsebene hinzu. Nach der Passworteingabe wird ein einmaliger Code per E-Mail oder SMS gesendet, den du eingeben musst.",
     "security", 2, ["all"]),
    ("hc_security_3", "Mein Account wurde gesperrt — was tun?",
     "Dein Account wird nach mehreren fehlgeschlagenen Anmeldeversuchen automatisch gesperrt. Warte 30 Minuten oder kontaktiere den Support über **Hilfe > Kontakt**.",
     "security", 3, ["all"]),

    # Investments (all)
    ("hc_investments_1", "Wie investiere ich in einen Trading-Pool?",
     "Navigiere zu **Trader entdecken**, wähle einen Trader aus und tippe auf **Investieren**. Gib den gewünschten Betrag ein und bestätige deine Investition.",
     "investments", 1, ["all"]),
    ("hc_investments_2", "Wie sehe ich meine aktuelle Rendite?",
     "Deine aktuelle Rendite findest du unter **Portfolio > Meine Investments**. Dort siehst du den aktuellen Wert, die Gesamtrendite und die Performance-Historie.",
     "investments", 2, ["all"]),
    ("hc_investments_3", "Kann ich mein Investment vorzeitig beenden?",
     "Ja. Gehe zu **Portfolio > Investment auswählen > Auszahlung anfordern**. Je nach Pool-Bedingungen kann eine Mindestanlagedauer gelten und es können Gebühren anfallen.",
     "investments", 3, ["all"]),

    # Investor Portfolio (investor)
    ("hc_investor_portfolio_1", "Wie diversifiziere ich mein Portfolio?",
     "Wir empfehlen, in mehrere Trader mit unterschiedlichen Handelsstrategien zu investieren. Unter **Trader entdecken** kannst du nach Risikoprofil, Performance und Strategie filtern.",
     "investor_portfolio", 1, ["investor"]),
    ("hc_investor_portfolio_2", "Was bedeuten die verschiedenen Risikostufen?",
     "**Konservativ**: Niedrigere, stabilere Renditen. **Moderat**: Ausgewogenes Verhältnis. **Aggressiv**: Höheres Renditepotenzial bei höherem Risiko. Dein Risikoprofil aus dem Onboarding hilft bei der Auswahl.",
     "investor_portfolio", 2, ["investor"]),

    # Trading (trader)
    ("hc_trading_1", "Wie erstelle ich eine neue Order?",
     "Gehe zu **Trading > Neue Order**. Wähle das Wertpapier, den Ordertyp (Market, Limit, Stop), die Menge und bestätige. Limit- und Stop-Orders erfordern die Angabe eines Preises.",
     "trading", 1, ["trader"]),
    ("hc_trading_2", "Was sind die Handelszeiten?",
     "Die regulären Handelszeiten sind Mo-Fr 08:00-22:00 Uhr (MEZ). Außerhalb dieser Zeiten werden Orders in die Warteschlange gestellt und bei Marktöffnung ausgeführt.",
     "trading", 2, ["trader"]),
    ("hc_trading_3", "Wie funktionieren Stop-Loss Orders?",
     "Eine Stop-Loss Order wird automatisch als Market-Order ausgeführt, wenn der Kurs einen bestimmten Preis erreicht, um potenzielle Verluste zu begrenzen.",
     "trading", 3, ["trader"]),

    # Trader Pools (trader)
    ("hc_trader_pools_1", "Wie erstelle ich einen Investment-Pool?",
     "Gehe zu **Mein Pool > Pool erstellen**. Definiere Name, Beschreibung, Mindestinvestition, Gebührenstruktur und Handelsstrategie. Nach der Freigabe können Investoren in deinen Pool investieren.",
     "trader_pools", 1, ["trader"]),
    ("hc_trader_pools_2", "Wie verwalte ich Investoren in meinem Pool?",
     "Unter **Mein Pool > Investoren** siehst du alle aktiven Investoren, deren Investitionsbeträge und Aktivitäten. Du kannst Auszahlungsanfragen bearbeiten.",
     "trader_pools", 2, ["trader"]),

    # Invoices (all)
    ("hc_invoices_1", "Wo finde ich meine Rechnungen und Abrechnungen?",
     "Gehe zu **Profil > Rechnungen & Abrechnungen**. Dort kannst du alle Rechnungen als PDF herunterladen. Abrechnungen werden monatlich erstellt.",
     "invoices", 1, ["all"]),
    ("hc_invoices_2", "Wie exportiere ich Unterlagen für die Steuererklärung?",
     "Unter **Profil > Rechnungen > Steuerexport** kannst du eine Jahresübersicht als PDF oder CSV exportieren. Diese enthält alle steuerrelevanten Transaktionen und Erträge.",
     "invoices", 2, ["all"]),

    # Notifications (all)
    ("hc_notifications_1", "Wie ändere ich meine Benachrichtigungseinstellungen?",
     "Gehe zu **Profil > Einstellungen > Benachrichtigungen**. Dort kannst du Push-Benachrichtigungen, E-Mail- und SMS-Benachrichtigungen einzeln aktivieren oder deaktivieren.",
     "notifications", 1, ["all"]),
    ("hc_notifications_2", "Warum erhalte ich keine Push-Benachrichtigungen?",
     "Prüfe: 1) Geräte-Einstellungen > {{APP_NAME}} > Mitteilungen müssen aktiviert sein. 2) In der App unter Profil > Einstellungen > Benachrichtigungen prüfen. 3) Bei weiterem Problem: App neu installieren.",
     "notifications", 2, ["all"]),

    # Technical (all)
    ("hc_technical_1", "Die App lässt sich nicht starten — was tun?",
     "Versuche: 1) App vollständig schließen und neu starten. 2) Gerät neu starten. 3) App löschen und aus dem App Store neu installieren. 4) Prüfe, ob genug Speicherplatz verfügbar ist.",
     "technical", 1, ["all"]),
    ("hc_technical_2", "Welche Geräte und iOS-Versionen werden unterstützt?",
     "{{APP_NAME}} unterstützt iPhones ab iPhone 12 mit iOS 16 oder neuer. Für die beste Erfahrung empfehlen wir die neueste iOS-Version.",
     "technical", 2, ["all"]),
    ("hc_technical_3", "Meine Verbindung zum Server ist instabil",
     "Prüfe deine Internetverbindung und versuche, zwischen WLAN und Mobilfunk zu wechseln. Falls das Problem bestehen bleibt, kann es an einer temporären Server-Wartung liegen — versuche es in einigen Minuten erneut.",
     "technical", 3, ["all"]),
]

created = 0
skipped = 0
for faq_id, question, answer, cat_slug, sort_order, target_roles in FAQS:
    cat_id = cat_map.get(cat_slug)
    if not cat_id:
        print(f"  SKIP (no category '{cat_slug}'): {faq_id}")
        skipped += 1
        continue

    # Check if already exists
    existing = api_get(f"classes/FAQ?where=%7B%22faqId%22%3A%22{faq_id}%22%7D&limit=1")
    if existing.get("results"):
        print(f"  EXISTS: {faq_id}")
        skipped += 1
        continue

    api_post("classes/FAQ", {
        "faqId": faq_id,
        "question": question,
        "questionDe": question,
        "answer": answer,
        "answerDe": answer,
        "categoryId": cat_id,
        "sortOrder": sort_order,
        "isPublished": True,
        "isArchived": False,
        "isPublic": False,
        "isUserVisible": True,
        "targetRoles": target_roles,
    })
    print(f"  CREATED: {faq_id} -> {question[:50]}")
    created += 1
    time.sleep(0.3)

print(f"\nDone: {created} created, {skipped} skipped")
