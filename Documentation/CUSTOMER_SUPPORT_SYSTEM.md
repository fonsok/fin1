# FIN1 Customer Support System (CSR) – Zielarchitektur

**Version**: 2.1
**Zielmarkt**: EU (PSD2, AML/KYC, DSGVO-konform)
**Status**: ✅ Implementiert
**Letzte Aktualisierung**: Januar 2026 (Refactoring für Dateigröße-Compliance)

---

## 1. Systemarchitektur (Übersicht)

### Kanäle
- **In-App-Chat**: Primärkanal via SDK (z.B. Intercom, Zendesk SDK), verschlüsselt, DSGVO-konform
- **E-Mail**: Über Ticketing-System, automatische Ticket-Erstellung
- **Telefon** (optional): VoIP-Integration mit CRM-Popup, Gesprächsprotokollierung

### Komponenten
- **Ticketing/CRM**: Zendesk, Freshdesk oder Salesforce Service Cloud
- **Wissensdatenbank**: Self-Service FAQ (siehe `FAQ_SUPPORT.md`) + internes Playbook
- **Identity-Check-Integration**: Anbindung an KYC-Provider (z.B. IDnow, Onfido)
- **Audit-Trail-System**: Lückenlose Protokollierung aller Aktionen (DSGVO Art. 30)
- **Eskalations-Engine**: Automatische Weiterleitung nach Ticket-Typ/SLA

### Datenhaltung
- Kundendaten nur lesend für CSR (Ausnahme: definierte Schreibrechte pro Rolle)
- Personenbezogene Daten pseudonymisiert in Logs
- Aufbewahrung: 10 Jahre für regulatorisch relevante Dokumente

**⚠️ Offene Annahme**: CRM-Auswahl noch nicht finalisiert. Empfehlung: Zendesk (DSGVO-zertifiziert, EU-Rechenzentrum verfügbar).

---

## 2. Rollen- und Berechtigungsmodell

| Rolle | Datenzugriff | Typische Aktionen | Einschränkungen |
|-------|--------------|-------------------|-----------------|
| **Level 1 (L1)** | Basis-Kundendaten, Investment-Übersicht (keine Trade-Details), FAQ | Ticket-Annahme, Standardanfragen, Weiterleitung | ❌ **Kein Trade-Zugriff** (Banking Best Practice), kein KYC-Zugriff, keine Kontoänderungen |
| **Level 2 (L2)** | + **Trade-Details** (Preise, Volumen, Strategien), Kontobewegungen, KYC-Status (lesend) | Komplexe Anfragen, Trade-Support, Kontoeinstellungen, Eskalation | Keine Sperrungen, keine Auszahlungsfreigaben |
| **Compliance** | Voller KYC-Zugriff, AML-Flags, DSGVO-Anfragen | KYC-Prüfung, AML-Meldungen, Auskunftsersuchen | **🔒 4-Augen bei AML-Meldungen** |
| **Fraud** | Transaktionsmuster, Gerätedaten, Login-Historie | Betrugsprüfung, Kontosperrung, Kartenblockierung | **🔒 4-Augen bei Kontosperrung >24h** |
| **Tech Support** | Logs, Fehlerprotokolle, App-Version | Bug-Analyse, Workarounds, Eskalation an Dev | Kein Kundendaten-Schreibzugriff |
| **Teamlead** | Alle Rollen lesend + Metriken | Eskalationsfreigabe, Qualitätskontrolle, Reporting | **🔒 Genehmiger für sensible Aktionen** |

**🔒 = Rechtlich sensitiver Vorgang, erfordert manuelle Freigabe oder 4-Augen-Prinzip**

---

## 3. Prozesse & Playbooks (Kern-Use-Cases)

### 3.1 Onboarding / KYC-Probleme

**Trigger**: Kunde kann KYC nicht abschließen, Dokument abgelehnt

| Schritt | Aktion | Rolle | 🔒 Sensitiv? |
|---------|--------|-------|--------------|
| 1 | Ticket klassifizieren, KYC-Status prüfen | L1 | Nein |
| 2 | Ablehnungsgrund aus KYC-System abrufen | L2 | Nein |
| 3 | Kunde informieren, neues Dokument anfordern | L2 | Nein |
| 4 | Bei wiederholter Ablehnung: Compliance eskalieren | L2→Compliance | Nein |
| 5 | **Manuelle KYC-Entscheidung** | Compliance | **🔒 Ja** |
| 6 | Entscheidung dokumentieren (Audit-Trail) | Compliance | **🔒 Ja** |

