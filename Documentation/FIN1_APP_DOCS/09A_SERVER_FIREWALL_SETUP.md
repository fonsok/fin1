# FIN1 Server Firewall Setup (ufw)

**Stand:** 2026-02-02
**Server:** Ubuntu 24.04 LTS (iobox, 192.168.178.24)

---

## Wichtig: Vor der Aktivierung

**WARNUNG:** Wenn Sie ufw aktivieren ohne SSH zu erlauben, sperren Sie sich aus!

---

## Empfohlene Konfiguration

### Schritt 1: SSH erlauben (WICHTIG - ZUERST!)

```bash
sudo ufw allow 22/tcp comment 'SSH'
```

### Schritt 2: Web-Traffic erlauben

```bash
sudo ufw allow 80/tcp comment 'HTTP (Nginx)'
sudo ufw allow 443/tcp comment 'HTTPS (Nginx)'
```

### Schritt 3: Optional - LAN-Services

```bash
# Samba (Dateifreigabe) - nur wenn benötigt
sudo ufw allow from 192.168.178.0/24 to any port 445 comment 'Samba LAN'
sudo ufw allow from 192.168.178.0/24 to any port 139 comment 'Samba NetBIOS LAN'

# Remote Desktop - nur wenn benötigt
sudo ufw allow from 192.168.178.0/24 to any port 3389 comment 'Remote Desktop LAN'
```

### Schritt 4: Firewall aktivieren

```bash
sudo ufw enable
```

### Schritt 5: Status prüfen

```bash
sudo ufw status verbose
```

---

## Erwartete Ausgabe nach Aktivierung

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere                   # SSH
80/tcp                     ALLOW IN    Anywhere                   # HTTP (Nginx)
443/tcp                    ALLOW IN    Anywhere                   # HTTPS (Nginx)
445                        ALLOW IN    192.168.178.0/24           # Samba LAN
139                        ALLOW IN    192.168.178.0/24           # Samba NetBIOS LAN
3389                       ALLOW IN    192.168.178.0/24           # Remote Desktop LAN
```

---

## Was NICHT erlaubt werden muss

Diese Ports sind bereits auf `127.0.0.1` gebunden und von außen nicht erreichbar:

| Port | Service | Binding | Status |
|------|---------|---------|--------|
| 1338 | Parse Server | 127.0.0.1 | ✅ Sicher |
| 27018 | MongoDB | 127.0.0.1 | ✅ Sicher |
| 5433 | PostgreSQL | 127.0.0.1 | ✅ Sicher |
| 6380 | Redis | 127.0.0.1 | ✅ Sicher |
| 9002/9003 | MinIO | 127.0.0.1 | ✅ Sicher |
| 8083-8085 | Internal Services | 127.0.0.1 | ✅ Sicher |

---

## Fehlerbehebung

### Ausgesperrt? (Physischer Zugang nötig)

```bash
# Am physischen Terminal oder über Remote Desktop:
sudo ufw disable
sudo ufw allow 22/tcp
sudo ufw enable
```

### Regel entfernen

```bash
# Regel nummer anzeigen
sudo ufw status numbered

# Regel löschen (z.B. Regel 5)
sudo ufw delete 5
```

### Komplett zurücksetzen

```bash
sudo ufw reset
```

---

## Quick-Setup (Copy & Paste)

```bash
# Alles in einem Block (VORSICHT: Erst lesen!)
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw allow from 192.168.178.0/24 to any port 445 comment 'Samba LAN'
sudo ufw allow from 192.168.178.0/24 to any port 139 comment 'Samba LAN'
sudo ufw allow from 192.168.178.0/24 to any port 3389 comment 'RDP LAN'
sudo ufw --force enable
sudo ufw status verbose
```

---

## Referenzen

- [Ubuntu UFW Documentation](https://help.ubuntu.com/community/UFW)
- `09_ADMIN_ROLES_SEPARATION.md` - Security Hardening Checkliste
