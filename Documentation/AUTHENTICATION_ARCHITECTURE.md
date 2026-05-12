# FIN1 Authentication Architecture

**Version**: 1.2
**Status**: ✅ Vollständig integriert in AppServices
**Letzte Aktualisierung**: April 2026 (Test-User-Doku, Passwort-Konsolidierung)

---

## Übersicht

Die FIN1 Authentication-Architektur ist so konzipiert, dass sie flexibel zwischen verschiedenen Authentifizierungsanbietern wechseln kann (Apple Sign In, Auth0, Okta, eigenes Backend), ohne die App-Logik ändern zu müssen.

```
┌─────────────────────────────────────────────────────────────┐
│                         App Layer                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │ LandingView │  │ ProfileView │  │ CSR Dashboard       │  │
│  └──────┬──────┘  └──────┬──────┘  └──────────┬──────────┘  │
│         │                │                     │             │
│         └────────────────┼─────────────────────┘             │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              AuthServiceProtocol                       │  │
│  │  • signIn(email:password:)                            │  │
│  │  • signInWithApple()                                  │  │
│  │  • signInWithBiometrics()                             │  │
│  │  • signInWithSSO()                                    │  │
│  │  • signOut()                                          │  │
│  └───────────────────────┬───────────────────────────────┘  │
│                          │                                   │
└──────────────────────────┼───────────────────────────────────┘
                           │
┌──────────────────────────┼───────────────────────────────────┐
│                    Service Layer                             │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              AuthProviderProtocol                      │  │
│  │  • authenticate(with: AuthMethod)                     │  │
│  │  • refreshToken()                                     │  │
│  │  • revokeTokens()                                     │  │
│  └───────────────────────┬───────────────────────────────┘  │
│                          │                                   │
│         ┌────────────────┼────────────────┐                 │
│         ▼                ▼                ▼                 │
│  ┌────────────┐  ┌────────────┐  ┌────────────────┐        │
│  │MockProvider│  │Auth0Provider│  │OktaProvider   │        │
│  │  (DEBUG)   │  │  (FUTURE)   │  │  (FUTURE)     │        │
│  └────────────┘  └────────────┘  └────────────────┘        │
│                          │                                   │
│                          ▼                                   │
│  ┌───────────────────────────────────────────────────────┐  │
│  │              TokenStorageProtocol                      │  │
│  │  • store(accessToken:refreshToken:...)                │  │
│  │  • getAccessToken()                                   │  │
│  │  • clear()                                            │  │
│  └───────────────────────┬───────────────────────────────┘  │
│         ┌────────────────┴────────────────┐                 │
│         ▼                                 ▼                 │
│  ┌────────────────┐              ┌────────────────┐        │
│  │InMemoryStorage │              │KeychainStorage │        │
│  │   (DEBUG)      │              │  (PRODUCTION)  │        │
│  └────────────────┘              └────────────────┘        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Implementierte Komponenten

### Protokolle

| Datei | Beschreibung |
|-------|--------------|
| `AuthProviderProtocol.swift` | Abstraktionsschicht für Auth-Provider |
| `TokenStorageProtocol.swift` | Protokoll für sichere Token-Speicherung |
| `AuthServiceProtocol.swift` | High-Level Auth-Service für die App |

### Implementierungen

| Datei | Beschreibung | Umgebung |
|-------|--------------|----------|
| `MockAuthProvider.swift` | Mock-Provider für Entwicklung | DEBUG |
| `KeychainTokenStorage.swift` | Sichere Keychain-Speicherung | PRODUCTION |
| `InMemoryTokenStorage.swift` | In-Memory für Tests | DEBUG |
| `AuthService.swift` | Haupt-Auth-Service mit `ServiceLifecycle` | Alle |

### Integration

- ✅ Registriert in `AppServices.swift`
- ✅ Erstellt in `AppServicesBuilder.buildLiveServices()`
- ✅ Implementiert `ServiceLifecycle` (start/stop/reset)
- ✅ Error-Mapping zu `AppError.AuthError`
- ✅ Logger statt print() Statements

---

## Authentifizierungsmethoden

### Unterstützt (AuthMethod Enum)

| Methode | Beschreibung | Status |
|---------|--------------|--------|
| `emailPassword` | E-Mail und Passwort | ✅ Mock implementiert |
| `appleSignIn` | Sign in with Apple (ASAuthorization) | ✅ Mock implementiert |
| `biometric` | Face ID / Touch ID (Re-Auth) | ✅ Mock implementiert |
| `sso` | SSO (Auth0, Okta, Azure AD, Google) | ✅ Mock implementiert |
| `magicLink` | Passwortlose Anmeldung | ✅ Mock implementiert |
| `refreshToken` | Token-Erneuerung | ✅ Mock implementiert |

---

## Token-Management

### Token-Typen

| Token | Zweck | Gültigkeit |
|-------|-------|------------|
| `accessToken` | API-Authentifizierung | 1 Stunde |
| `refreshToken` | Neue Access-Tokens anfordern | 30 Tage |
| `idToken` | Benutzerinformationen (JWT) | 1 Stunde |

### Sichere Speicherung

```swift
// Keychain-Speicherung (Production)
let storage = KeychainTokenStorage(
    serviceName: "com.fin1.app",
    accessGroup: nil  // Optional: für App-Gruppen
)

