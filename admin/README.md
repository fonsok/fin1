# Static Admin SPA (`/admin/`)

Dieses Verzeichnis wird **nicht** mit gebauten Dateien versioniert (Hashes unter `assets/`, `index.html`, `fin1-logo.svg` aus dem Vite-Build).

**Lokal (z. B. Docker mit `./admin:/var/www/admin`):**

```bash
cd admin-portal && npm ci && npm run build
```

`npm run build` führt per `postbuild` `scripts/sync-admin-portal-to-admin.sh` aus und füllt `../admin/` aus `dist/`.

**Deploy auf den Server:** `admin-portal/deploy.sh` (rsync von `dist/`).

Siehe `admin-portal/README.md` → Abschnitt „Build für Production“.