**Eskalation**: Nach 2 fehlgeschlagenen Versuchen → Compliance Review

---

### 3.2 Kontosperrung (Fraud-Verdacht)

**Trigger**: Automatische Sperrung durch Fraud-Engine oder manuelle Meldung

| Schritt | Aktion | Rolle | 🔒 Sensitiv? |
|---------|--------|-------|--------------|
| 1 | Fraud-Alert prüfen, Transaktionsmuster analysieren | Fraud | Nein |
| 2 | Sofort-Sperrung bei akuter Gefahr (<24h) | Fraud | Nein |
| 3 | **Verlängerung Sperrung >24h** | Fraud + Teamlead | **🔒 4-Augen** |
| 4 | Kundenbenachrichtigung (gesetzliche Frist beachten) | L2 | **🔒 Ja** |
| 5 | **Kontowiederherstellung oder endgültige Schließung** | Compliance + Teamlead | **🔒 4-Augen** |
| 6 | SAR-Meldung an FIU (bei Verdacht) | Compliance | **🔒 Meldepflicht** |

**⚠️ WICHTIG**: Keine Vorab-Information an Kunden bei laufender SAR-Prüfung (Tipping-Off-Verbot)

---

### 3.3 Kartenverlust / Kartendiebstahl

**Trigger**: Kunde meldet Karte verloren/gestohlen

| Schritt | Aktion | Rolle | 🔒 Sensitiv? |
|---------|--------|-------|--------------|
| 1 | Sofortige Kartensperre (Self-Service oder CSR) | L1/Automatisch | Nein |
| 2 | Identität verifizieren (Sicherheitsfragen/2FA) | L1 | Nein |
| 3 | Letzte Transaktionen prüfen, unautorisierte markieren | L2 | Nein |
| 4 | Ersatzkarte bestellen | L2 | Nein |
| 5 | Bei unautorisierte Transaktionen: Chargeback einleiten | Fraud | **🔒 Ja** |

**SLA**: Kartensperre innerhalb 5 Minuten nach Meldung

---

### 3.4 Transaktionsdispute

**Trigger**: Kunde erkennt Transaktion nicht an

| Schritt | Aktion | Rolle | 🔒 Sensitiv? |
|---------|--------|-------|--------------|
| 1 | Dispute-Details aufnehmen (Betrag, Datum, Händler) | L1 | Nein |
| 2 | Transaktionsdetails aus Backend abrufen | L2 | Nein |
| 3 | Erste Prüfung: Legitime Transaktion? | L2 | Nein |
| 4 | **Chargeback-Prozess einleiten (>50€)** | Fraud + Compliance | **🔒 4-Augen** |
| 5 | Provisorische Gutschrift (PSD2: 1 Werktag) | Fraud | **🔒 Ja** |
| 6 | Abschluss nach Kartenherausgeber-Entscheidung | L2 | Nein |

**Regulatorik**: PSD2 Art. 73 – Erstattung bei nicht autorisierter Zahlung innerhalb 1 Werktag

---

### 3.5 DSGVO-Anfragen (Auskunft, Löschung, Datenübertragung)

**Trigger**: Kunde stellt DSGVO-Antrag (Art. 15, 17, 20)

| Schritt | Aktion | Rolle | 🔒 Sensitiv? |
|---------|--------|-------|--------------|
| 1 | Antrag aufnehmen, Identität verifizieren | L1 | Nein |
| 2 | Antrag an Compliance weiterleiten | L1→Compliance | Nein |
| 3 | **Daten aus allen Systemen zusammenstellen** | Compliance | **🔒 Ja** |
| 4 | **Prüfung auf gesetzliche Aufbewahrungspflichten** | Compliance | **🔒 Ja** |
| 5 | **Freigabe der Antwort/Löschung** | Compliance + Teamlead | **🔒 4-Augen** |
| 6 | Antwort innerhalb 30 Tagen (verlängerbar auf 90) | Compliance | **🔒 Frist** |

**⚠️ Achtung**: AML-Daten unterliegen 5-10-jähriger Aufbewahrungspflicht – keine Löschung!

---

## 4. Antwortbausteine (Beispiele)

### 4.1 KYC-Dokument abgelehnt

