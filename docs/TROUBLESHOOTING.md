# Troubleshooting

## The installer says the SDIO device is missing

The build helper requires SDIO vendor/device ID 024c:f179. Check:

    ls /sys/bus/sdio/devices/
    cat /sys/bus/sdio/devices/mmc0:0001:1/uevent

If the device is absent, investigate the Wi-Fi module, board revision, SDIO initialization, and active device tree before compiling. The tested HG680P setup used the P212 device tree. Do not switch DTBs blindly.

## Matching kernel headers are missing

The headers must match the running kernel exactly:

    uname -r
    readlink -f /lib/modules/$(uname -r)/build
    make -s -C /lib/modules/$(uname -r)/build kernelrelease

Install the exact Armbian/Ophub header package for the running kernel. Do not compile against generic headers or another kernel release.

## The compatibility patch does not apply

The build script pins upstream commit 786a5816a3731d57aee9eaa97744b89c4b799417. The maintained patch was checked against that revision. If the source checkout was manually changed, preserve it and choose a fresh BUILD_DIR. Do not force-apply a patch with rejected hunks.

## Compilation fails

The installer already supplies the tested compatibility flags:

    CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT=
    KCFLAGS=-Wno-error

The full build log is stored as build-KERNEL.log under BUILD_DIR. A compiler warning is not the same as a successful build; the installer still requires a valid 8189fs.ko and matching vermagic.

If the failure is caused by missing commands, rerun bash install.sh so it can install build prerequisites. If matching headers are incomplete or unavailable, install the correct Armbian/Ophub headers first.

## Module reports unknown symbols

Check that the module declares cfg80211 and let modprobe resolve dependencies:

    modinfo 8189fs
    sudo modprobe cfg80211
    sudo modprobe 8189fs
    dmesg | tail -n 80

If unresolved symbols remain, confirm that the module was built against the exact running kernel headers. Do not force-load a module built for another kernel.

## Module exists but Wi-Fi does not connect

Collect a diagnostic report:

    bash scripts/diagnose.sh

Then inspect:

    rfkill list
    ip link
    nmcli device status
    dmesg | grep -iE '8189|wlan|firmware|sdio' | tail -n 100

The verified test used wlan0 as the primary interface. wlan0 and wlan1 were virtual interfaces of one physical SDIO radio, not two separate adapters.

## Module does not load after a kernel update

External modules are specific to a kernel ABI/build. Re-run the installer after installing the new kernel's exact matching headers. The installer will warn if the kernel is not the project's exact tested kernel and will stop if the compatibility patch does not apply or the resulting vermagic does not match.
