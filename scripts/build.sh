#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR=$(cd -- "$(dirname -- "$0")/.." && pwd)
KVER=$(uname -r)
ARCH=$(uname -m)
BUILD_DIR=$(printenv BUILD_DIR || printf '%s\n' "$HOME/.local/share/hg680p-rtl8189fs")
JOBS=$(printenv JOBS || printf '2\n')
UPSTREAM_URL="https://github.com/gustiarto/rtl8189fs-armbian.git"
UPSTREAM_COMMIT="786a5816a3731d57aee9eaa97744b89c4b799417"
PATCH_FILE="$ROOT_DIR/patches/kernel-6.12/0001-cfg80211-set-monitor-channel-signature.patch"
SOURCE_DIR="$BUILD_DIR/source-$KVER"
OUTPUT_DIR="$BUILD_DIR/output"
LOG_FILE="$BUILD_DIR/build-$KVER.log"
KERNEL_BUILD="/lib/modules/$KVER/build"
fail() { echo "ERROR: $*" >&2; exit 1; }

[ "$EUID" -ne 0 ] || fail "Build as a normal user, not root."
case "$ARCH" in aarch64|arm64) ;; *) fail "ARM64 is required; detected $ARCH." ;; esac
[ -f "$PATCH_FILE" ] || fail "Compatibility patch is missing: $PATCH_FILE"
[ -f "$KERNEL_BUILD/Makefile" ] || fail "Matching kernel headers are missing: $KERNEL_BUILD"
for cmd in git patch make gcc bc modinfo; do
    command -v "$cmd" >/dev/null 2>&1 || fail "Required command $cmd is missing. Run install.sh first."
done

HEADER_RELEASE=$(make -s -C "$KERNEL_BUILD" kernelrelease)
[ "$HEADER_RELEASE" = "$KVER" ] || fail "Header release $HEADER_RELEASE does not match running kernel $KVER."

SDIO_FOUND=0
shopt -s nullglob
for dev in /sys/bus/sdio/devices/*; do
    [ -r "$dev/vendor" ] && [ -r "$dev/device" ] || continue
    vendor=$(tr '[:upper:]' '[:lower:]' < "$dev/vendor" | sed 's/^0x//')
    device=$(tr '[:upper:]' '[:lower:]' < "$dev/device" | sed 's/^0x//')
    if [ "$vendor" = "024c" ] && [ "$device" = "f179" ]; then SDIO_FOUND=1; break; fi
done
[ "$SDIO_FOUND" -eq 1 ] || fail "RTL8189FS SDIO device 024c:f179 was not detected. Check hardware and device tree."

if [ "$KVER" != "6.12.114-ophub" ]; then
    echo "WARNING: $KVER is not the exact kernel tested by this project (6.12.114-ophub)."
    echo "A successful build does not guarantee runtime compatibility."
    read -r -p "Attempt this unverified kernel anyway? [y/N] " answer
    case "$answer" in y|Y|yes|YES) ;; *) fail "Stopped outside the tested kernel configuration." ;; esac
fi

mkdir -p "$BUILD_DIR" "$OUTPUT_DIR"
if [ -d "$SOURCE_DIR/.git" ]; then
    remote=$(git -C "$SOURCE_DIR" remote get-url origin)
    actual_commit=$(git -C "$SOURCE_DIR" rev-parse HEAD)
    [ "$remote" = "$UPSTREAM_URL" ] || fail "Existing source directory has a different Git remote: $SOURCE_DIR"
    [ "$actual_commit" = "$UPSTREAM_COMMIT" ] || fail "Existing source directory is not the pinned upstream revision."
    echo "Reusing the pinned upstream source and cleaning previous build outputs..."
    make -C "$SOURCE_DIR" clean >/dev/null 2>&1 || true
elif [ -e "$SOURCE_DIR" ]; then
    fail "Source path exists but is not the expected Git checkout: $SOURCE_DIR. Move it aside; no files were deleted."
else
    echo "Fetching pinned upstream source $UPSTREAM_COMMIT..."
    mkdir -p "$SOURCE_DIR"
    git -C "$SOURCE_DIR" init -q
    git -C "$SOURCE_DIR" remote add origin "$UPSTREAM_URL"
    git -C "$SOURCE_DIR" fetch --depth 1 origin "$UPSTREAM_COMMIT"
    git -C "$SOURCE_DIR" checkout --detach -q FETCH_HEAD
fi

actual_commit=$(git -C "$SOURCE_DIR" rev-parse HEAD)
[ "$actual_commit" = "$UPSTREAM_COMMIT" ] || fail "Upstream commit verification failed."

echo "Checking and applying the kernel 6.12 patch..."
if patch --dry-run -p1 -d "$SOURCE_DIR" < "$PATCH_FILE" >/dev/null 2>&1; then
    patch -p1 -d "$SOURCE_DIR" < "$PATCH_FILE"
elif patch --dry-run -R -p1 -d "$SOURCE_DIR" < "$PATCH_FILE" >/dev/null 2>&1; then
    echo "Patch is already applied."
else
    fail "Patch does not match the pinned upstream source. Build stopped."
fi

actual_diff=$(git -C "$SOURCE_DIR" diff --numstat | tr '\t' ' ')
[ "$actual_diff" = "1 1 os_dep/linux/ioctl_cfg80211.c" ] || fail "Source tree contains changes beyond the single maintained cfg80211 patch."

echo "Building for $KVER with $JOBS job(s). Log: $LOG_FILE"
if ! make -C "$SOURCE_DIR" -j"$JOBS" ARCH=arm64 KSRC="$KERNEL_BUILD" CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT= KCFLAGS=-Wno-error > "$LOG_FILE" 2>&1; then
    echo "Build failed. Last 100 log lines:"
    tail -n 100 "$LOG_FILE" >&2
    fail "Compilation failed. Full log: $LOG_FILE"
fi

BUILT_MODULE="$SOURCE_DIR/8189fs.ko"
[ -s "$BUILT_MODULE" ] || { tail -n 100 "$LOG_FILE" >&2; fail "Build completed without producing 8189fs.ko."; }
VERMAGIC=$(modinfo -F vermagic "$BUILT_MODULE")
MODULE_KERNEL=$(printf '%s\n' "$VERMAGIC" | cut -d ' ' -f 1)
[ "$MODULE_KERNEL" = "$KVER" ] || fail "Module vermagic $MODULE_KERNEL does not match $KVER."
DEPENDENCIES=$(modinfo -F depends "$BUILT_MODULE")
case ",$DEPENDENCIES," in *,cfg80211,*) ;; *) fail "Expected cfg80211 dependency is absent: $DEPENDENCIES." ;; esac

install -m 0644 "$BUILT_MODULE" "$OUTPUT_DIR/8189fs.ko"
printf '%s\n' "$KVER" > "$OUTPUT_DIR/kernel-release.txt"
printf '%s\n' "$UPSTREAM_COMMIT" > "$OUTPUT_DIR/upstream-commit.txt"
echo
echo "BUILD SUCCESS"
echo "Module: $OUTPUT_DIR/8189fs.ko"
echo "Kernel: $KVER"
echo "Vermagic: $VERMAGIC"
echo "Dependencies: $DEPENDENCIES"
echo "Log: $LOG_FILE"
