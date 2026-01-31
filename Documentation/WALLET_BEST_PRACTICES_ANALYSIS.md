# Wallet vs. Account Statement: Best Practices Analyse

**Datum**: Januar 2026
**Quelle**: Analyse etablierter Trading-Apps (eToro, Trading 212, Coinbase)

---

## ✅ Bestätigung: Unser Ansatz ist Best Practice

### Etablierte Apps verwenden das gleiche Pattern

#### **eToro** (Weltweit führende Trading-Plattform)
```
┌─────────────────────────────────┐
│  Investment Account             │
│  • Cash Balance (für Trading)   │
│  • Positions                     │
│  • Account Statement             │
└─────────────────────────────────┘
            ↕
┌─────────────────────────────────┐
│  eToro Money (Wallet)           │
│  • Instant Deposits             │
│  • Instant Withdrawals           │
│  • Separate from Trading         │
└─────────────────────────────────┘
```

**Workflow:**
1. User zahlt Geld ein → **eToro Money Wallet**
2. User transferiert Geld → **Investment Account** (für Trading)
3. User handelt → Geld wird im **Investment Account** verwendet
4. User möchte auszahlen → Geld zurück zu **eToro Money** → dann auf Bankkonto

#### **Trading 212**
```
Account Menu → Manage Funds
├── Deposit Funds (Wallet)
├── Withdraw Funds (Wallet)
└── Account Statement (Read-Only Übersicht)
```

**Features:**
- Separate "Manage Funds" Sektion für Ein-/Auszahlungen
- Account Statement zeigt alle Transaktionen
- 2FA erforderlich für Auszahlungen

#### **Coinbase** (Crypto + Trading)
```
┌─────────────────────────────────┐
│  Trading Account                │
│  • Cash Balance                 │
│  • Positions                    │
└─────────────────────────────────┘
            ↕
┌─────────────────────────────────┐
│  Wallet                         │
│  • Deposits                     │
│  • Withdrawals                  │
│  • Transaction History           │
└─────────────────────────────────┘
            ↕
┌─────────────────────────────────┐
│  Account Ledger                 │
│  • All Transactions             │
│  • Export                        │
└─────────────────────────────────┘
```

---

## 🎯 Best Practices (aus Recherche)

### 1. **Separation of Concerns** ✅
- **Wallet**: Ein-/Auszahlungen, externe Transfers
- **Cash Balance**: Trading-Operations, interne Buchungen
- **Account Statement**: Read-only Übersicht aller Transaktionen

### 2. **UX Patterns** ✅
- **Klare Trennung** zwischen Wallet und Trading-Balance
- **Schnellaktionen** für Ein-/Auszahlungen (wie wir implementiert haben)
- **Separate Navigation** für Wallet vs. Account Statement

### 3. **Security** ✅
- **2FA für Auszahlungen** (Trading 212)
- **Separate Validierung** für Wallet-Transaktionen
- **Transaktionslimits** (täglich/wöchentlich)

### 4. **Transaction History** ✅
- **Wallet zeigt**: Nur Wallet-Transaktionen (Ein-/Auszahlungen)
- **Account Statement zeigt**: ALLE Transaktionen (Wallet + Trading)

---

## 📊 Vergleich: FIN1 vs. Etablierte Apps

| Feature | eToro | Trading 212 | Coinbase | **FIN1 (unser Ansatz)** |
|---------|-------|-------------|----------|-------------------------|
| **Wallet für Ein-/Auszahlungen** | ✅ eToro Money | ✅ Manage Funds | ✅ Wallet | ✅ Wallet |
| **Cash Balance für Trading** | ✅ Investment Account | ✅ Trading Balance | ✅ Trading Account | ✅ Cash Balance |
| **Account Statement (Read-Only)** | ✅ Account Statement | ✅ Account Statement | ✅ Account Ledger | ✅ Account Statement |
| **Schnellaktionen** | ✅ | ✅ | ✅ | ✅ |
| **Transaction History** | ✅ | ✅ | ✅ | ✅ (Wallet) |
| **Alle Transaktionen in Statement** | ✅ | ✅ | ✅ | ⚠️ Noch zu implementieren |

---

## ✅ Fazit: Unser Ansatz ist State-of-the-Art

### Was wir richtig machen:
1. ✅ **Separation**: Wallet vs. Cash Balance (wie eToro, Trading 212)
2. ✅ **Schnellaktionen**: Ein-/Auszahlungs-Buttons (wie alle etablierten Apps)
3. ✅ **Read-Only Statement**: Account Statement für Übersicht (Best Practice)
4. ✅ **Transaction History**: Wallet zeigt eigene Transaktionen

### Was noch fehlt (aber geplant ist):
1. ⚠️ **Integration**: Wallet-Transaktionen in Account Statement anzeigen
2. ⚠️ **2FA für Auszahlungen**: Security-Best-Practice
3. ⚠️ **Transaktionslimits**: Tägliche/Wöchentliche Limits

---

## 🚀 Empfehlung: Integration implementieren

Da unser Ansatz **Best Practice** ist, sollten wir die Integration vollständig implementieren:

1. **Wallet-Transaktionen in Account Statement** integrieren
2. **2FA für Auszahlungen** hinzufügen (später)
3. **Transaktionslimits** implementieren (später)

**Erstellt**: Januar 2026
**Status**: Bestätigt - Ansatz ist State-of-the-Art ✅
