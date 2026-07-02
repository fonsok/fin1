# Release — iOS Intent-only + Market-Data Feed (ADR-019 Phase 8–9)

**Typ:** iOS-Release (Backend bereits deployed auf iobox)  
**Git-Ref:** `c0de3b9` auf `origin/main`  
**Parse-Umgebung:** iobox `https://192.168.178.20/parse` (Default in App)

---

## Enthaltene Commits (Trading / Execution)

| Commit | Inhalt |
|--------|--------|
| `b3bcad3` | Intent-only Market-Execute; `upsertMarketDataQuote` Fallback |
| `090d89f` | Ops: Depot-Limit-Smoke (min buy + upsert) |
| `c8c4cfb` | Server Market-Data-Feed + iOS feed-first |
| `b408068` | Feed: Mock-Katalog + kürzlich gehandelte WKNs |
| `b7528cc` | Release-Abnahme Phase 8–9 + Unit-Test-Fix |
| `4d98a60` | iOS-Release-Runbook |
| `c0de3b9` | CI file-size baseline (Trading) |

---

## Deploy-Status

| Schritt | Status | Aktion |
|---------|--------|--------|
| Parse Cloud deploy (intent-only + Feed) | ✅ | Live auf iobox (2026-07-02) |
| Post-Deploy-Smoke full profile | ✅ | Feed + Upsert E2E grün |
| iOS feed-first Check (automatisiert) | ✅ | API-Mirror + 3 Unit-Tests |
| Release-Build `FIN1` Release / Simulator | ✅ | Lokal verifiziert |
| Git push `main` | ✅ | `origin/main` @ `c0de3b9` |
| GitHub CI (`build-test-lint` + Smokes) | ✅ | Run #183, ~65 min |
| **iOS App Gerät / TestFlight** | 📱 | **Jetzt** — siehe unten |

**Kein weiterer Backend-Deploy** für diese Welle.

---

## iOS-Build (Gerät / TestFlight)

1. `git pull` / Branch **`main`** @ `c0de3b9`.
2. Xcode → Scheme **FIN1** (Staging-Parse = iobox `.20`).
3. **Product → Run** auf physischem Gerät — Kurztest Market-Buy (siehe Abnahme).
4. **Product → Archive** → Distribute → **TestFlight** (oder Ad-Hoc intern).

### Kurztest vor Upload (empfohlen)

| Szenario | Erwartung |
|----------|-----------|
| Market-Buy WKN `865985` (Apple) | Kein `upsertMarketDataQuote` in Xcode-Konsole |
| Market-Buy exotische WKN (neu) | Einmal `upsertMarketDataQuote`, dann Execute OK |

---

## Abnahme-Referenz

- [`RELEASE_ABNAHME_INTENT_ONLY_PHASE8_2026-07-01.md`](RELEASE_ABNAHME_INTENT_ONLY_PHASE8_2026-07-01.md) — **Go** Phase 8–9 (2026-07-02)
- ADR: [`ADR-019-Sell-Server-Authoritative-Execution.md`](ADR-019-Sell-Server-Authoritative-Execution.md)

---

## Breaking / Migrationshinweise

- **Alte iOS-Builds** ohne feed-first: senden ggf. weiter Client-`price` (Server ignoriert) oder Upsert — funktioniert mit deployed Backend.
- **Sehr alte Builds** ohne Publish **und** ohne Feed-Quote: Market-Orders schlagen mit `no market data` fehl → Update erzwingen.
- `upsertMarketDataQuote` **nicht entfernen** — Fallback für erstmalige WKNs.

---

## Backlog (bewusst offen)

| Item | Status |
|------|--------|
| Echter Market-Data-Service (`backend/market-data/`) | Slice 4 / Backlog |
| P0 #2 Fees/Belege | Backlog |
| Simulator-Konsole Szenario A dokumentieren | Optional |

---

## Ergebnis

**Go für iOS-Release** — Backend live, Abnahme dokumentiert, CI grün. **Nächster Schritt:** Archive → TestFlight → Kurztest auf Gerät.
