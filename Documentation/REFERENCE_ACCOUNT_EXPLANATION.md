# Referenzkonto: Woher kommt das Geld? Wohin geht das Geld?

**Datum**: Januar 2026
**Frage**: Wohin geht die Auszahlung und woher kommt die Einzahlung - Referenzkonto?

---

## 🎯 Kurze Antwort

**Ja, genau! Es ist das Referenzkonto (externes Bankkonto des Users).**

- **Einzahlung**: Referenzkonto (User's Bankkonto) → FIN1 Konto
- **Auszahlung**: FIN1 Konto → Referenzkonto (User's Bankkonto)

---

## 📊 Datenfluss

```
┌─────────────────────────────────────────────────────────────┐
│              User's Referenzkonto                           │
│         (Externes Bankkonto des Users)                      │
│                                                              │
│  Beispiel:                                                  │
│  • IBAN: DE89 3704 0044 0532 0130 00                        │
│  • Bank: Sparkasse                                          │
│  • Kontoinhaber: Max Mustermann                             │
└─────────────────────────────────────────────────────────────┘
                            ▲ │
                            │ │
                    Einzahlung │ Auszahlung
                            │ │
                            │ ▼
┌─────────────────────────────────────────────────────────────┐
│                    FIN1 Konto                               │
│  • Balance: €25.000,00                                       │
│  • Einzahlung: +€1.000,00                                    │
│  • Auszahlung: -€500,00                                      │
└─────────────────────────────────────────────────────────────┘
```

---

## 🔄 Wie funktioniert es?

### Einzahlung (Deposit)

**User Journey:**
1. User öffnet Kontoansicht
2. Klickt "Einzahlen"
3. Gibt Betrag ein (z.B. 1.000€)
4. Bestätigt Einzahlung

**Was passiert:**
- **Demo-Modus**: Balance wird sofort erhöht (Mock)
- **Produktion (mit BaaS)**:
  - User wird zu SEPA-Direktlastschrift weitergeleitet
  - Oder: User überweist manuell von Referenzkonto
  - BaaS-Provider bestätigt Zahlungseingang
  - FIN1 Konto-Balance wird erhöht

**Geldfluss:**
```
Referenzkonto (User's Bank) → SEPA-Überweisung → FIN1 Konto
```

---

### Auszahlung (Withdrawal)

**User Journey:**
1. User öffnet Kontoansicht
2. Klickt "Auszahlen"
3. Gibt Betrag ein (z.B. 500€)
4. Bestätigt Auszahlung

**Was passiert:**
- **Demo-Modus**: Balance wird sofort reduziert (Mock)
- **Produktion (mit BaaS)**:
  - FIN1 sendet Auszahlungsanfrage an BaaS-Provider
  - BaaS-Provider führt SEPA-Überweisung durch
  - Geld wird auf Referenzkonto überwiesen (1-3 Werktage)
  - FIN1 Konto-Balance wird reduziert

**Geldfluss:**
```
FIN1 Konto → SEPA-Überweisung → Referenzkonto (User's Bank)
```

---

## 🏦 Was ist das Referenzkonto?

### Definition

Das **Referenzkonto** ist das externe Bankkonto des Users, das:
- ✅ Bei der Registrierung/KYC hinterlegt wird
- ✅ Für Einzahlungen verwendet wird (Geld kommt von dort)
- ✅ Für Auszahlungen verwendet wird (Geld geht dorthin)
- ✅ Einmalig verifiziert wird (IBAN-Validierung)

### Beispiel

```
User: Max Mustermann
Referenzkonto:
  • IBAN: DE89 3704 0044 0532 0130 00
  • Bank: Sparkasse
  • Kontoinhaber: Max Mustermann
  • Status: Verifiziert ✅
```

---

## 📋 Aktuelle Implementierung (Demo-Modus)

### MockPaymentService

**Aktuell (Demo):**
```swift
func deposit(amount: Double) async throws -> Transaction {
    // Simuliert nur Balance-Update
    // Keine echte Bank-Überweisung
    await cashBalanceService.processGutschrift(amount: amount)
    // Balance wird erhöht
}
```

**Was fehlt:**
- ❌ Keine IBAN-Speicherung
- ❌ Keine SEPA-Überweisung
- ❌ Keine Referenzkonto-Verwaltung

**Was funktioniert:**
- ✅ Balance wird aktualisiert
- ✅ Transaktion wird gespeichert
- ✅ Transaktion erscheint in Historie

---

## 🚀 Zukünftige Implementierung (Produktion mit BaaS)

### Mit BaaS-Provider (z.B. Solaris)

**Einzahlung:**
```swift
func deposit(amount: Double) async throws -> Transaction {
    // 1. Hole Referenzkonto (IBAN) vom User
    let referenceAccount = try await getUserReferenceAccount()

    // 2. Initiiere SEPA-Direktlastschrift via BaaS
    let sepaResponse = try await solarisClient.createDirectDebit(
        amount: amount,
        referenceAccount: referenceAccount.iban,
        userId: userId
    )

    // 3. Warte auf Bestätigung (Webhook)
    // 4. Aktualisiere Balance
    await cashBalanceService.processGutschrift(amount: amount)

    return transaction
}
```

**Auszahlung:**
```swift
func withdraw(amount: Double) async throws -> Transaction {
    // 1. Hole Referenzkonto (IBAN) vom User
    let referenceAccount = try await getUserReferenceAccount()

    // 2. Initiiere SEPA-Überweisung via BaaS
    let sepaResponse = try await solarisClient.createSEPATransfer(
        amount: amount,
        targetIBAN: referenceAccount.iban,
        userId: userId
    )

    // 3. Aktualisiere Balance
    await cashBalanceService.processWithdrawal(amount: amount)

    return transaction
}
```

---

## 📊 User-Datenmodell (Zukünftig)

### User Model erweitern

```swift
struct User {
    let id: String
    let email: String
    let role: UserRole
    // ... andere Felder

    // Neu: Referenzkonto
    let referenceAccount: ReferenceAccount?
}

struct ReferenceAccount {
    let iban: String
    let bankName: String?
    let accountHolder: String
    let verified: Bool
    let verifiedAt: Date?
    let createdAt: Date
}
```

---

## 🔐 KYC & Verifizierung

### Referenzkonto-Verifizierung

**Schritte:**
1. **User gibt IBAN ein** (bei Registrierung oder später)
2. **IBAN-Validierung** (Format-Check)
3. **SEPA-Validierung** (IBAN-Prüfung via BaaS)
4. **Micro-Deposit** (optional, für Verifizierung):
   - BaaS sendet kleine Beträge (z.B. 0,01€, 0,02€)
   - User gibt Beträge ein
   - Verifizierung erfolgreich ✅

**Status:**
- `pending`: IBAN eingegeben, noch nicht verifiziert
- `verified`: IBAN verifiziert, kann verwendet werden
- `rejected`: IBAN ungültig oder Verifizierung fehlgeschlagen

---

## 📋 Zusammenfassung

### Aktuell (Demo-Modus)

**Einzahlung:**
- ✅ Balance wird erhöht
- ❌ Keine echte Bank-Überweisung
- ❌ Keine Referenzkonto-Verwaltung

**Auszahlung:**
- ✅ Balance wird reduziert
- ❌ Keine echte Bank-Überweisung
- ❌ Keine Referenzkonto-Verwaltung

### Zukünftig (Produktion mit BaaS)

**Einzahlung:**
- ✅ Balance wird erhöht
- ✅ SEPA-Direktlastschrift vom Referenzkonto
- ✅ Referenzkonto-Verwaltung (IBAN-Speicherung)

**Auszahlung:**
- ✅ Balance wird reduziert
- ✅ SEPA-Überweisung auf Referenzkonto
- ✅ Referenzkonto-Verwaltung (IBAN-Speicherung)

---

## 🎯 Nächste Schritte

1. **Referenzkonto-Modell erstellen**
   - `ReferenceAccount` struct
   - IBAN-Speicherung im User-Model

2. **Referenzkonto-Verwaltung UI**
   - IBAN-Eingabe
   - IBAN-Validierung
   - Verifizierungs-Status

3. **BaaS-Integration**
   - SEPA-Direktlastschrift für Einzahlungen
   - SEPA-Überweisung für Auszahlungen
   - Webhook-Handler für Bestätigungen

---

**Erstellt**: Januar 2026
**Status**: Erklärung - Referenzkonto ist das externe Bankkonto des Users ✅
