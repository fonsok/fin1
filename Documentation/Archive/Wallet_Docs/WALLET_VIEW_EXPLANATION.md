# Wallet-View: Was soll gezeigt werden?

## 📱 Was die Wallet-View anzeigen soll

Wenn ein Nutzer (Trader oder Investor) im Dashboard auf den "Wallet"-Button klickt, sollte folgendes angezeigt werden:

### 1. **Aktuelles Guthaben (Balance Card)**
- Große Anzeige des aktuellen Kontoguthabens (z.B. "€ 10.000,00")
- "Demo-Modus" Badge (da wir noch keine echten Zahlungen haben)
- Überschrift: "Aktuelles Guthaben"

### 2. **Schnellaktionen (Quick Actions)**
- **"Einzahlen" Button** (grün) - Öffnet Sheet zum Einzahlen von Geld
- **"Auszahlen" Button** (rot) - Öffnet Sheet zum Auszahlen von Geld

### 3. **Letzte Transaktionen (Recent Transactions)**
- Liste der letzten 5 Transaktionen
- Jede Transaktion zeigt:
  - Typ (Einzahlung, Auszahlung, Trade, etc.)
  - Betrag (mit + oder -)
  - Datum/Zeit
  - Status
- "Alle anzeigen" Button - Öffnet vollständige Transaktionshistorie

### 4. **Navigation & Toolbar**
- Titel: "Wallet"
- Refresh-Button (rechts oben) - Lädt Daten neu

---

## 🔍 Aktuelles Problem

Die Wallet-View zeigt einen **leeren schwarzen Bildschirm mit gelbem Warnsymbol**. Das deutet darauf hin, dass:

1. **Das ViewModel nicht richtig initialisiert wird**
2. **Ein Fehler beim Laden der Daten auftritt**
3. **Die Services nicht verfügbar sind**

---

## ✅ Lösung: Einfache Test-Version

Ich habe eine `WalletViewSimple` erstellt, die:
- **Ohne ViewModel** funktioniert (nur statische UI)
- **Sofort anzeigt**, was gezeigt werden soll
- **Zum Testen** dient, ob die Navigation funktioniert

Wenn `WalletViewSimple` funktioniert, liegt das Problem beim ViewModel/Service-Initialisierung.
Wenn `WalletViewSimple` auch nicht funktioniert, liegt das Problem bei der Navigation.

---

## 🎯 Nächste Schritte

1. **Teste `WalletViewSimple`** - Zeigt sie den Inhalt?
2. **Wenn ja**: Problem liegt beim ViewModel → Fix ViewModel-Initialisierung
3. **Wenn nein**: Problem liegt bei der Navigation → Fix Navigation

---

**Erstellt**: Januar 2026