```
Betreff: Ihre Identitätsprüfung – Nächste Schritte

Guten Tag [Vorname],

vielen Dank für Ihre Registrierung bei FIN1.

Leider konnten wir Ihr hochgeladenes Dokument nicht akzeptieren.
Der Grund: [GRUND – z.B. „Dokument ist abgelaufen" / „Foto unscharf"].

So geht's weiter:
1. Laden Sie bitte ein gültiges, gut lesbares Dokument hoch
2. Akzeptiert werden: Reisepass, Personalausweis (Vorder- + Rückseite)
3. Achten Sie auf gute Beleuchtung und vollständige Sichtbarkeit

Bei Fragen stehen wir Ihnen gerne zur Verfügung.

Mit freundlichen Grüßen
Ihr FIN1 Support-Team

Hinweis: Diese Prüfung erfolgt gemäß den gesetzlichen Vorgaben
zur Geldwäscheprävention (GwG).
```

---

### 4.2 Kontosperrung (nach Prüfung aufgehoben)

```
Betreff: Ihr FIN1-Konto ist wieder aktiv

Guten Tag [Vorname],

nach Abschluss unserer Sicherheitsprüfung freuen wir uns, Ihnen mitteilen
zu können, dass Ihr Konto ab sofort wieder uneingeschränkt nutzbar ist.

Die vorübergehende Einschränkung erfolgte zu Ihrem Schutz, da unser
Sicherheitssystem ungewöhnliche Aktivitäten erkannt hatte.

Ihre nächsten Schritte:
• Sie können sich wie gewohnt anmelden
• Alle Funktionen stehen Ihnen wieder zur Verfügung
• Wir empfehlen, Ihr Passwort vorsorglich zu ändern

Wir entschuldigen uns für eventuelle Unannehmlichkeiten.

Mit freundlichen Grüßen
Ihr FIN1 Support-Team
```

---

### 4.3 DSGVO-Auskunftsersuchen (Bestätigung)

```
Betreff: Bestätigung Ihres Auskunftsersuchens nach Art. 15 DSGVO

Guten Tag [Vorname],

wir bestätigen den Eingang Ihres Auskunftsersuchens vom [DATUM].

So geht es weiter:
• Wir stellen alle zu Ihrer Person gespeicherten Daten zusammen
• Sie erhalten eine vollständige Auskunft innerhalb von 30 Tagen
• Die Auskunft erfolgt in einem maschinenlesbaren Format (PDF/JSON)

Falls wir zur Bearbeitung mehr Zeit benötigen, informieren wir Sie
rechtzeitig unter Angabe der Gründe.

Bei Rückfragen erreichen Sie uns unter datenschutz@fin1.com.

Mit freundlichen Grüßen
Ihr FIN1 Datenschutz-Team

Rechtsgrundlage: Art. 15 DSGVO, Art. 12 Abs. 3 DSGVO (Antwortfrist)
```

---

## 4. Beispiel-Workflows pro Rolle

### 4.1 Level 1 Support (L1) – Standard-Kundensupport

**Szenario**: Kunde meldet, dass er sein Passwort vergessen hat

**Workflow**:
1. **Ticket erstellen** (`createSupportTicket`)
   - Kunde kontaktiert Support über In-App-Chat
   - L1-Agent erstellt Ticket #12345, Kategorie: "Passwort-Reset"

2. **Kundenprofil anzeigen** (`viewCustomerProfile`)
   - Agent prüft: Kunde ist verifiziert, letzter Login vor 3 Tagen
   - Keine verdächtigen Aktivitäten

3. **Kontaktdaten aktualisieren** (`updateCustomerContact`) – falls E-Mail geändert werden muss
   - Agent bestätigt E-Mail-Adresse mit Kunde
   - Aktualisierung wird protokolliert (Audit-Log)

4. **Support-Ticket beantworten** (`respondToSupportTicket`)
   - Agent sendet Passwort-Reset-Link per E-Mail
   - Interne Notiz: "Reset-Link gesendet, Kunde informiert"

5. **Ticket schließen**
   - Kunde bestätigt erfolgreichen Reset
   - Ticket auf "Gelöst" gesetzt

**Dauer**: ~5-10 Minuten
**Berechtigungen verwendet**: `viewCustomerProfile`, `createSupportTicket`, `respondToSupportTicket`, `updateCustomerContact`, `addInternalNote`

---

### 4.2 Level 2 Support (L2) – Erweiterte Support-Fälle

**Szenario**: Kunde kann sich nicht einloggen, Konto scheint gesperrt zu sein

**Workflow**:
1. **Ticket von L1 übernommen** (Eskalation)
   - L1 hat Problem nicht lösen können
   - Ticket #12346 an L2 eskaliert

