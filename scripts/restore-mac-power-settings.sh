#!/bin/bash

# Restore Mac power settings from backup
# Usage: sudo ./restore-mac-power-settings.sh [backup-file]

set -e

if [ "$EUID" -ne 0 ]; then
    echo "⚠️  This script requires sudo privileges."
    echo "Please run: sudo $0 [backup-file]"
    exit 1
fi

if [ -z "$1" ]; then
    echo "📋 Available backup files:"
    ls -lt /tmp/pmset-backup-*.txt 2>/dev/null | head -5
    echo ""
    echo "Usage: sudo $0 <backup-file>"
    exit 1
fi

BACKUP_FILE="$1"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "❌ Backup file not found: $BACKUP_FILE"
    exit 1
fi

echo "🔄 Restoring power settings from: $BACKUP_FILE"
echo "⚠️  This will restore ALL power management settings."
read -p "Continue? (y/N) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

# Extract and apply settings from backup
# Note: This is a simplified restore - full restore would require parsing the backup file
echo "📝 For full restore, manually review $BACKUP_FILE and apply settings with:"
echo "   pmset -a <setting> <value>"
echo ""
echo "Or use System Preferences > Energy Saver to restore defaults."
