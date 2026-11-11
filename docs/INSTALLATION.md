# Installation and build workflow

## Tested scope

The only fully tested configuration is FiberHome HG680P (Amlogic S905X), Armbian 26.11.0 Ubuntu Noble ARM64, kernel 6.12.114-ophub, and RTL8189FS SDIO ID 024c:f179. The tested setup used the P212 device tree.

The installer checks architecture, kernel headers, SDIO ID, patch applicability, module vermagic, and the cfg80211 dependency. A successful build on another kernel is not proof of runtime compatibility.

## 1. Obtain this project

    git clone https://github.com/Ag2sap/HG680P-Armbian-Kernel-6.12-RTL8189FS-WiFi-Fix.git
    cd HG680P-Armbian-Kernel-6.12-RTL8189FS-WiFi-Fix

## 2. Choose a build location

Source and logs can consume storage. Set BUILD_DIR to a writable data disk when available. Example for an external HDD:

    BUILD_DIR=/media/devmon/HardDisk/rtl8189fs-build bash install.sh

If BUILD_DIR is not set, the installer uses ~/.local/share/hg680p-rtl8189fs. Two parallel build jobs are used by default; set JOBS=1 or JOBS=2 to override.

## 3. Run

Run as the normal user, not with sudo:

    bash install.sh

The installer uses sudo for missing build prerequisites, module installation, depmod, and boot-time loading. Missing build packages are installed through apt. Matching kernel headers are required; if the exact linux-headers-KERNEL package is unavailable, install matching Armbian/Ophub headers manually and rerun.

## 4. Automated steps

1. Checks ARM64 architecture and SDIO ID 024c:f179.
2. Confirms kernel headers match uname -r.
3. Fetches a pinned upstream driver commit.
4. Checks and applies the maintained kernel 6.12 callback patch.
5. Builds using the tested flags CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT= and KCFLAGS=-Wno-error.
6. Verifies the output module, exact vermagic kernel release, and cfg80211 dependency.
7. Requests confirmation before system-level installation.
8. Installs under /lib/modules/KERNEL/updates/, runs depmod, and enables boot-time loading.

A pre-existing module at the destination is backed up under /var/backups/hg680p-rtl8189fs before replacement. The installer does not alter U-Boot, replace Armbian, change Wi-Fi credentials, or configure NetworkManager.

## 5. Prebuilt module

If a matching local file exists at prebuilt/KERNEL/8189fs.ko, the installer validates and installs it without compiling. A module built for another kernel is rejected.

A downloadable prebuilt release for 6.12.114-ophub is not published yet. It will be published only after the actual tested 8189fs.ko binary is supplied and its vermagic and checksum are verified. Do not use the upstream 6.1.170-ophub module on kernel 6.12.114-ophub.

## 6. Diagnostics and uninstall

    bash scripts/diagnose.sh
    sudo bash scripts/uninstall.sh

Uninstall asks for confirmation, unloads the driver if it is not in use, removes this project's module and boot-load configuration, restores the latest backed-up module if present, and runs depmod.

## Safety notes

- Keep Ethernet or another recovery path available.
- Do not change the device tree blindly. The tested setup used P212; an incorrect DTB can prevent boot.
- On kernels other than 6.12.114-ophub, the installer warns and requires confirmation. The patch must still apply cleanly and the built module must match the running kernel.
- Matching vermagic is necessary but does not guarantee runtime compatibility. Test scanning, connection, connectivity, and reboot persistence before relying on another kernel.
