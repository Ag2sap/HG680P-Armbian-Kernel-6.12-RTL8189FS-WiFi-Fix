# Installation and build workflow

## Tested scope

The only fully tested configuration is FiberHome HG680P (Amlogic S905X), Armbian 26.11.0 Ubuntu Noble ARM64, kernel 6.12.114-ophub, and RTL8189FS SDIO ID 024c:f179. The tested setup used the P212 device tree.

The installer checks architecture, kernel headers, SDIO ID, patch applicability, module vermagic, and cfg80211 dependency. A successful build on another kernel is not proof of runtime compatibility.

## 1. Obtain this project

    git clone https://github.com/Ag2sap/HG680P-WiFi-Fix-Armbian-ARM64-RTL8189FS-Driver-Kernel-6.12-.git
    cd HG680P-WiFi-Fix-Armbian-ARM64-RTL8189FS-Driver-Kernel-6.12-

## 2. Choose a build location

The temporary source/build workspace and logs can consume storage. Set BUILD_DIR to a writable data disk when available:

    BUILD_DIR=/media/devmon/HardDisk/rtl8189fs-build bash install.sh

If unset, the installer uses ~/.local/share/hg680p-rtl8189fs. Two parallel jobs are used by default; set JOBS=1 or JOBS=2 to override.

## 3. Run

Run as the normal user, not with sudo:

    bash install.sh

The installer uses sudo for missing prerequisites, module installation, depmod, and boot-time loading. Missing build packages are installed through apt. Matching kernel headers are required; if the exact linux-headers-KERNEL package is unavailable, install matching Armbian/Ophub headers manually and rerun.

## 4. Automated workflow

1. Checks ARM64 architecture and SDIO ID 024c:f179.
2. Confirms headers match uname -r.
3. Checks for a local prebuilt module, then attempts to download a kernel-specific asset from the latest GitHub Release.
4. Verifies release asset SHA-256, module vermagic, and cfg80211 dependency.
5. If no verified prebuilt is available, fetches the pinned upstream source and applies the maintained kernel 6.12 callback patch.
6. Builds using CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT= and KCFLAGS=-Wno-error.
7. Verifies module output and matching vermagic/dependency metadata. After a successful build, removes the downloaded source tree and compiler artifacts by default; the verified module and build log remain in BUILD_DIR. Set KEEP_SOURCE=1 to retain the source tree for debugging.
8. Requests confirmation before system-level installation.
9. Installs under /lib/modules/KERNEL/updates/, runs depmod, and enables boot-time loading.

A pre-existing module at the destination is backed up under /var/backups/hg680p-rtl8189fs. Existing module-load configuration is preserved. The installer records which files it created so uninstall does not remove a pre-existing configuration.

## 5. Prebuilt module release

The latest release must provide two assets for the exact kernel:

- 8189fs-KERNEL.ko
- 8189fs-KERNEL.ko.sha256

Generate the checksum file alongside the module using:

    sha256sum 8189fs-KERNEL.ko > 8189fs-KERNEL.ko.sha256

The actual prebuilt for 6.12.114-ophub has not yet been uploaded. On the tested device, run `bash scripts/stage-prebuilt.sh` from the repository checkout to stage the already-installed module under `prebuilt/$(uname -r)/8189fs.ko`; commit it and push a version tag to publish the release assets. Until then, the installer falls back to source compilation. Do not use the upstream 6.1.170-ophub module on kernel 6.12.114-ophub.

## 6. Diagnostics and uninstall

    bash scripts/diagnose.sh
    sudo bash scripts/uninstall.sh

Uninstall asks for confirmation, unloads the driver if it is not in use, removes this project's module and only its own boot-load configuration, restores the latest backed-up module if present, and runs depmod.

## Safety notes

- Keep Ethernet or another recovery path available.
- Do not change the device tree blindly. The tested setup used P212; an incorrect DTB can prevent boot.
- On kernels other than 6.12.114-ophub, the installer warns and requires confirmation. The patch must still apply cleanly and the built module must match the running kernel.
- Matching vermagic is necessary but does not guarantee runtime compatibility. Test scanning, connection, connectivity, and reboot persistence before relying on another kernel.
