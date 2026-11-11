#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR=$(cd -- "$(dirname -- "$0")" && pwd)
KVER=$(uname -r)
BUILD_DIR=$(printenv BUILD_DIR || printf '%s\n' "$HOME/.local/share/hg680p-rtl8189fs")
JOBS=$(printenv JOBS || printf '2\n')
LOCAL_PREBUILT="$ROOT_DIR/prebuilt/$KVER/8189fs.ko"
CACHED_PREBUILT="$BUILD_DIR/prebuilt/$KVER/8189fs.ko"
MODULE=""

fail() { echo "ERROR: $*" >&2; exit 1; }
valid_module() {
    [ -s "$1" ] || return 1
    VERMAGIC=$(modinfo -F vermagic "$1" 2>/dev/null) || return 1
    MODULE_KERNEL=$(printf '%s\n' "$VERMAGIC" | cut -d ' ' -f 1)
    [ "$MODULE_KERNEL" = "$KVER" ] || return 1
    DEPENDENCIES=$(modinfo -F depends "$1" 2>/dev/null) || return 1
    case ",$DEPENDENCIES," in *,cfg80211,*) return 0 ;; *) return 1 ;; esac
}

if [ "$EUID" -eq 0 ]; then fail "Run as a normal user: bash install.sh. The script uses sudo only for system changes."; fi
command -v sudo >/dev/null 2>&1 || fail "sudo is required."
sudo -v

if ! command -v modinfo >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y kmod
fi

if [ -f "$LOCAL_PREBUILT" ]; then
    if valid_module "$LOCAL_PREBUILT"; then
        echo "Found a valid local prebuilt module."
        MODULE="$LOCAL_PREBUILT"
    else
        echo "Ignoring local prebuilt: vermagic or cfg80211 dependency does not match $KVER."
    fi
fi

if [ -z "$MODULE" ] && [ -f "$CACHED_PREBUILT" ]; then
    if valid_module "$CACHED_PREBUILT"; then
        echo "Found a valid cached prebuilt module."
        MODULE="$CACHED_PREBUILT"
    else
        echo "Ignoring cached prebuilt: it does not match the running kernel."
    fi
fi

if [ -z "$MODULE" ] && ! command -v curl >/dev/null 2>&1; then
    echo "curl is needed to check for a downloadable prebuilt module."
    sudo apt-get update
    sudo apt-get install -y curl
fi

if [ -z "$MODULE" ] && command -v curl >/dev/null 2>&1 && command -v sha256sum >/dev/null 2>&1; then
    if bash "$ROOT_DIR/scripts/fetch-prebuilt.sh" "$BUILD_DIR/prebuilt/$KVER" "$KVER"; then
        if valid_module "$CACHED_PREBUILT"; then MODULE="$CACHED_PREBUILT"; fi
    fi
fi

if [ -z "$MODULE" ]; then
    echo "No verified prebuilt module is available. Preparing a source build."
    missing=0
    for cmd in git patch make gcc bc; do
        if ! command -v "$cmd" >/dev/null 2>&1; then missing=1; fi
    done
    if [ "$missing" -eq 1 ]; then
        echo "Installing build prerequisites."
        sudo apt-get update
        sudo apt-get install -y build-essential git patch bc
    fi
    if [ ! -f "/lib/modules/$KVER/build/Makefile" ]; then
        echo "Matching kernel headers are missing. Trying the exact distribution package."
        sudo apt-get update
        sudo apt-get install -y "linux-headers-$KVER" || fail "Install the exact Armbian/Ophub headers for $KVER, then rerun."
    fi
    BUILD_DIR="$BUILD_DIR" JOBS="$JOBS" bash "$ROOT_DIR/scripts/build.sh"
    MODULE="$BUILD_DIR/output/8189fs.ko"
fi

[ -s "$MODULE" ] || fail "Module file not found: $MODULE"
echo
echo "Module: $MODULE"
echo "Kernel: $KVER"
read -r -p "Install this module and enable loading at boot? [y/N] " answer
case "$answer" in
    y|Y|yes|YES) sudo bash "$ROOT_DIR/scripts/install-module.sh" "$MODULE" "$KVER" ;;
    *) echo "Installation cancelled. The module has been kept at $MODULE."; exit 0 ;;
esac
