# Moderne Deploy-Best-Practices (FIN1 / iobox-orientiert)

**Zielgruppe:** Betrieb, Release, Security · **Kontext:** Parse Server, **OCI-Container** (heute Docker Engine + Compose; perspektivisch z. B. **Podman**), Ubuntu-Host ohne zwingendes `git pull` auf Produktionspfaden.

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
2. **Mittel (Schritt 2 — im Repo):** CI-Artefakt für dasselbe Manifest — Workflow **`.github/workflows/deploy-manifest-artifact.yml`** (`workflow_dispatch`, **PR** und **Push** auf `main`/`master` bei Änderungen unter `backend/parse-server/cloud/` u. a.): lädt **`deploy-manifest-parse-cloud-<sha>.json`** als **Artifact** (90 Tage); JSON wird in CI mit **`python3 -m json.tool`** geprüft.  
3. **Mittel (Parse-Image — Vorbereitung):** Workflow **`.github/workflows/parse-server-docker-build.yml`** baut das **Produktions-Parse-Image** wie in `docker-compose.production.yml` (**ohne Push**), mit **Buildx** und **GitHub Actions Cache** für schnellere Layer-Wiederholungen; lokal identisch: **`./scripts/ci-build-parse-server-docker.sh`**. Nächster Reifegrad: Image in eine **Registry** pushen und auf iobox **`docker compose pull`** mit fester Digest/Tag. Cloud-Code **in** Image (oder read-only Volume aus Artefakt) bleibt das Zielbild.  
4. **Lang:** vollständige **GitOps**/Registry-Strategie — nur wenn Team/Audit das rechtfertigt.

## 9) Verknüpfungen im Repo

- Ubuntu/iobox-Runbook: [`FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md`](FIN1_APP_DOCS/06A_BACKEND_UBUNTU_IOBOX_RUNBOOK.md)  
- Betriebs-Übersicht: [`FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md`](FIN1_APP_DOCS/06_BETRIEB_PROZESSE.md)  
- Rsync-Sicherheit: [`DEPLOYMENT_RSYNC_SICHERHEIT.md`](DEPLOYMENT_RSYNC_SICHERHEIT.md)  
- Deploy-Ziele (IPs): [`OPERATIONAL_DEPLOY_HOSTS.md`](OPERATIONAL_DEPLOY_HOSTS.md)

## 10) Podman / andere FOSS-Runtime (mittelfristig)

**Jetzt schon sinnvoll:** nicht die Engine wechseln, sondern **Abstraktionen festhalten**, die unter Docker *und* Podman (und anderen **OCI**-fähigen Runtimes) gleich bleiben:

- **Artefakt = OCI-Image** aus `Dockerfile` (heutiger Build) — `podman build` versteht dasselbe Format; euer **Registry-Pull**-Pfad bleibt der gleiche (`podman pull` / `skopeo`).
- **Orchestrierung = Compose-Spezifikation** (`docker-compose*.yml`): Podman kann die **Compose v2**-Dateien ausführen (`podman compose` bzw. Integration in neueren Podman-Versionen); Befehle im Runbook werden später **1:1** oder nahezu 1:1 ersetzbar (`docker compose …` → `podman compose …`), ohne das Datenmodell zu ändern.
- **Keine harten Abhängigkeiten** von Docker-only APIs im Anwendungscode (Swarm-only Features, proprietäre Plugins) — FIN1 nutzt das ohnehin kaum; **Swarm „Secrets“** in Abschnitt 5 sind nur ein Beispiel für *irgendein* Secret-Backend, nicht als Zwang zu Docker Swarm.
- **CI:** GitHub-hosted Runner sind Docker-lastig (`docker/build-push-action`); ein Podman-Umstieg in CI ist **eigenes Projekt** (self-hosted Runner, `podman build`, oder Buildah). **Vorbereitung:** solange die **Dockerfile**-Semantik standardkonform bleibt, ist der CI-Wechsel entkoppelt vom Server-Wechsel.

**Was bewusst später kommt:** Rootless-Netzwerk (`pasta`/`slirp4netns`), UID-Mapping auf Volumes, `podman`-spezifische Systemd-Quadlets — das gehört in eine Migrations-Checkliste, sobald ihr auf dem Host umstellt, nicht schon in jedem PR.

---

**Kern:** *Moderne* Best Practice ist **Reproduzierbarkeit + Integrität + klare Secrets** — nicht zwingend Kubernetes. Für FIN1 reicht oft ein **konsequenter CI-Build + versioniertes Artefakt + disziplinierter Rollout** als nächster Reifegrad über „nur rsync“.