// Attribute
kSecAttrAccessibleWhenUnlockedThisDeviceOnly
// → Tokens nur verfügbar wenn Gerät entsperrt
// → Nicht in Backups enthalten
// → Nicht auf andere Geräte übertragbar
```

---

## Verwendung

### 1. Einfache E-Mail/Passwort-Anmeldung

```swift
let authService = AuthServiceFactory.create()

do {
    let result = try await authService.signIn(
        email: "user@example.com",
        password: "securePassword123"
    )
    print("Angemeldet als: \(result.userId)")
} catch let error as AuthError {
    print("Fehler: \(error.errorDescription ?? "")")
}
```

### 2. Apple Sign In

```swift
// Nach ASAuthorizationController Callback
func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
) {
    if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
       let identityToken = appleIDCredential.identityToken,
       let authorizationCode = appleIDCredential.authorizationCode {

        Task {
            do {
                let result = try await authService.signInWithApple(
                    identityToken: identityToken,
                    authorizationCode: authorizationCode,
                    fullName: appleIDCredential.fullName
                )
                print("Apple Sign In erfolgreich: \(result.userId)")
            } catch {
                print("Fehler: \(error)")
            }
        }
    }
}
```

### 3. Biometrische Re-Authentifizierung

```swift
if authService.isBiometricAvailable {
    do {
        let result = try await authService.signInWithBiometrics()
        print("Biometrische Anmeldung erfolgreich")
    } catch AuthError.biometricFailed {
        // Fallback zu Passwort-Eingabe
    }
}
```

### 4. SSO für CSR/Enterprise

```swift
// Nach OAuth-Callback
let result = try await authService.signInWithSSO(
    provider: .auth0,
    code: "authorization_code_from_redirect",
    state: "optional_state_parameter"
)
```

---

## Fehlerbehandlung

### AuthError Typen

| Fehler | Beschreibung | Benutzeraktion |
|--------|--------------|----------------|
| `invalidCredentials` | Falsche E-Mail/Passwort | Erneut eingeben |
| `accountLocked` | Konto gesperrt | Support kontaktieren |
| `accountDisabled` | Konto deaktiviert | Support kontaktieren |
| `emailNotVerified` | E-Mail nicht bestätigt | E-Mail bestätigen |
| `mfaRequired` | 2FA erforderlich | MFA-Code eingeben |
| `tokenExpired` | Sitzung abgelaufen | Erneut anmelden |
| `biometricFailed` | Biometrie fehlgeschlagen | Passwort verwenden |
| `userCancelled` | Abgebrochen | - |

---

## Migration zu echtem Auth-Provider

### Phase 1: Auth0 Integration (Empfohlen)

```swift
// 1. Auth0.swift SDK hinzufügen (SPM)
// dependencies: [
//     .package(url: "https://github.com/auth0/Auth0.swift", from: "2.0.0")
// ]

// 2. Auth0Provider implementieren
final class Auth0Provider: AuthProviderProtocol {
    private let auth0: Auth0.Authentication

    init(clientId: String, domain: String) {
        self.auth0 = Auth0.authentication(
            clientId: clientId,
            domain: domain
        )
    }

