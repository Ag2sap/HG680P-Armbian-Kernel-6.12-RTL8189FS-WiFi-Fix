#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
KVER=$(uname -r)
SOURCE_MODULE="/lib/modules/$KVER/updates/8189fs.ko"
DEST_DIR="$ROOT_DIR/prebuilt/$KVER"
DEST_MODULE="$DEST_DIR/8189fs.ko"

fail() { echo "ERROR: $*" >&2; exit 1; }

[ "$EUID" -ne 0 ] || fail "Run as your normal user; sudo is not required."
[ -r "$SOURCE_MODULE" ] || fail "Installed module not found or unreadable: $SOURCE_MODULE"
command -v modinfo >/dev/null 2>&1 || fail "modinfo is required (install kmod)."
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required."

VERMAGIC=$(modinfo -F vermagic "$SOURCE_MODULE") || fail "Unable to read module vermagic."
MODULE_KERNEL=$(printf '%s\n' "$VERMAGIC" | cut -d ' ' -f 1)
[ "$MODULE_KERNEL" = "$KVER" ] || fail "Installed module vermagic $MODULE_KERNEL does not match running kernel $KVER."
DEPENDENCIES=$(modinfo -F depends "$SOURCE_MODULE") || fail "Unable to read module dependencies."
case ",$DEPENDENCIES," in *,cfg80211,*) ;; *) fail "Installed module does not declare cfg80211 dependency: $DEPENDENCIES" ;; esac

if [ -e "$DEST_MODULE" ]; then
    read -r -p "Replace existing staged module $DEST_MODULE? [y/N] " answer
    case "$answer" in y|Y|yes|YES) ;; *) echo "Staging cancelled."; exit 0 ;; esac
fi

mkdir -p "$DEST_DIR"
install -m 0644 "$SOURCE_MODULE" "$DEST_MODULE"
echo "Staged verified module: $DEST_MODULE"
echo "Kernel: $KVER"
echo "Vermagic: $VERMAGIC"
echo "Dependencies: $DEPENDENCIES"
echo "SHA-256:"
sha256sum "$DEST_MODULE"
echo
echo "Next: review the binary, commit it, and push a version tag to publish the prebuilt release."
