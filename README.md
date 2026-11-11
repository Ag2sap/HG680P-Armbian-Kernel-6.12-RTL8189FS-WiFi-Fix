# HG680P Armbian RTL8189FS Wi-Fi Fix

A focused build and installation helper for the Realtek RTL8189FS SDIO Wi-Fi adapter on Armbian ARM64. The project automates the compatibility adjustment and compiler workarounds verified on the HG680P test device.

> **Tested configuration:** FiberHome HG680P, Amlogic S905X, Armbian 26.11.0 Ubuntu Noble ARM64, kernel 6.12.114-ophub, P212 device tree, RTL8189FS SDIO 024c:f179. Other combinations are not yet verified.

## Quick installation

Clone this repository on the Armbian device:

    git clone https://github.com/Ag2sap/HG680P-Armbian-Kernel-6.12-RTL8189FS-WiFi-Fix.git
    cd HG680P-Armbian-Kernel-6.12-RTL8189FS-WiFi-Fix

Run the installer as your normal user (do not prefix it with sudo):

    bash install.sh

To keep the build workspace and logs on an external HDD:

    BUILD_DIR=/media/devmon/HardDisk/rtl8189fs-build bash install.sh

The installer first looks for a matching local prebuilt module, then checks the latest GitHub Release for a kernel-specific module and SHA-256 file. If no verified prebuilt is available, it automatically builds from pinned upstream source. It requests sudo only for required system changes and asks before installing the module.

Default build parallelism is two jobs. Set JOBS=1 if memory is limited.

## What is automated

- Detects ARM64 and RTL8189FS SDIO ID 024c:f179.
- Confirms the active kernel headers match the running kernel.
- Fetches upstream source at a pinned commit, not a moving branch.
- Applies the kernel 6.12 cfg80211 callback patch.
- Applies the tested build compatibility flags:
  - CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT=
  - KCFLAGS=-Wno-error
- Verifies module output, kernel vermagic, and cfg80211 dependency.
- Installs under /lib/modules/KERNEL/updates/, runs depmod, and configures module autoload at boot.
- Backs up an existing module before replacing it.
- Preserves installer state so uninstall removes only configuration created by this project.
- Keeps build logs in BUILD_DIR.

The installer does not replace Armbian, change U-Boot, modify Wi-Fi credentials, or configure NetworkManager. After a successful source build, the downloaded source tree and compiler artifacts are removed by default; the verified module and build log remain in BUILD_DIR. Set KEEP_SOURCE=1 when running the installer to retain the source tree for debugging.

## Prebuilt module

A matching local module can be placed at:

    prebuilt/KERNEL/8189fs.ko

The installer can also download a matching asset from the latest GitHub Release. The release must contain both:

    8189fs-KERNEL.ko
    8189fs-KERNEL.ko.sha256

On the tested HG680P, after installing and validating the driver, run `bash scripts/stage-prebuilt.sh` from this repository to copy the installed module into `prebuilt/$(uname -r)/8189fs.ko`. Review and commit that binary, then push a version tag such as v1.0.0. The release workflow validates vermagic and cfg80211, generates the checksum file, and publishes both assets. The installer verifies the checksum, vermagic, and cfg80211 dependency before using the binary. If no release asset is available, it falls back to source compilation.

A downloadable prebuilt for kernel 6.12.114-ophub has **not yet been published**; the exact tested .ko file still needs to be staged from the test device and committed. We will publish it only after checking its metadata and SHA-256 checksum. Do not use the upstream 6.1.170-ophub module on kernel 6.12.114-ophub.

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

The driver exposed wlan0 and wlan1 in this test. They are virtual interfaces associated with the same SDIO radio, not two separate physical Wi-Fi adapters. Use wlan0 as the primary interface unless there is a reason to configure the second interface.

**Compatibility is not universal.** The tested Armbian image filename was B860H-targeted, but the actual test hardware was an HG680P using the P212 device tree. Other board revisions, B860H devices, kernels, images, and device trees are not guaranteed. For kernels other than 6.12.114-ophub, the installer warns and requires confirmation. A successful build and matching vermagic do not prove runtime compatibility.

## Requirements and storage

- ARM64 Armbian/Linux.
- Matching headers at /lib/modules/$(uname -r)/build.
- Detected SDIO device ID 024c:f179.
- Internet access to fetch the pinned upstream source.
- git, patch, make, GCC, bc, kmod; missing build packages are offered through apt.
- Enough free space for source, object files, module, and logs.

The tested setup used an external HDD for source and build output. The project does not use /tmp for the build.

## Diagnostics and uninstall

    bash scripts/diagnose.sh
    sudo bash scripts/uninstall.sh

The diagnostic script reports kernel/header state, SDIO IDs, module metadata, interfaces, and recent driver messages. Uninstall asks for confirmation, unloads the driver if not in use, removes this project's module and only its own autoload configuration, restores a backed-up module if one exists, and runs depmod.

See the [Installation guide](docs/INSTALLATION.md), [Troubleshooting](docs/TROUBLESHOOTING.md), and [first installer acceptance test](docs/ACCEPTANCE-TEST.md).

## Upstream source and patch

The driver source is fetched from [gustiarto/rtl8189fs-armbian](https://github.com/gustiarto/rtl8189fs-armbian) at pinned commit:

    786a5816a3731d57aee9eaa97744b89c4b799417

This repository maintains the narrow [kernel 6.12 cfg80211 callback patch](patches/kernel-6.12/0001-cfg80211-set-monitor-channel-signature.patch). GitHub Actions validates shell syntax, runs ShellCheck, and checks patch applicability against that exact upstream commit.

The upstream README identifies the driver as GPL-2.0. Upstream source is fetched separately and is not copied into this repository. Review the upstream project and its license before redistributing source or binaries.

## Disclaimer

Unofficial community project, provided without warranty. Keep Ethernet or another recovery path available during installation. Do not change the device tree blindly; an incorrect DTB can prevent the system from booting. Users are responsible for checking hardware compatibility and reviewing system-level changes.
