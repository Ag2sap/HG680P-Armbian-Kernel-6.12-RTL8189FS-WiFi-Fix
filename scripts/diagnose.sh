#!/usr/bin/env bash
set -u
KVER=$(uname -r)
echo "=== System ==="
printf 'Kernel: %s\nArchitecture: %s\n' "$KVER" "$(uname -m)"
printf 'Headers: '
if [ -e "/lib/modules/$KVER/build" ]; then readlink -f "/lib/modules/$KVER/build"; else echo "missing"; fi
echo
echo "=== SDIO devices ==="
found=0
for dev in /sys/bus/sdio/devices/*; do
    [ -r "$dev/vendor" ] && [ -r "$dev/device" ] || continue
    printf '%s vendor=%s device=%s\n' "$(basename "$dev")" "$(cat "$dev/vendor")" "$(cat "$dev/device")"
    found=1
done
[ "$found" -eq 1 ] || echo "No SDIO devices with readable vendor/device attributes."
echo
echo "=== Driver module ==="
if command -v modinfo >/dev/null 2>&1 && modinfo 8189fs >/dev/null 2>&1; then
    modinfo 8189fs | grep -E '^(filename|version|depends|vermagic|alias):' || true
else
    echo "8189fs module is not installed or modinfo is unavailable."
fi
lsmod | grep -E '^(8189fs|cfg80211|rfkill)\b' || true
echo
echo "=== Network interfaces ==="
ip -brief link 2>/dev/null | grep -E '(^| )(wlan|wl)' || true
if command -v nmcli >/dev/null 2>&1; then nmcli device status; fi
echo
echo "=== Recent driver messages ==="
dmesg 2>/dev/null | grep -iE '8189|wlan|firmware|sdio' | tail -n 60 || true
