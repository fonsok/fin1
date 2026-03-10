# CSR Portal - Separates Web Panel

## ✅ Implementiert: Separates CSR Web Panel

Das CSR-Portal ist jetzt **vollständig getrennt** vom Admin-Portal mit eigenem Layout, eigener Navigation und eigenen Routen.

## Anmelde-URLs

### Option 1: CSR-Login (Empfohlen)
**URL:** `https://192.168.178.24/admin/csr/login`

- Dedizierte CSR-Login-Seite
- CSR-Branding mit Gradient-Design
- Automatische Umleitung zum CSR-Dashboard

### Option 2: Admin-Login (Funktioniert auch)
**URL:** `https://192.168.178.24/admin/login`

- CSR-User werden automatisch zum CSR-Portal umgeleitet
- Keine Admin-Features sichtbar

## Sicherheits-Features

1. **CSRRedirectGuard**: Blockiert CSR-User von Admin-Routen
2. **ProtectedRoute**: Leitet CSR-User sofort um, wenn sie Admin-Routen erreichen
3. **Separates Layout**: CSR-User sehen NIE das Admin-Layout

## Unterschiede: CSR-Portal vs. Admin-Portal

### CSR-Portal (`/admin/csr`)
- ✅ Eigenes Layout mit CSR-Branding
- ✅ Navigation: Dashboard, Tickets, Warteschlange, Kunden, KYC, Analytics, Trends, Templates, FAQs
- ✅ Keine Admin-Features (keine "Benutzer", keine Finance, keine Security)

### Admin-Portal (`/admin`)
- ✅ Admin-Layout
- ✅ Navigation: Dashboard, Benutzer, Tickets, Compliance, Finance, Security, etc.
- ✅ Nur für Admin-Rollen zugänglich

## Technische Implementierung

### Routing-Struktur
```
/admin/csr/*          → CSRApp (Separates Portal)
  /admin/csr/login    → CSRLoginPage
  /admin/csr          → CSRDashboard
  /admin/csr/tickets  → Ticket-Management
  ...

/admin/*              → Admin Portal (nur für Admin-Rollen)
  /admin/login        → AdminLoginPage
  /admin              → AdminDashboard
  /admin/users        → User-Management
  ...
```

### Umleitung-Logik
1. **Nach Login**: CSR-User werden automatisch zu `/admin/csr` umgeleitet
2. **Bei Admin-Route-Zugriff**: CSRRedirectGuard blockiert und leitet um
3. **ProtectedRoute**: Verhindert CSR-User-Zugriff auf Admin-Routen

## CSR-User Accounts

| E-Mail | Rolle | Passwort |
|--------|-------|----------|
| L1@fin1.de | Level 1 Support | `L1Secure2024!` |
| L2@fin1.de | Level 2 Support | `L2Secure2024!` |
| Fraud@fin1.de | Fraud Analyst | `FraudSecure2024!` |
| Compliance@fin1.de | Compliance Officer | `ComplianceSecure2024!` |
| Tech@fin1.de | Tech Support | `TechSecure2024!` |
| Lead@fin1.de | Team Lead | `LeadSecure2024!` |

## Features im CSR-Portal

- ✅ Dashboard mit Metriken
- ✅ Ticket-Management (vollständig)
- ✅ Ticket-Warteschlange
- ✅ Kundensuche & Details
- ✅ KYC-Status Übersicht
- ✅ Analytics & Performance
- ✅ Trends & Mustererkennung
- ✅ Templates-Verwaltung
- ✅ FAQ-Verwaltung

## Troubleshooting

**Problem**: CSR-User sehen immer noch "Admin Portal" in der Sidebar
**Lösung**:
1. Browser-Cache leeren (Strg+Shift+R / Cmd+Shift+R)
2. Über `/admin/csr/login` anmelden
3. Sicherstellen, dass die URL `/admin/csr` ist, nicht `/admin/tickets`

**Problem**: Umleitung funktioniert nicht
**Lösung**:
- CSRRedirectGuard sollte automatisch umleiten
- Falls nicht: Browser-Konsole prüfen auf Fehler
- Manuell zu `/admin/csr` navigieren
