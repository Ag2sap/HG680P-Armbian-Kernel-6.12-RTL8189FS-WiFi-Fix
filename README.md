# HG680P Armbian RTL8189FS Wi-Fi Fix

A focused build and installation helper for the Realtek RTL8189FS SDIO Wi-Fi adapter on Armbian ARM64. The project automates the compatibility adjustment and compiler workarounds verified on the HG680P test device.

> **Tested configuration:** FiberHome HG680P, Amlogic S905X, Armbian 26.11.0 Ubuntu Noble ARM64, kernel 6.12.114-ophub, P212 device tree, RTL8189FS SDIO 024c:f179. Other combinations are not yet verified.

## Quick installation

Clone this repository on the Armbian device:

    git clone https://github.com/Ag2sap/HG680P-Armbian-Kernel-6.12-RTL8189FS-WiFi-Fix.git
    cd HG680P-Armbian-Kernel-6.12-RTL8189FS-WiFi-Fix

Run the installer as your normal user (do not prefix it with sudo):

    bash install.sh

If you want all source files and build logs on an external HDD, set BUILD_DIR:

    BUILD_DIR=/media/devmon/HardDisk/rtl8189fs-build bash install.sh

The installer requests sudo only when needed. It installs missing build tools through apt, checks for matching kernel headers, fetches the pinned upstream source, applies the maintained patch, builds the module, verifies its kernel vermagic and cfg80211 dependency, and asks before installing it.

Default build parallelism is two jobs. You can set JOBS=1 if memory is limited.

## What is automated

- Detects ARM64 and the RTL8189FS SDIO ID 024c:f179.
- Confirms the active kernel headers match the running kernel.
- Fetches upstream source at a pinned commit to avoid unexpected changes from a moving branch.
- Applies the kernel 6.12 cfg80211 callback patch automatically.
- Applies the tested build compatibility flags automatically:
  - CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT=
  - KCFLAGS=-Wno-error
- Checks that 8189fs.ko was produced, its vermagic matches the running kernel, and cfg80211 is declared as a dependency.
- Installs the module under /lib/modules/KERNEL/updates/, runs depmod, and configures module autoload at boot.
- Backs up an existing module before replacing it.
- Keeps the complete build log in BUILD_DIR.

The script does not replace Armbian, change U-Boot, modify Wi-Fi credentials, or configure NetworkManager.

## Prebuilt module

The installer supports a local prebuilt module at:

    prebuilt/KERNEL/8189fs.ko

If a matching file is present, it validates and installs it without compiling. A binary for kernel 6.12.114-ophub has **not yet been published as a GitHub Release asset** because the exact tested .ko file still needs to be uploaded from the test device. We will publish it only after checking its vermagic and SHA-256 checksum. Do not use the upstream 6.1.170-ophub module on kernel 6.12.114-ophub.

See [Prebuilt module policy](docs/PREBUILT-MODULE.md).

## Tested configuration and results

| Item | Tested value |
|---|---|
| TV box | HG680P |
| SoC | Amlogic S905X |
| OS image | Armbian 26.11.0 Ubuntu Noble server (ARM64) |
| Kernel | 6.12.114-ophub |
| Device tree | meson-gxl-s905x-p212.dtb |
| Wi-Fi chipset | Realtek RTL8189FS |
| SDIO ID | 024c:f179 |

Verified on the test device:
- SDIO adapter detected.
- Driver compiled against matching kernel headers.
- Module loaded with cfg80211 dependency.
- Nearby Wi-Fi networks scanned.
- NetworkManager connected to an access point.
- Router, public IP, and DNS connectivity tested through Wi-Fi.
- Module autoload and Wi-Fi connection survived reboot.

The driver exposed wlan0 and wlan1 in this test. They are virtual interfaces associated with the same SDIO radio, not two separate physical Wi-Fi adapters. Use wlan0 as the primary interface unless you have a reason to configure the second interface.

**Compatibility is not universal.** The tested Armbian image filename was B860H-targeted, but the actual test hardware was an HG680P using the P212 device tree. Other board revisions, B860H devices, kernels, images, and device trees are not guaranteed. For kernels other than 6.12.114-ophub, the installer warns and requires confirmation. A successful build and matching vermagic do not prove runtime compatibility.

## Build location and requirements

- ARM64 Armbian/Linux.
- Matching kernel headers at /lib/modules/$(uname -r)/build.
- A detected SDIO device with ID 024c:f179.
- Internet access to fetch the pinned upstream source.
- Build tools: git, patch, make, GCC, bc, and kmod. The installer offers to install missing packages.
- Enough free space for source, object files, module, and logs. Prefer an external data drive when eMMC space is limited.

The tested setup used an external HDD for source and build output. The project does not use /tmp for the build.

## Diagnostics and uninstall

Collect a diagnostic report:

    bash scripts/diagnose.sh

Uninstall this project's module:

    sudo bash scripts/uninstall.sh

The uninstall script asks for confirmation, unloads the driver if it is not in use, removes the module and only the autoload configuration created by this installer, restores a previously backed-up module if one exists, and runs depmod.

For detailed steps and troubleshooting, see [Installation guide](docs/INSTALLATION.md).

## Upstream source and patch

The driver source is fetched from [gustiarto/rtl8189fs-armbian](https://github.com/gustiarto/rtl8189fs-armbian) at commit:

    786a5816a3731d57aee9eaa97744b89c4b799417

This repository maintains the narrow [kernel 6.12 cfg80211 callback patch](patches/kernel-6.12/0001-cfg80211-set-monitor-channel-signature.patch). The patch was dry-run and applied successfully against a clean upstream source checkout. GitHub Actions also checks the shell scripts and patch applicability.

The upstream README identifies the driver as GPL-2.0. Upstream source is fetched separately and is not copied into this repository. Review the upstream project and its license before redistributing source or binaries.

## Disclaimer

Unofficial community project, provided without warranty. Keep Ethernet or another recovery path available during installation. Do not change the device tree blindly; an incorrect DTB can prevent the system from booting. Users are responsible for checking hardware compatibility and reviewing system-level changes.