2. **KYC-Status anzeigen** (`viewCustomerKYCStatus`)
   - Agent prüft: KYC vollständig, keine Compliance-Probleme

3. **Konto entsperren** (`unlockCustomerAccount`)
   - Agent stellt fest: Konto nach 3 fehlgeschlagenen Login-Versuchen gesperrt
   - Entsperrung durchgeführt, Kunde informiert

4. **Passwort zurücksetzen** (`resetCustomerPassword`)
   - Neues temporäres Passwort generiert
   - Kunde erhält E-Mail mit Anweisungen

5. **Interne Notiz** (`addInternalNote`)
   - "Konto entsperrt, Passwort-Reset durchgeführt. Kunde aufgefordert, 2FA zu aktivieren."

6. **Ticket schließen**
   - Kunde bestätigt erfolgreichen Login
   - Ticket auf "Gelöst" gesetzt

**Dauer**: ~15-20 Minuten
**Berechtigungen verwendet**: `viewCustomerKYCStatus`, `unlockCustomerAccount`, `resetCustomerPassword`, `escalateToAdmin` (falls nötig), `addInternalNote`

---

### 4.3 Fraud Analyst – Betrugserkennung und Kontosperrung

**Szenario**: Automatisches System erkennt verdächtige Transaktionsmuster

**Workflow**:
1. **Fraud-Alert erhalten** (`viewFraudAlerts`)
   - System-Alert: "Ungewöhnliche Transaktionsmuster bei Kunde #789"
   - 5 Transaktionen in 10 Minuten, verschiedene Länder

2. **Transaktionsmuster analysieren** (`viewTransactionPatterns`)
   - Agent prüft: Transaktionen von IP-Adressen in 3 verschiedenen Ländern
   - Letzte erfolgreiche Login von Deutschland, jetzt Aktivität aus USA, UK, Polen

3. **Verdächtige Aktivität markieren** (`flagSuspiciousActivity`)
   - Agent markiert Konto als "Verdächtig"
   - Interne Notiz: "Multi-Location-Aktivität, möglicher Account-Takeover"

4. **Karte blockieren** (`blockPaymentCard`)
   - Sofortige Kartenblockierung zum Schutz des Kunden
   - Kunde erhält automatische Benachrichtigung

5. **Konto temporär sperren** (`suspendAccountTemporary`)
   - 24-Stunden-Sperre aktiviert
   - Kunde kann sich nicht einloggen

6. **4-Augen-Freigabe anfordern** (`manageAccountSuspension` → erfordert Approval)
   - Für längere Sperre (>24h) wird Approval-Request erstellt
   - Request geht an Compliance Officer oder Teamlead

7. **SAR-Report vorbereiten** (`reportSAR` → erfordert Approval)
   - Agent erstellt SAR-Entwurf
   - Beschreibung: "Verdächtige Multi-Location-Transaktionen, möglicher Geldwäsche-Verdacht"
   - **Wartet auf 4-Augen-Freigabe** durch Compliance Officer

**Dauer**: ~30-45 Minuten (ohne Approval-Zeit)
**Berechtigungen verwendet**: `viewFraudAlerts`, `viewTransactionPatterns`, `flagSuspiciousActivity`, `suspendAccountTemporary`, `blockPaymentCard`, `viewAMLFlags`, `reportSAR` (mit Approval)

---

### 4.4 Compliance Officer – KYC-Prüfung und GDPR-Anfrage

**Szenario**: Kunde beantragt Datenauskunft nach DSGVO Art. 15

**Workflow**:
1. **GDPR-Anfrage erhalten** (`handleGDPRRequest`)
   - Kunde hat formelle DSGVO-Anfrage gestellt
   - Ticket #12347, Kategorie: "GDPR Data Access Request"

2. **KYC-Status prüfen** (`viewCustomerKYCStatus`)
   - Agent verifiziert: Kunde ist identifiziert
   - KYC vollständig abgeschlossen

3. **Audit-Logs anzeigen** (`viewAuditLogs`)
   - Agent prüft alle Zugriffe auf Kundendaten
   - Protokollierung: Wer hat wann welche Daten eingesehen?

4. **GDPR-Antwortdokument erstellen** (`processGDPRRequest`)
   - Agent generiert vollständige Datenauskunft:
     - Persönliche Daten (Name, Adresse, E-Mail, etc.)
     - Transaktionshistorie
     - KYC-Dokumente (pseudonymisiert)
     - Support-Verlauf
   - Dokument wird als PDF generiert

