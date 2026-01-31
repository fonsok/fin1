#!/bin/bash

# Backend Verbindungstest / Health Check Script
# Testet die Verbindung zum Backend-Server mit netcat, nmap und mtr
# Default target: 192.168.178.20 (iobox.local)
#
# Verwendung:
#   ./scripts/health-check-backend-v2026-01-30.sh [HOST]
#   sudo ./scripts/health-check-backend-v2026-01-30.sh 192.168.178.20  # Mit mtr-Diagnose
#
# Was wird getestet:
#   - Port-Erreichbarkeit (netcat)
#   - Port-Status (nmap)
#   - Netzwerk-Pfad und Latenz (mtr)

set -euo pipefail

HOST=${1:-192.168.178.20}
PORTS="1337,27017,6379,5432,9000"

NC_BIN=$(command -v nc || true)
NMAP_BIN=$(command -v nmap || true)
MTR_BIN=$(command -v mtr || true)

section() {
  echo ""
  echo "==== $1 ===="
}

warn_missing() {
  echo "⚠️  $1 nicht gefunden. Bitte installieren: $2"
}

# 1) Port reachability via netcat
section "Port-Check (netcat)"
if [ -z "$NC_BIN" ]; then
  warn_missing "netcat" "brew install netcat"
else
  IFS=',' read -ra PORT_LIST <<< "$PORTS"
  for p in "${PORT_LIST[@]}"; do
    echo -n "Port $p: "
    if $NC_BIN -zv -w 3 "$HOST" "$p" 2>&1 | grep -q "succeeded"; then
      echo "✅ offen"
    else
      echo "❌ geschlossen oder gefiltert"
    fi
  done
fi

# 2) Port scan via nmap (if available)
section "Port-Scan (nmap)"
if [ -z "$NMAP_BIN" ]; then
  warn_missing "nmap" "brew install nmap"
else
  NMAP_OUTPUT=$($NMAP_BIN -p "$PORTS" "$HOST" 2>&1)
  echo "$NMAP_OUTPUT" | head -10

  # Parse nmap results
  OPEN_PORTS=$(echo "$NMAP_OUTPUT" | grep -E "^\d+/tcp.*open" | awk '{print $1}' | cut -d'/' -f1 || true)
  if [ -n "$OPEN_PORTS" ]; then
    echo ""
    echo "✅ Offene Ports:"
    echo "$OPEN_PORTS" | while read -r port; do
      case $port in
        1337) echo "  - Port $port: Parse Server ✅" ;;
        27017) echo "  - Port $port: MongoDB ✅" ;;
        6379) echo "  - Port $port: Redis ✅" ;;
        5432) echo "  - Port $port: PostgreSQL ✅" ;;
        9000) echo "  - Port $port: MinIO ✅" ;;
        *) echo "  - Port $port: Unbekannter Service ✅" ;;
      esac
    done
  fi
fi

# 3) Path diagnostics via mtr (requires sudo for ICMP)
section "Netzwerk-Pfad (mtr)"
if [ -z "$MTR_BIN" ]; then
  warn_missing "mtr" "brew install mtr"
else
  if [ "$EUID" -ne 0 ]; then
    echo "ℹ️  Für mtr bitte mit sudo ausführen: sudo $0 $HOST"
  else
    $MTR_BIN -r -c 10 "$HOST"
  fi
fi

# 4) Summary
section "Zusammenfassung"
echo "Host: $HOST"

# Check if host is reachable
if [ -n "$NMAP_BIN" ]; then
  if $NMAP_BIN -p "$PORTS" "$HOST" 2>&1 | grep -q "Host is up"; then
    echo "Status: ✅ Host erreichbar"
  else
    echo "Status: ❌ Host nicht erreichbar"
  fi
fi

echo "Ports geprüft: $PORTS"
echo ""
echo "Tools:"
if [ -n "$NMAP_BIN" ]; then
  echo "  ✅ nmap: $NMAP_BIN"
else
  echo "  ❌ nmap: nicht installiert"
fi
if [ -n "$NC_BIN" ]; then
  echo "  ✅ netcat: $NC_BIN"
else
  echo "  ❌ netcat: nicht installiert"
fi
if [ -n "$MTR_BIN" ]; then
  echo "  ✅ mtr: $MTR_BIN"
else
  echo "  ❌ mtr: nicht installiert"
fi

echo ""
echo "💡 Tipp: Für Parse Server (1337) sollte Port offen sein."
echo "   Andere Ports können geschlossen sein (normal bei Docker)."
echo ""
echo "Fertig."
