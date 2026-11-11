#!/usr/bin/env bash
set -Eeuo pipefail
[ "$EUID" -eq 0 ] || { echo "Run through install.sh or with sudo." >&2; exit 1; }
fail() { echo "ERROR: $*" >&2; exit 1; }
[ "$#" -eq 2 ] || fail "Usage: install-module.sh /path/to/8189fs.ko kernel-release"
MODULE="$1"
TARGET_KERNEL="$2"
CURRENT_KERNEL=$(uname -r)
MODULE_DIR="/lib/modules/$CURRENT_KERNEL/updates"
TARGET="$MODULE_DIR/8189fs.ko"
CONFIG="/etc/modules-load.d/hg680p-rtl8189fs.conf"
BACKUP_DIR="/var/backups/hg680p-rtl8189fs"
STATE_DIR="/var/lib/hg680p-rtl8189fs"
STAMP=$(date +%Y%m%d-%H%M%S)

[ -n "$MODULE" ] && [ -f "$MODULE" ] || fail "Usage: install-module.sh /path/to/8189fs.ko kernel-release"
[ "$TARGET_KERNEL" = "$CURRENT_KERNEL" ] || fail "Requested kernel $TARGET_KERNEL differs from running kernel $CURRENT_KERNEL."
command -v modinfo >/dev/null 2>&1 || fail "modinfo is unavailable; install kmod."
VERMAGIC=$(modinfo -F vermagic "$MODULE")
MODULE_KERNEL=$(printf '%s\n' "$VERMAGIC" | cut -d ' ' -f 1)
[ "$MODULE_KERNEL" = "$CURRENT_KERNEL" ] || fail "Module vermagic $MODULE_KERNEL does not match $CURRENT_KERNEL."
DEPENDENCIES=$(modinfo -F depends "$MODULE")
case ",$DEPENDENCIES," in *,cfg80211,*) ;; *) fail "Expected cfg80211 dependency is absent: $DEPENDENCIES." ;; esac

if [ -e "$CONFIG" ] && ! grep -qx '8189fs' "$CONFIG"; then
    fail "Existing configuration does not contain a standalone 8189fs entry; refusing to alter it: $CONFIG"
fi

install -d -m 0755 "$MODULE_DIR" "$STATE_DIR"
if [ -e "$TARGET" ]; then
    install -d -m 0700 "$BACKUP_DIR"
    cp -a "$TARGET" "$BACKUP_DIR/8189fs.ko.$STAMP"
    echo "Previous module backed up to $BACKUP_DIR/8189fs.ko.$STAMP"
fi
install -m 0644 "$MODULE" "$TARGET"
touch "$STATE_DIR/module-installed"

if [ ! -e "$CONFIG" ]; then
    printf '8189fs\n' > "$CONFIG"
    chmod 0644 "$CONFIG"
    touch "$STATE_DIR/config-created"
fi

depmod -a "$CURRENT_KERNEL"
if lsmod | awk '{print $1}' | grep -qx '8189fs'; then
    echo "8189fs is already loaded. The new file will be used after a safe reload or reboot."
else
    modprobe 8189fs
fi

echo
echo "INSTALLATION COMPLETE"
echo "Module: $TARGET"
echo "Kernel: $CURRENT_KERNEL"
echo "Autoload: $CONFIG"