5. **Retention Conflicts prüfen**
   - Agent prüft: Welche Daten können nicht gelöscht werden?
   - Beispiel: Transaktionsdaten müssen 10 Jahre aufbewahrt werden (Steuerrecht)

6. **Dokument an Kunde senden**
   - PDF wird per verschlüsselter E-Mail versendet
   - Interne Notiz: "DSGVO-Auskunft versendet, Frist eingehalten (Tag 25/30)"

7. **Ticket schließen**
   - GDPR-Anfrage als "Abgeschlossen" markiert
   - Audit-Log: Compliance Officer hat Datenauskunft erstellt

**Dauer**: ~1-2 Stunden (inkl. Dokumentenerstellung)
**Berechtigungen verwendet**: `viewCustomerKYCStatus`, `viewAuditLogs`, `processGDPRRequest`, `viewCustomerProfile`, `viewCustomerInvestments`, `viewCustomerTrades` (✅ Compliance Officer hat Trade-Zugriff für regulatorische Prüfungen)

**Zweites Szenario**: KYC-Review für neuen Kunden

**Workflow**:
1. **KYC-Review initiieren** (`initiateKYCReview`)
   - Neuer Kunde hat KYC-Prozess gestartet
   - Dokumente hochgeladen, automatische Prüfung ergab "Manuelle Prüfung erforderlich"

2. **KYC-Dokumente prüfen**
   - Agent prüft: Ausweis-Dokumente, Adressnachweis
   - Vergleich mit Kundendaten im System

3. **KYC-Entscheidung genehmigen** (`approveKYCDecision` → 4-Augen)
   - Agent erstellt Approval-Request
   - Zweiter Compliance Officer muss genehmigen
   - Nach Genehmigung: KYC-Status auf "Verifiziert" gesetzt

**Berechtigungen verwendet**: `initiateKYCReview`, `approveKYCDecision` (mit 4-Augen), `viewCustomerDocuments`

---

### 4.5 Tech Support – Technische Probleme

**Szenario**: Kunde meldet App-Crash beim Öffnen des Portfolios

**Workflow**:
1. **Ticket erstellen** (`createSupportTicket`)
   - Kunde meldet: "App stürzt ab, wenn ich auf Portfolio klicke"
   - Ticket #12348, Kategorie: "Technisches Problem"

2. **Audit-Logs anzeigen** (`viewAuditLogs`)
   - Agent prüft: Gibt es Fehler-Logs für diesen Kunden?
   - System zeigt: "NullPointerException in PortfolioView, iOS 17.2"

3. **App-Version prüfen**
   - Agent prüft: Kunde verwendet App-Version 2.1.0
   - Bekannter Bug in Version 2.1.0, Fix in 2.1.1 verfügbar

4. **Workaround kommunizieren**
   - Agent informiert Kunde: "Bitte App auf Version 2.1.1 aktualisieren"
   - Alternativ: "Temporär Portfolio über Web-Interface öffnen"

5. **An Dev-Team eskalieren** (`escalateToAdmin`)
   - Falls Workaround nicht hilft, Eskalation an Entwickler
   - Interne Notiz: "Bug reproduziert, Dev-Team informiert"

6. **Ticket schließen**
   - Nach App-Update: Kunde bestätigt, dass Problem behoben ist
   - Ticket auf "Gelöst" gesetzt

**Dauer**: ~10-15 Minuten
**Berechtigungen verwendet**: `viewAuditLogs`, `createSupportTicket`, `respondToSupportTicket`, `escalateToAdmin`, `addInternalNote`

**Wichtig**: Tech Support hat **keinen Schreibzugriff** auf Kundendaten – nur Analyse und Eskalation.

---

### 4.6 Teamlead – 4-Augen-Freigaben und Agenten-Verwaltung

**Szenario 1**: 4-Augen-Freigabe für Kontosperrung

**Workflow**:
1. **Approval-Queue prüfen** (`viewFourEyesQueue`)
   - Teamlead öffnet 4-Augen-Queue
   - Sieht: "Fraud Analyst beantragt Kontosperrung >24h für Kunde #789"

2. **Request-Details prüfen**
   - Teamlead liest: "Multi-Location-Aktivität, verdächtige Transaktionen"
   - Prüft Audit-Log: Welche Aktionen wurden bereits durchgeführt?

3. **Kundendaten prüfen** (alle Lese-Berechtigungen)
   - Teamlead prüft: KYC-Status, Transaktionshistorie, Fraud-Alerts
   - Bewertung: Sperre gerechtfertigt

