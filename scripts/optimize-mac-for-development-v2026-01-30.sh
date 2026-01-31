#!/bin/bash

# Optimize Mac (Tahoe/Apple Silicon) for Development
# This script configures power management settings for optimal development performance

set -e

echo "🔧 Optimizing Mac for Development..."
echo ""

# Check if running as root (needed for pmset)
if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script requires sudo privileges to modify power settings."
    echo "Please run: sudo $0"
    exit 1
fi

# Backup current settings
echo "📋 Backing up current power settings..."
pmset -g > /tmp/pmset-backup-$(date +%Y%m%d-%H%M%S).txt
echo "✅ Backup saved to /tmp/pmset-backup-*.txt"
echo ""

# Development-optimized power settings
echo "⚡ Applying development-optimized power settings..."

# Disable low power mode (critical for development)
pmset -a lowpowermode 0
echo "✅ Low Power Mode: DISABLED (full CPU performance)"

# Prevent sleep while plugged in (AC power)
pmset -c sleep 0
echo "✅ Sleep on AC Power: DISABLED (never sleep when plugged in)"

# Set sleep timeout on battery to 15 minutes (system sleep - Mac goes to sleep, no internet)
pmset -b sleep 15
echo "✅ System Sleep on Battery: 15 minutes (Mac goes to sleep - internet will disconnect)"

# Prevent disk sleep
pmset -a disksleep 0
echo "✅ Disk Sleep: DISABLED"

# Set display sleep to 15 minutes (longer for development)
pmset -a displaysleep 15
echo "✅ Display Sleep: 15 minutes"

# Keep network awake (important for development servers)
pmset -a networkoversleep 0
echo "✅ Network Over Sleep: DISABLED"

# Enable Power Nap (for background updates)
pmset -a powernap 1
echo "✅ Power Nap: ENABLED (for background updates)"

# Prevent system sleep when sharing display
pmset -a womp 0
echo "✅ Wake on Network Access: DISABLED"

# Keep TTY awake
pmset -a ttyskeepawake 1
echo "✅ TTY Keep Awake: ENABLED"

# TCP keepalive
pmset -a tcpkeepalive 1
echo "✅ TCP Keepalive: ENABLED"

echo ""
echo "✅ Mac optimized for development!"
echo ""
echo "📊 Current power settings:"
pmset -g
echo ""
echo "💡 Important: Display Sleep vs. System Sleep"
echo ""
echo "   📺 DISPLAY SLEEP (15 min):"
echo "      - Only screen turns off"
echo "      - Mac keeps running ✅"
echo "      - Internet works ✅"
echo "      - Downloads continue ✅"
echo "      - Just touch screen/keyboard to wake"
echo ""
echo "   💤 SYSTEM SLEEP (15 min on battery):"
echo "      - Mac goes completely to sleep"
echo "      - Internet DISCONNECTS ❌"
echo "      - Mac is off (RAM only for quick wake)"
echo "      - Open Mac to wake up"
echo ""
echo "💡 Tips:"
echo "   - Low Power Mode: DISABLED (full CPU performance)"
echo "   - Display Sleep: 15 minutes (screen off, Mac still running)"
echo "   - System Sleep (battery): 15 minutes (Mac sleeps, no internet)"
echo "   - System Sleep (AC power): DISABLED (never sleep)"
echo ""
echo "🔄 To restore previous settings, check backup files in /tmp/"
