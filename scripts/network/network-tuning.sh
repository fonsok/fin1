#!/bin/bash

# Network performance tuning helper (on-demand)
# Modes: status | transfer | connections | mtu <iface> <value> | reset [backup-file]
# Requires sudo for changes.

set -euo pipefail

DEFAULT_BACKUP_DIR="/tmp"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$DEFAULT_BACKUP_DIR/network-tuning-backup-$TIMESTAMP.txt"

usage() {
  cat <<'USAGE'
Usage: sudo ./scripts/network-tuning-v2026-01-30.sh <mode> [args]

Modes:
  status                    Show current tuning-related settings
  transfer                  Optimize TCP buffers for large transfers
  connections               Increase max queued connections (somaxconn)
  mtu <iface> <value>       Set MTU for interface (e.g., mtu Wi-Fi 1500)
  reset [backup-file]       Restore settings from backup (latest if omitted)

Notes:
  - Always run with sudo for apply/reset/mtu
  - Backups are stored in /tmp/network-tuning-backup-<timestamp>.txt
  - Uses sysctl for TCP settings; no persistent changes across reboot unless you persist manually
USAGE
}

require_sudo() {
  if [ "${EUID}" -ne 0 ]; then
    echo "⚠️  Please run with sudo" >&2
    exit 1
  fi
}

has_sysctl() {
  sysctl "$1" >/dev/null 2>&1
}

print_sysctl_if_exists() {
  local key="$1"
  if has_sysctl "$key"; then
    sysctl "$key"
  else
    echo "$key: (not available on this system)"
  fi
}

set_sysctl_if_exists() {
  local key="$1"
  local val="$2"
  if has_sysctl "$key"; then
    sysctl -w "$key=$val"
  else
    echo "Skipping $key (not available on this system)"
  fi
}

backup_settings() {
  local file="$1"
  echo "📋 Backing up current settings to $file"
  {
    print_sysctl_if_exists net.inet.tcp.sendspace
    print_sysctl_if_exists net.inet.tcp.recvspace
    print_sysctl_if_exists net.inet.tcp.sendbuf_max
    print_sysctl_if_exists net.inet.tcp.recvbuf_max
    print_sysctl_if_exists kern.ipc.somaxconn
  } > "$file"
  echo "✅ Backup saved: $file"
}

show_status() {
  echo "=== Network Tuning Status ==="
  print_sysctl_if_exists net.inet.tcp.sendspace
  print_sysctl_if_exists net.inet.tcp.recvspace
  print_sysctl_if_exists net.inet.tcp.sendbuf_max
  print_sysctl_if_exists net.inet.tcp.recvbuf_max
  print_sysctl_if_exists kern.ipc.somaxconn
  echo "--- MTU ---"
  networksetup -listallhardwareports | awk '/Device/ {dev=$2} /Hardware Port/ {hp=$3} /Wi-Fi/ {print "Wi-Fi:"dev}' | while read -r iface; do
    dev=${iface#Wi-Fi:}
    [ -n "$dev" ] && networksetup -getMTU "$dev" 2>/dev/null || true
  done
}

apply_transfer() {
  require_sudo
  backup_settings "$BACKUP_FILE"
  echo "⚡ Applying TCP buffer tuning (large transfers)"
  set_sysctl_if_exists net.inet.tcp.sendspace 1048576
  set_sysctl_if_exists net.inet.tcp.recvspace 1048576
  set_sysctl_if_exists net.inet.tcp.sendbuf_max 2097152
  set_sysctl_if_exists net.inet.tcp.recvbuf_max 2097152
  echo "✅ Applied. Backup: $BACKUP_FILE"
}

apply_connections() {
  require_sudo
  backup_settings "$BACKUP_FILE"
  echo "⚡ Increasing connection backlog"
  sysctl -w kern.ipc.somaxconn=1024
  echo "✅ Applied. Backup: $BACKUP_FILE"
}

apply_mtu() {
  require_sudo
  local iface="$1"
  local value="$2"
  echo "⚡ Setting MTU $value on $iface"
  networksetup -setMTU "$iface" "$value"
  echo "✅ MTU set."
}

find_latest_backup() {
  ls -1t /tmp/network-tuning-backup-*.txt 2>/dev/null | head -1
}

reset_from_backup() {
  require_sudo
  local file="${1:-}"
  if [ -z "$file" ]; then
    file=$(find_latest_backup)
  fi
  if [ -z "$file" ] || [ ! -f "$file" ]; then
    echo "❌ No backup file found. Provide a backup file explicitly." >&2
    exit 1
  fi
  echo "♻️  Restoring from backup: $file"
  while read -r line; do
    key=$(echo "$line" | awk -F': ' '{print $1}')
    val=$(echo "$line" | awk -F': ' '{print $2}')
    [ -n "$key" ] && [ -n "$val" ] && set_sysctl_if_exists "$key" "$val"
  done < "$file"
  echo "✅ Restored."
}

mode="${1:-status}"
shift || true

case "$mode" in
  status)
    show_status
    ;;
  transfer)
    apply_transfer
    ;;
  connections)
    apply_connections
    ;;
  mtu)
    iface="${1:-}"; value="${2:-}"
    if [ -z "$iface" ] || [ -z "$value" ]; then
      echo "❌ Usage: sudo $0 mtu <iface> <value>" >&2
      exit 1
    fi
    apply_mtu "$iface" "$value"
    ;;
  reset)
    reset_from_backup "${1:-}"
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage
    exit 1
    ;;
esac
