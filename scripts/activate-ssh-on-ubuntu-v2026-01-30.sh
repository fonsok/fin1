#!/bin/bash
# Script zum Aktivieren von SSH auf Ubuntu
# Dieses Script kann auf Ubuntu ausgeführt werden

echo "SSH auf Ubuntu aktivieren..."
echo ""

# Prüfen ob SSH installiert ist
if ! command -v ssh &> /dev/null; then
    echo "SSH wird installiert..."
    sudo apt update
    sudo apt install -y openssh-server
fi

# SSH-Service aktivieren und starten
echo "SSH-Service aktivieren..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Status prüfen
echo ""
echo "SSH-Status:"
sudo systemctl status ssh --no-pager

# Firewall prüfen (falls UFW aktiv ist)
if command -v ufw &> /dev/null; then
    echo ""
    echo "Firewall-Regel für SSH hinzufügen..."
    sudo ufw allow ssh
    sudo ufw status | grep ssh || echo "Firewall nicht aktiv"
fi

# IP-Adresse anzeigen
echo ""
echo "Server IP-Adresse:"
hostname -I | awk '{print $1}'

echo ""
echo "✅ SSH sollte jetzt aktiv sein!"
echo "Testen Sie vom Mac aus: ssh iobox@192.168.178.24"
