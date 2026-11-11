# Prebuilt module policy

Prebuilt modules are kernel-build specific. They are not interchangeable merely because two kernels share the 6.12 version family.

## Required checks before publishing

1. Build against the exact matching kernel headers.
2. Confirm the first field of modinfo -F vermagic 8189fs.ko exactly matches uname -r.
3. Confirm modinfo -F depends 8189fs.ko includes cfg80211.
4. Confirm modprobe loads the module.
5. Confirm SDIO detection and Wi-Fi scanning.
6. Confirm network connection and connectivity.
7. Confirm module autoload and Wi-Fi operation after reboot.
8. Record SHA-256 checksum and tested hardware, image, and kernel details.

## Release asset names

For a kernel release KERNEL, publish both files in the same GitHub Release:

    8189fs-KERNEL.ko
    8189fs-KERNEL.ko.sha256

Generate the checksum file in the same directory as the module:

    sha256sum 8189fs-KERNEL.ko > 8189fs-KERNEL.ko.sha256

The installer downloads assets from the latest release only when both files exist. It verifies the checksum, vermagic, and cfg80211 dependency before installing. If the assets are absent, it falls back to a source build.

## Current status

The exact installed module from the tested HG680P has been staged and committed in this repository at:

    prebuilt/6.12.114-ophub/8189fs.ko

The staged file's SHA-256 was compared with `/lib/modules/6.12.114-ophub/updates/8189fs.ko` on the test device; both hashes matched:

    7714cf5761ef8514c7c88c0c37619cc1c77c8f9002b92cfe4fa0a2d1e3fee735

The tested environment is HG680P, Amlogic S905X, Armbian 26.11.0 Noble ARM64, kernel 6.12.114-ophub, using the P212 device tree. Wi-Fi scanning, connection, connectivity, and autoload after reboot were verified.

The binary is present in the repository, but the downloadable GitHub Release asset has not yet been published. Push a version tag such as `v1.0.0` to trigger `.github/workflows/release-prebuilt.yml`. The workflow checks each module's vermagic against its directory name, verifies the cfg80211 dependency, generates a SHA-256 file, and creates a GitHub Release with both assets. The installer can use the local matching file from the repository before a release is available.

Do not substitute the upstream 6.1.170-ophub module; its vermagic is not compatible with 6.12.114-ophub.
