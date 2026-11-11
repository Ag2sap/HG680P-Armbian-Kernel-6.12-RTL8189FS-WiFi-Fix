#!/usr/bin/env bash
set -Eeuo pipefail
DEST_DIR="$1"
KVER="$2"
ASSET="8189fs-$KVER.ko"
BASE_URL="https://github.com/Ag2sap/HG680P-Armbian-Kernel-6.12-RTL8189FS-WiFi-Fix/releases/latest/download"
mkdir -p "$DEST_DIR"
WORK_DIR=$(mktemp -d "$DEST_DIR/.download-$KVER.XXXXXX")
trap 'rm -rf "$WORK_DIR"' EXIT

if ! curl -fsSL "$BASE_URL/$ASSET" -o "$WORK_DIR/$ASSET"; then
    echo "No prebuilt release asset is published for kernel $KVER."
    exit 1
fi
if ! curl -fsSL "$BASE_URL/$ASSET.sha256" -o "$WORK_DIR/$ASSET.sha256"; then
    echo "The prebuilt module has no downloadable SHA-256 file; refusing to use it."
    exit 1
fi
if ! (cd "$WORK_DIR" && sha256sum -c "$ASSET.sha256"); then
    echo "Prebuilt module checksum verification failed; refusing to use it."
    exit 1
fi
VERMAGIC=$(modinfo -F vermagic "$WORK_DIR/$ASSET")
MODULE_KERNEL=$(printf '%s\n' "$VERMAGIC" | cut -d ' ' -f 1)
if [ "$MODULE_KERNEL" != "$KVER" ]; then
    echo "Prebuilt module vermagic $MODULE_KERNEL does not match $KVER."
    exit 1
fi
DEPENDENCIES=$(modinfo -F depends "$WORK_DIR/$ASSET")
case ",$DEPENDENCIES," in *,cfg80211,*) ;; *) echo "Prebuilt module does not declare cfg80211 dependency."; exit 1 ;; esac
install -m 0644 "$WORK_DIR/$ASSET" "$DEST_DIR/8189fs.ko"
echo "Verified prebuilt module saved to $DEST_DIR/8189fs.ko"
