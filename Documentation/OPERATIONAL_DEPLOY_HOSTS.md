# Operative Deploy-Ziele (iobox) — Single Source of Truth

**Zielgruppe:** Entwicklung, Agenten, Betrieb  
**Ergänzt:** [`NETZWERK_KONFIGURATION.md`](../NETZWERK_KONFIGURATION.md) (Ports, URLs, Fritzbox)

## Einstieg (Happy-Path)

Kurzüberblick inkl. CI- und PR-Guardrails: [`ENGINEERING_GUIDE.md`](ENGINEERING_GUIDE.md) → Abschnitte **CI** und **Deploy — Happy-Path Lesepfad**.

## Physische Realität

| Begriff | Bedeutung |
|--------|------------|
| **Ein Host** | `iobox` — ein Ubuntu-Stack unter `~/fin1-server/` |
| **Zwei LAN-IPs** | Derselbe Rechner, zwei NICs; **kein** zweiter App-Server |

| IP | Schnittstelle | Rolle |
|----|----------------|--------|
| **`192.168.178.24`** | WLAN (`wlp2s0`) | **Kanone für HTTPS/Parse in Doku und Clients** (`https://…/parse`, `wss://…/parse`, Admin-URL in den meisten Anleitungen) |
| **`192.168.178.20`** | Ethernet (`enp3s0`) | **Gleicher Host** — gültig für SSH/rsync; oft stabiler für große Transfers vom Mac |

**Wichtig:** Unterschiedliche IPs in Logs oder Deploy-Ausgaben bedeuten **nicht** „falsches System“, sondern nur **unterschiedliche Wege zum gleichen Docker-Stack**.

## Was welches Skript / welche Variable nutzt

| Aufgabe | Mechanismus | Standard-Host (wenn nichts gesetzt) |
|-----------|--------------|--------------------------------------|
| **Admin-Portal** (Build + `rsync` + Bundle-Check) | `admin-portal/deploy.sh` lädt `scripts/.env.server` | `FIN1_SERVER_IP` oder **`192.168.178.24`** |
| **Parse Cloud** (`cloud/` + Restart `parse-server`) | **`scripts/deploy-parse-cloud-to-fin1-server.sh`** | **`FIN1_PARSE_CLOUD_SSH_HOST`** oder **`192.168.178.24`** (bewusst **unabhängig** von `FIN1_SERVER_IP`, damit Admin z. B. über `.20` gehen kann, Cloud-Deploy weiterhin der Doku-Kanone folgt) |
| **GHCR-Parse-Compose** (`docker-compose.parse-server-ghcr.yml` + Snippet) | **`scripts/sync-docker-compose-parse-server-ghcr-to-fin1-server.sh`** | dieselbe SSH-Ziel-Logik wie Parse-Cloud-Deploy |
| **Schnell prüfen, was aktiv ist** | `./scripts/show-fin1-deploy-targets.sh` | zeigt effektive Werte |

Konfiguration: **`scripts/.env.server`** (lokal, nicht committen) — Vorlage: **`scripts/.env.server.example`**.

## Nginx liefert altes Admin-UI trotz neuem `rsync`

Symptom: Auf dem Host unter `~/fin1-server/admin/` liegt z. B. `index-CxfA18kk.js`, im Browser referenziert `https://…/admin/` aber noch `index-….js` von gestern; **Sidebar-Einträge fehlen**.

Ursache: Der **Container `fin1-nginx`** kann einen veralteten Inhalt von `/var/www/admin` sehen (Host und Container-MD5 von `index.html` weichen ab).

Abhilfe (auf dem Server):

```bash
cd ~/fin1-server && docker compose -f docker-compose.production.yml up -d --force-recreate --no-deps nginx
```

`admin-portal/deploy.sh` führt diesen Schritt nach erfolgreichem `rsync` automatisch aus.

## Empfohlene Workflows

```bash
# Effektive Deploy-Ziele anzeigen (liest scripts/.env.server falls vorhanden)
./scripts/show-fin1-deploy-targets.sh
```

```bash
# Parse Cloud inkl. Shadow-Check, rsync, configHelper-Schutz, Container-Restart
./scripts/deploy-parse-cloud-to-fin1-server.sh
```

```bash
# Admin-Portal
cd admin-portal && ./deploy.sh
```

## Optional: ein Hostname statt IPs

Wenn ihr im LAN einen DNS- oder `/etc/hosts`-Eintrag pflegt (z. B. `iobox.fritz.box` → eine der beiden IPs), könnt ihr **`FIN1_SERVER_IP`** und **`FIN1_PARSE_CLOUD_SSH_HOST`** auf diesen Namen setzen — dann ändert sich bei IP-Umstellungen nur eine Stelle.

## Verwandte Doku

- [`Documentation/DEPLOYMENT_RSYNC_SICHERHEIT.md`](DEPLOYMENT_RSYNC_SICHERHEIT.md) — kein `--delete` auf dem Server-`backend/`-Baum
- [`.cursor/rules/ci-cd.md`](../.cursor/rules/ci-cd.md) — Agent-Regeln FIN1-Server-Deploy
- [`Documentation/FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`](FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md) — Betrieb auf dem Host
