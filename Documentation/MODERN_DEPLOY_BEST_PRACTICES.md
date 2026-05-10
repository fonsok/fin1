# Moderne Deploy-Best-Practices (FIN1 / iobox-orientiert)

**Zielgruppe:** Betrieb, Release, Security · **Kontext:** Parse Server, Docker Compose, Ubuntu-Host ohne zwingendes `git pull` auf Produktionspfaden.

## 1) Zielbild

- **Ein gebauter, geprüfter Stand** verlässt CI — nicht „irgendein Arbeitsbaum auf dem Server“.
- **Produktion** bekommt nur **Artefakte** (typisch **OCI-Images**) plus **versionierte Konfiguration** und **Runtime-Secrets**.
- **Server-Filesystem** für Anwendungscode möglichst **immutable**: kein Editieren von Cloud-Code auf dem Host; Änderungen nur durch neuen Rollout.

## 2) Build in CI („Build once“)

- Jeder Release-Build hängt an einem **Git-Commit** (`GIT_COMMIT_SHA`, Branch/Tag).
- Im Artefakt sichtbar machen: Label/Env im Image, `VERSION`-Datei im Bundle, oder Release-Notes-Link.
- **Tests vor Merge** (Parse Cloud Jest, Lint) + optional **Smoke** gegen Staging-Stack.

## 3) Artefakte statt `git pull` auf Prod

| Variante | Beschreibung | Passt zu FIN1 |
|----------|----------------|----------------|
| **Container-Images** | `parse-server`-Image in Registry; Prod macht `docker compose pull` + `up` mit fester **Image-Digest** oder semver-Tag | Stärkste Immutability; erfordert Registry + Image-Build-Pipeline |
| **Signiertes Bundle** | CI erzeugt tarball/rsync-Tree + **SHA256-Manifest**; Server verifiziert Hash, entpackt nach staging, **atomarer** Switch | Nahe am heutigen rsync; verbessert Integrität & Nachvollziehbarkeit |
| **Git auf Deploy-Host** | Separater Clone **nur** als Quelle für rsync/Compose; **nicht** `/home/io/fin1-server` wild mischen | Übergangspfad; Disziplin: kein direktes Editieren in Prod |

## 4) Rollout auf dem Server

- **Kein** unkontrolliertes `git pull` im laufenden Prod-Baum ohne Prozess.
- Stattdessen: **deklarierter Schritt** — z. B. `compose pull` / `compose up -d` mit neuer Image-Revision, oder **rsync aus CI-Artefakt** + **Neustart definierter Services**.
- Nach Rollout: **Health** (`/health`, `/parse/health`) + euer **`fin1-smoke-check.sh`** + fachliche Stichprobe (Admin).

## 5) Secrets & Konfiguration

- **Nicht** in Git, **nicht** in Image-Layern, die öffentlich gezogen werden können.
- **Runtime-Injection:** z. B. `env_file` aus geschütztem Pfad, **Docker Secrets** (Swarm), oder Secret-Manager (Vault, SOPS, 1Password-CLI) — je nach Reifegrad.
- **Single Source of Truth** pro Secret (wie bei `MONGO_INITDB_ROOT_PASSWORD` in `~/fin1-server/.env` dokumentiert).

## 6) Immutability & Konfiguration

- **Anwendungscode** in Containern aus **Image**; Host-Volume nur, wo bewusst nötig (z. B. Cloud-Code-Volume — dann klarer Prozess: nur deployierte Version).
- **Konfig-Drift** vermeiden: `docker compose config` in CI gegen erwartetes Schema; auf dem Host **keine** dauerhaften Handänderungen ohne Ticket.

## 7) Rollback

- **Image-basiert:** vorherigen **Digest/Tag** erneut ausrollen (schnell, reproduzierbar).
- **Bundle-basiert:** vorheriges Manifest + bekanntes Backup (`mongodump` etc.) — langsamer, aber nachvollziehbar.

## 8) Migration vom heutigen iobox-Setup

1. **Kurz (Schritt 1 — im Repo):** weiter rsync, plus **Deploy-Manifest** auf dem Server:
   - Skript: `scripts/write-deploy-manifest.sh --component parse-cloud` (JSON: `gitCommit`, Branch, `gitTreeDirty`, UTC-Zeit, optional **`sourceTreeSha256`** über `git archive … backend/parse-server/cloud`).
   - Nach **`scripts/deploy-parse-cloud-to-fin1-server.sh`** (Standard: **an**) landen Dateien unter **`~/fin1-server/deploy-manifests/`** auf iobox: `parse-cloud-latest.json` und eine Zeile pro Deploy in **`history.log`**.
   - Deaktivieren: `WRITE_DEPLOY_MANIFEST=0 ./scripts/deploy-parse-cloud-to-fin1-server.sh`
2. **Mittel:** Parse-Image in CI bauen, Prod zieht **nur** Images; Cloud-Code **in** Image (oder read-only Volume aus Artefakt).  
3. **Lang:** vollständige **GitOps**/Registry-Strategie — nur wenn Team/Audit das rechtfertigt.

## 9) Verknüpfungen im Repo

- Ubuntu/iobox-Runbook: [`FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`](FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md)  
- Betriebs-Übersicht: [`FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md`](FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md)  
- Rsync-Sicherheit: [`DEPLOYMENT_RSYNC_SICHERHEIT.md`](DEPLOYMENT_RSYNC_SICHERHEIT.md)  
- Deploy-Ziele (IPs): [`OPERATIONAL_DEPLOY_HOSTS.md`](OPERATIONAL_DEPLOY_HOSTS.md)

---

**Kern:** *Moderne* Best Practice ist **Reproduzierbarkeit + Integrität + klare Secrets** — nicht zwingend Kubernetes. Für FIN1 reicht oft ein **konsequenter CI-Build + versioniertes Artefakt + disziplinierter Rollout** als nächster Reifegrad über „nur rsync“.