    func authenticate(with method: AuthMethod) async throws -> AuthResult {
        switch method {
        case .emailPassword(let email, let password):
            let credentials = try await auth0
                .login(usernameOrEmail: email, password: password, realmOrConnection: "Username-Password-Authentication")
                .start()
            return mapToAuthResult(credentials, method: method)
        // ... andere Methoden
        }
    }
}

// 3. In AuthServiceFactory einbinden
static func create() -> AuthServiceProtocol {
    #if DEBUG
    return createMockService()
    #else
    let tokenStorage = KeychainTokenStorage()
    let authProvider = Auth0Provider(
        clientId: Secrets.auth0ClientId,
        domain: Secrets.auth0Domain
    )
    return AuthService(authProvider: authProvider, tokenStorage: tokenStorage)
    #endif
}
```

### Phase 2: Apple Sign In (App Store Pflicht)

```swift
// In Info.plist hinzufügen:
// <key>com.apple.developer.applesignin</key>
// <array><string>Default</string></array>

// Capability hinzufügen: "Sign in with Apple"
```

---

## Test-Benutzer (DEBUG)

**Passwort für alle unten genannten Mock-/Seed-User:** nur in **`FIN1/Shared/Constants/TestUserConstants.swift`** (`TestConstants.password`) — nicht in Markdown-Dokumenten duplizieren.

**Single Source of Truth (iOS):** dieselbe Datei (Investoren-/Trader-Namen, Kunden-ID-Prefixe `ANL` / `TRD`).

**Backend-Vollprofile:** Cloud Function `seedTestUsers` legt **5 Investoren** (`investor1@test.com` … `investor5@test.com`) und **10 Trader** (`trader1@test.com` … `trader10@test.com`) mit abgeschlossenem Onboarding an — siehe `backend/parse-server/cloud/functions/seed/users.js`.

| E-Mail | Passwort / Quelle | Rolle |
|--------|-------------------|-------|
| `investor1@test.com` … `investor5@test.com` | `TestConstants.password` (Swift) | Investor |
| `trader1@test.com` … `trader10@test.com` | dieselbe Konstante | Trader |
| `admin@test.com` | dieselbe Konstante | Admin |
| `csr-l1@test.com` | dieselbe Konstante | CSR Level 1 |
| `csr-l2@test.com` | dieselbe Konstante | CSR Level 2 |
| `csr-fraud@test.com` | dieselbe Konstante | Fraud Analyst |
| `csr-compliance@test.com` | dieselbe Konstante | Compliance |
| `csr-tech-support@test.com` | dieselbe Konstante | Tech Support |
| `csr-teamlead@test.com` | dieselbe Konstante | Teamlead |

---

## Sicherheitshinweise

### ✅ Implementiert

- Keychain-Speicherung mit `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- Token-Expiration-Prüfung
- Automatische Token-Erneuerung
- Sichere Löschung bei Sign-Out

### 🔜 Noch zu implementieren (Production)

- [ ] Certificate Pinning für API-Calls
- [ ] Jailbreak-Detection
- [ ] Token-Verschlüsselung vor Keychain-Speicherung
- [ ] Rate-Limiting bei fehlgeschlagenen Anmeldeversuchen
- [ ] Device-Fingerprinting
- [ ] Session-Invalidierung bei Sicherheitsvorfällen

---

## Dateien

```
FIN1/Features/Authentication/Services/
├── AuthProviderProtocol.swift      # Auth-Provider Abstraktion
├── TokenStorageProtocol.swift      # Token-Speicher Abstraktion + Keychain
├── MockAuthProvider.swift          # Mock für Entwicklung (DEBUG)
├── AuthService.swift               # Haupt-Service + Factory
├── UserServiceProtocol.swift       # Bestehender User-Service
└── UserFactory.swift               # Test-User-Erstellung
```

---

## Nächste Schritte

1. **Kurzfristig**: Weiter mit Mock-Auth für Entwicklung
2. **Beta**: Apple Sign In implementieren
3. **Launch**: Auth0 für CSR-Portal integrieren
4. **Scale**: MFA, Device-Management, SSO

---

© 2026 FIN1 – Internes Dokument