4. **Request genehmigen** (`approveFourEyesRequest`)
   - Teamlead genehmigt Kontosperrung für 7 Tage
   - Interne Notiz: "Sperre genehmigt aufgrund von Multi-Location-Aktivität"

5. **Audit-Log**
   - System protokolliert: "Teamlead [Name] hat Kontosperrung für Kunde #789 genehmigt"
   - Compliance-Event erstellt

**Dauer**: ~10-15 Minuten
**Berechtigungen verwendet**: `viewFourEyesQueue`, `approveFourEyesRequest`, `viewCustomerProfile`, `viewFraudAlerts`, `viewAuditLogs`

**Szenario 2**: Agenten-Berechtigungen verwalten

**Workflow**:
1. **Agent-Performance prüfen**
   - Teamlead öffnet Agent-Performance-Dashboard
   - Sieht: Agent "Lisa L1" hat hohe Ticket-Auflösungsrate

2. **Berechtigungen anpassen** (`manageAgentPermissions`)
   - Teamlead beschließt: Lisa soll auf L2 befördert werden
   - Neue Berechtigungen zuweisen: L2-Permission-Set

3. **Audit-Log**
   - System protokolliert: "Agent Lisa L1 → L2 befördert, Berechtigungen aktualisiert"
   - Compliance-Event erstellt

**Berechtigungen verwendet**: `manageAgentPermissions`, `viewAuditLogs`

---

## 5. E-Mail-Vorlagen & Textbausteine pro Rolle

> **Implementiert in**: `FIN1/Features/CustomerSupport/Models/Templates/`

### Vorlagen-Kategorien

| Kategorie | Icon | Beschreibung |
|-----------|------|--------------|
| Begrüßung | 👋 | Standard-Begrüßungen für alle Rollen |
| Konto-Probleme | 👤 | Passwort-Reset, Kontoänderungen |
| KYC/Onboarding | ✅ | Verifizierung, Dokumentenanforderung |
| Transaktionen | ↔️ | Transaktionserklärungen, Dispute |
| Sicherheit | 🔒 | Sicherheitswarnungen, Sperrungen |
| Betrug | ⚠️ | Fraud-Alerts, Chargebacks |
| Compliance | 🔍 | AML, regulatorische Mitteilungen |
| DSGVO | ✋ | Datenauskunft, Löschung |
| Technisch | 🔧 | App-Probleme, Bug-Reports |
| Eskalation | ⬆️ | 4-Augen, VIP-Eskalation |
| Abschluss | ✓ | Ticket-Abschluss, Feedback |

### 5.1 Level 1 Support – Vorlagen

| Vorlage | Kategorie | Typ |
|---------|-----------|-----|
| Standard-Begrüßung | Begrüßung | Chat |
| Begrüßung mit Ticket-Referenz | Begrüßung | Chat |
| Passwort-Reset Anleitung | Konto | Chat |
| E-Mail-Adresse ändern | Konto | Chat |
| App-Update erforderlich | Technisch | Chat |
| Cache leeren Anleitung | Technisch | Chat |
| Standard-Abschluss | Abschluss | Chat |
| Ticket geschlossen + Umfrage | Abschluss | Chat |

**Quick Snippets:**
- "Bitte warten": *"Einen Moment bitte, ich prüfe das für Sie."*
- "Nicht möglich": *"Das liegt leider außerhalb meiner Befugnisse..."*
- "Eskalation": *"Ich leite Ihr Anliegen an einen erfahrenen Kollegen weiter."*

---

### 5.2 Level 2 Support – Vorlagen

| Vorlage | Kategorie | Typ |
|---------|-----------|-----|
| *Alle L1-Vorlagen* | — | — |
| Konto entsperrt | Konto | E-Mail |
| KYC-Dokumente nachfordern | KYC | E-Mail |
| Transaktion erklären | Transaktionen | Chat |
| Verdächtige Aktivität bestätigen | Sicherheit | Chat |

**Zusätzliche Quick Snippets:**
- "Bitte warten": *"Ich schaue mir das genauer an..."*
- "Nicht möglich": *"Diese Aktion erfordert eine Genehmigung..."*

---

### 5.3 Fraud Analyst – Vorlagen

| Vorlage | Kategorie | Typ |
|---------|-----------|-----|
| Konto temporär gesperrt | Sicherheit | E-Mail |
| Karte blockiert (Verdacht) | Betrug | E-Mail |
| Chargeback eingeleitet | Betrug | E-Mail |
| Verdächtige Aktivität bestätigen | Betrug | Chat |

