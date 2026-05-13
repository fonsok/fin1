# Nächste Schritte - Roadmap

**Datum**: Januar 2026  
**Status**: Compliance-Features (Audit-Logging, Transaction Limits) abgeschlossen ✅

---

## ✅ Abgeschlossen

1. **Audit-Logging Integration** ✅
   - BuyOrderPlacementService
   - MockPaymentService
   - TradeLifecycleService
   - UnifiedOrderService

2. **Transaction Limits Service** ✅
   - Service erstellt (Mock-First)
   - Integration in BuyOrderPlacementService
   - UI-Feedback in BuyOrderViewModel
   - Risk Class korrekt aus SignUp verwendet

---

## 🎯 Nächste Prioritäten (Empfohlen)

### 🔴 Priorität 1: Stabilization v1 — Admin & Betrieb (zeitlich begrenzt)

**Status:** Checkliste liegt vor; nach Admin-/Cloud-Änderungen operativ sinnvoll als Nächstes.

**Referenz:** `Documentation/STABILIZATION_V1_CHECKLIST.md`

**Nächster konkreter Schritt (Expert-Default):** **§3 — Dark-Mode / Kontrast** im **Admin Web Portal** (manuell, z. B. 60–90 Min.): Benutzerliste/-detail, Tickets, Compliance, Audit Logs, CSR-Templates, AGB — laut Checkliste auf Lesbarkeit prüfen; auffällige Stellen als **kleine PRs** in `admin-portal/` nachziehen.

**Danach (optional, dieselbe Datei):** §5 bei jedem relevanten Deploy; §1 nur bei konkreter Lücke (Audit zu `devResetTradingTestData` — Payload liegt unter `AuditLog.metadata.payload`).

---

### ⏸️ Zurückgestellt: Wallet-UI

**Grund:** Wallet-Konzept soll später noch angepasst werden — bis zur fachlichen Klärung **keine** großen UI-Ausbauten (Transaktionshistorie, Deposit/Withdraw-Sheets, Pagination); `WalletView` / `WalletViewModel` nur minimal bei Bugs oder API-Anpassungen.

**Wieder aufnehmen, wenn:** Produkt/Finance Zielbild und Datenmodell festliegen; dann diesen Abschnitt neu schreiben und ggf. Parse-Persistenz (Priorität 2, Punkt „Wallet-Transaktionen“) mitplanen.

---

### 🟡 Priorität 2: Parse Server Integration (3-5 Tage)

**Status**: "In Progress" laut README

**Was fehlt:**
- ⚠️ **Fehlt**: Vollständige Parse Server Integration für alle Services
- ⚠️ **Fehlt**: Persistente Speicherung (aktuell in-memory)
- ⚠️ **Fehlt**: Offline-Sync-Mechanismus

**Konkrete Tasks:**
1. **Transaction Limits persistieren**
   - Limits in Parse Server speichern (User-Klasse erweitern)
   - Transaktions-Tracking in Parse Server
   - Sync zwischen App und Server

2. **Audit-Logging persistieren**
   - Compliance-Events in Parse Server speichern
   - Query-Interface für Audit-Trails
   - Export-Funktionalität

3. **Wallet-Transaktionen persistieren** *(von Wallet-Konzept abhängig — aktuell mit Wallet-UI zurückgestellt)*
   - Transactions in Parse Server speichern
   - Balance-Sync zwischen App und Server
   - Conflict-Resolution bei Offline-Änderungen

**Impact:**
- ✅ **Daten-Persistenz** - Keine Datenverluste mehr
- ✅ **Multi-Device-Sync** - User kann auf mehreren Geräten arbeiten
- ⚠️ **Mittleres Risiko** - Backend-Integration erforderlich

---

### 🟢 Priorität 3: Real-time Updates (3-4 Tage)

**Status**: "In Progress" laut README

**Was fehlt:**
- ⚠️ **Fehlt**: Live-Updates für Portfolio-Werte
- ⚠️ **Fehlt**: Live-Updates für Order-Status
- ⚠️ **Fehlt**: WebSocket-Integration mit Parse Server

**Konkrete Tasks:**
1. **Parse Live Query Integration**
   - Portfolio-Updates in Echtzeit
   - Order-Status-Updates
   - Balance-Updates

