#!/usr/bin/env bash
set -Eeuo pipefail
[ "$EUID" -eq 0 ] || { echo "Run with sudo: sudo bash scripts/uninstall.sh" >&2; exit 1; }
KVER=$(uname -r)
TARGET="/lib/modules/$KVER/updates/8189fs.ko"
CONFIG="/etc/modules-load.d/hg680p-rtl8189fs.conf"
BACKUP_DIR="/var/backups/hg680p-rtl8189fs"
STATE_DIR="/var/lib/hg680p-rtl8189fs"

if [ ! -f "$STATE_DIR/module-installed" ]; then
    echo "No module installation recorded by this installer for kernel $KVER."
    exit 0
fi

echo "This removes the HG680P RTL8189FS module installed for kernel $KVER."
read -r -p "Continue? [y/N] " answer
case "$answer" in y|Y|yes|YES) ;; *) echo "Uninstall cancelled."; exit 0 ;; esac

if lsmod | awk '{print $1}' | grep -qx '8189fs'; then
    if ! modprobe -r 8189fs; then
        echo "The module is in use and could not be unloaded."
        echo "Disconnect Wi-Fi and stop services using wlan0, then rerun."
        exit 1
    fi
fi

rm -f "$TARGET"
if [ -f "$STATE_DIR/config-created" ]; then rm -f "$CONFIG"; fi

if [ -d "$BACKUP_DIR" ]; then
    latest_backup=$(find "$BACKUP_DIR" -maxdepth 1 -type f -name '8189fs.ko.*' -printf '%T@ %p\n' | sort -nr | head -n 1 | cut -d' ' -f2-)
    if [ -n "$latest_backup" ] && [ -f "$latest_backup" ]; then
        install -D -m 0644 "$latest_backup" "$TARGET"
        echo "Restored previous module from $latest_backup"
    fi
fi

rm -f "$STATE_DIR/module-installed" "$STATE_DIR/config-created"
depmod -a "$KVER"
echo "Uninstall complete for kernel $KVER."