**Fraud-spezifische Quick Snippets:**
- "Bitte warten": *"Ich prüfe die Sicherheitslogs..."*
- "Nicht möglich": *"Aus Sicherheitsgründen kann ich diese Information nicht teilen."*
- "Eskalation": *"Das erfordert eine 4-Augen-Prüfung. Ich leite es ein."*

---

### 5.4 Compliance Officer – Vorlagen

| Vorlage | Kategorie | Typ |
|---------|-----------|-----|
| KYC-Verifizierung abgeschlossen | KYC | E-Mail |
| KYC-Ablehnung | KYC | E-Mail |
| DSGVO-Datenauskunft (Art. 15) | DSGVO | E-Mail |
| DSGVO-Löschung (Art. 17) | DSGVO | E-Mail |
| AML-Prüfung abgeschlossen | Compliance | Intern |
| 4-Augen-Freigabe erteilt | Eskalation | Intern |
| 4-Augen-Freigabe abgelehnt | Eskalation | Intern |

**Compliance-spezifische Quick Snippets:**
- "Bitte warten": *"Ich überprüfe die Compliance-Daten..."*
- "Nicht möglich": *"Aus regulatorischen Gründen ist das nicht möglich..."*
- "Eskalation": *"Für diese Entscheidung benötige ich eine zweite Freigabe."*

---

### 5.5 Tech Support – Vorlagen

| Vorlage | Kategorie | Typ |
|---------|-----------|-----|
| App-Update erforderlich | Technisch | Chat |
| Cache leeren Anleitung | Technisch | Chat |
| Bug-Report erstellt | Technisch | Chat |
| Verbindungsproblem | Technisch | Chat |

**Tech-spezifische Quick Snippets:**
- "Bitte warten": *"Ich analysiere die Logs, das dauert einen kurzen Moment."*
- "Nicht möglich": *"Das ist eine Systemeinschränkung. Ich erstelle einen Feature-Request."*
- "Eskalation": *"Ich eskaliere das an unser Entwicklerteam."*

---

### 5.6 Teamlead – Vorlagen

| Vorlage | Kategorie | Typ |
|---------|-----------|-----|
| *Alle Vorlagen verfügbar* | — | — |
| Eskalation bestätigt | Eskalation | Intern |
| 4-Augen-Freigabe erteilt | Eskalation | Intern |
| 4-Augen-Freigabe abgelehnt | Eskalation | Intern |
| VIP-Kunde Eskalation | Eskalation | E-Mail |

**Teamlead-spezifische Quick Snippets:**
- "Bitte warten": *"Ich kümmere mich persönlich darum..."*
- "Nicht möglich": *"Ich verstehe Ihren Wunsch, aber aus regulatorischen Gründen..."*
- "Eskalation": *"Ich kümmere mich persönlich um die schnelle Lösung."*

---

### Platzhalter-System

Alle Vorlagen unterstützen dynamische Platzhalter:

| Platzhalter | Beschreibung | Beispiel |
|-------------|--------------|----------|
| `{{KUNDENNAME}}` | Vollständiger Kundenname | Max Mustermann |
| `{{AGENTNAME}}` | Name des CSR-Agenten | Lisa Level-1 |
| `{{TICKETNUMMER}}` | Ticket-Referenz | 12345 |
| `{{DATUM}}` | Relevantes Datum | 22.01.2026 |
| `{{BETRAG}}` | Geldbetrag | 150,00 € |
| `{{EMAIL}}` | E-Mail-Adresse | max@example.com |

---

## Offene Annahmen (zur Klärung)

1. **CRM-System**: Zendesk empfohlen, finale Entscheidung ausständig
2. **Telefon-Support**: Optional – Kosten-Nutzen-Analyse empfohlen
3. **KYC-Provider**: Integration mit IDnow/Onfido vorhanden?
4. **SAR-Prozess**: Direkte FIU-Anbindung oder manuelle Meldung?
5. **SLA-Ziele**: L1-Erstantwort <2h, L2 <8h – bestätigen

---

## Implementierte Komponenten (v2.1)

### Models (`FIN1/Features/CustomerSupport/Models/`)

