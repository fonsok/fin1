#!/bin/bash
# ============================================================================
# Enable X11 forwarding for SSH (auf dem Ubuntu-Server mit fin1-server)
# ============================================================================
#
# Problem: In /etc/ssh/sshd_config.d/99-fin1-hardening.conf steht
#   X11Forwarding no  → überschreibt die Hauptkonfiguration
#
# Dieses Script auf dem Server ausführen (mit sudo):
#   ssh io@192.168.178.20
#   cd ~/fin1-server/scripts
#   sudo bash enable-x11-forwarding.sh
#
# Falls ./enable-x11-forwarding.sh "Befehl nicht gefunden" meldet (z. B. CRLF-Zeilenenden):
#   sudo bash enable-x11-forwarding.sh
#
# Danach: Vom Mac aus Firefox mit X11-Forwarding starten:
#   ssh -Y io@192.168.178.20 firefox
#
# ============================================================================

set -e

CONF="/etc/ssh/sshd_config.d/99-fin1-hardening.conf"

if [ ! -f "$CONF" ]; then
  echo "Fehler: $CONF nicht gefunden."
  exit 1
fi

if grep -q '^X11Forwarding yes' "$CONF"; then
  echo "X11Forwarding ist bereits yes. Nichts zu tun."
  exit 0
fi

sed -i 's/^X11Forwarding no/X11Forwarding yes/' "$CONF"
echo "X11Forwarding yes gesetzt in $CONF"

systemctl restart ssh
echo "SSH-Dienst neu gestartet."
echo "X11-Forwarding ist aktiv. Teste mit: ssh -Y io@192.168.178.20 firefox"