2. **Market Data Updates**
   - Live-Kurse für Trading-View
   - Watchlist-Updates
   - Price-Alerts

3. **UI-Reaktivität**
   - SwiftUI-Views reagieren auf Live-Updates
   - Optimistic Updates für bessere UX
   - Loading-Indikatoren während Updates

**Impact:**
- ✅ **Bessere UX** - User sieht sofort Änderungen
- ✅ **Real-time Trading** - Aktuelle Kurse und Status
- ⚠️ **Mittleres Risiko** - WebSocket-Integration erforderlich

---

### 🔵 Priorität 4: Push Notifications (2-3 Tage)

**Status**: "In Progress" laut README

**Was fehlt:**
- ⚠️ **Fehlt**: Push-Notifications für wichtige Events
- ⚠️ **Fehlt**: Notification-Service-Integration
- ⚠️ **Fehlt**: User-Präferenzen für Notifications

**Konkrete Tasks:**
1. **Notification-Service erweitern**
   - Order-Execution-Notifications
   - Profit-Distribution-Notifications
   - Limit-Warning-Notifications
   - System-Notifications

2. **User-Präferenzen**
   - Settings-UI für Notification-Präferenzen
   - Kategorien (Trading, Payments, System)
   - Quiet-Hours-Einstellungen

3. **Parse Server Integration**
   - Cloud Functions für Push-Notifications
   - Notification-Historie
   - Badge-Count-Management

**Impact:**
- ✅ **Bessere UX** - User wird über wichtige Events informiert
- ✅ **Engagement** - User bleibt aktiv
- ✅ **Niedriges Risiko** - Bestehender Service wird erweitert

---

### 🟣 Priorität 5: Charts & Analytics (5-7 Tage)

**Status**: "Planned" laut README

**Was fehlt:**
- ⚠️ **Fehlt**: Portfolio-Performance-Charts
- ⚠️ **Fehlt**: Trading-Historie-Visualisierung
- ⚠️ **Fehlt**: Analytics-Dashboard

**Konkrete Tasks:**
1. **Chart-Library Integration**
   - SwiftUI-Charts oder TradingView-Integration
   - Portfolio-Performance-Graph
   - Trading-Historie-Timeline

2. **Analytics-Dashboard**
   - Performance-Metriken
   - Risk-Metrics
   - Profit/Loss-Analyse

3. **Export-Funktionalität**
   - PDF-Reports
   - CSV-Export
   - Sharing-Funktionalität

**Impact:**
- ✅ **Bessere UX** - User sieht Performance visuell
- ✅ **Trading-Entscheidungen** - Datenbasierte Insights
- ⚠️ **Längere Implementierung** - 5-7 Tage

---

## 📋 Empfohlene Reihenfolge

### Sprint 1 (Diese Woche)
1. **Wallet-UI vervollständigen** (2-3 Tage)
   - TransactionHistoryView erweitern
   - Deposit/Withdrawal Sheets
   - UI-Polish

### Sprint 2 (Nächste Woche)
2. **Parse Server Integration** (3-5 Tage)
   - Transaction Limits persistieren
   - Audit-Logging persistieren
   - Wallet-Transaktionen persistieren

### Sprint 3 (Woche 3-4)
3. **Real-time Updates** (3-4 Tage)
   - Parse Live Query Integration
   - Market Data Updates
   - UI-Reaktivität

4. **Push Notifications** (2-3 Tage)
   - Notification-Service erweitern
   - User-Präferenzen
   - Parse Server Integration

### Sprint 4 (Später)
5. **Charts & Analytics** (5-7 Tage)
   - Chart-Library Integration
   - Analytics-Dashboard
   - Export-Funktionalität

---

## 🎯 Quick Win: Wallet-UI (Start hier!)

**Warum zuerst?**
- ✅ **Schnell umsetzbar** (2-3 Tage)
- ✅ **Sofort sichtbar** - User kann Wallet testen
- ✅ **Niedriges Risiko** - Bestehende Services werden nur erweitert
- ✅ **Hoher Impact** - Wichtige User-Journey wird vervollständigt

**Nächster Schritt**: Soll ich mit der Wallet-UI-Vervollständigung beginnen?