| Datei | Beschreibung |
|-------|--------------|
| `CustomerSupportPermission.swift` | 36 granulare Berechtigungen für CSR-Aktionen |
| `CSRRole.swift` | 6 Rollen (L1, L2, Fraud, Compliance, Tech, Teamlead) mit UI-Eigenschaften |
| `PermissionCategory.swift` | Kategorien zur UI-Gruppierung von Berechtigungen |
| `CustomerSupportPermissionSet.swift` | Vordefinierte Berechtigungs-Sets pro Rolle |
| `PermissionCheckResult.swift` | Ergebnis-Struct für Berechtigungsprüfungen |
| `FraudAMLModels.swift` | AccountSuspension, SARReport, ChargebackRequest, FraudAlert |
| `FourEyesApprovalModels.swift` | 4-Augen-Workflow mit ApprovalRequest, ApprovalDecision, AuditEntry |
| `GDPRRequestModels.swift` | DSGVO Art. 15/17/20 Anfragen mit RetentionConflicts |

### Backend (MongoDB Collections)

| Collection | Beschreibung |
|------------|--------------|
| `CSRPermission` | 36 Berechtigungen mit Metadaten (category, requiresApproval, etc.) |
| `CSRRole` | 6 Rollen mit Berechtigungs-Arrays und UI-Properties |

**Backend Cloud Functions** (CSR-RBAC-Implementierung: `backend/parse-server/cloud/functions/support/csrPermissions.js`; Registrierung u. a. über Loader `functions/support.js`):

- `getCSRPermissions` – Alle Berechtigungen abrufen (gruppiert nach Kategorie)
- `getCSRRoles` – Alle Rollen mit Berechtigungen abrufen
- `getCSRRolePermissions` – Berechtigungen einer spezifischen Rolle
- `checkCSRPermission` – Prüfen ob User eine bestimmte Berechtigung hat
- `getCSRAgentsWithRoles` – CSR-Agenten mit Rollen-Info
- `updateCSRUserRole` – CSR-Sub-Rolle eines Benutzers ändern

**Hinweis (Rollen-Lookup):** Die genannten Funktionen lösen `CSRRole` primär per Feld **`key`** (z. B. Werte aus `csrSubRole` / `createCSRUser`, typisch Snake_case wie `level_1`). Für ältere Daten, in denen eine Rolle nur unter **`name`** existiert, gibt es einen **Legacy-Fallback** — vermeidet Fehler wie „Role not found“, wenn UI oder User noch den alten Stil nutzen.

**Seed-Skript:** `backend/scripts/seed-csr-permissions.js`

### Templates (`FIN1/Features/CustomerSupport/Models/Templates/`)

| Datei | Beschreibung |
|-------|--------------|
| `TemplateCategory.swift` | Kategorien für Vorlagen (Begrüßung, KYC, DSGVO, etc.) |
| `ResponseTemplate.swift` | Basis-Model für Antwortvorlagen |
| `CSRTemplatesLibrary.swift` | Zentrale Zugriffspunkt für alle Vorlagen |
| `CommonTemplates.swift` | Begrüßungen und Abschlüsse (alle Rollen) |
| `Level1Templates.swift` | L1-spezifische Vorlagen |
| `Level2Templates.swift` | L2-spezifische Vorlagen |
| `FraudTemplates.swift` | Fraud-Analyst Vorlagen |
| `ComplianceTemplates.swift` | Compliance-Officer Vorlagen (KYC, DSGVO) |
| `TechSupportTemplates.swift` | Tech-Support Vorlagen |
| `TeamleadTemplates.swift` | Teamlead Vorlagen (4-Augen, Eskalation) |
| `QuickSnippets.swift` | Kurze rollenspezifische Textbausteine |

### Services (`FIN1/Features/CustomerSupport/Services/`)

| Service | Protokoll | Beschreibung |
|---------|-----------|--------------|
| `FourEyesApprovalService` | `FourEyesApprovalServiceProtocol` | 4-Augen-Workflow mit Audit-Trail |

### Views (`FIN1/Features/CustomerSupport/Views/Components/`)

| View | Beschreibung |
|------|--------------|
| `FourEyesApprovalQueueView.swift` | Dashboard für Genehmigungsanfragen |

### ViewModels (`FIN1/Features/CustomerSupport/ViewModels/`)

| ViewModel | Beschreibung |
|-----------|--------------|
| `FourEyesApprovalQueueViewModel.swift` | Genehmigungsqueue-Logik |

---

**Dokumentverantwortung**: Product/Compliance Team
**Nächste Review**: Quartalsweise oder bei regulatorischen Änderungen

© 2026 FIN1 – Internes Dokument
