# Installer acceptance test

This checklist is for the first end-to-end test of the repository installer on the documented HG680P configuration. It is separate from the earlier manual driver test.

## Prepare a fresh build directory

The previous manual source and patch-test folders are not reused. Use a new directory on the external HDD:

    BUILD_DIR=/media/devmon/HardDisk/rtl8189fs-installer-test bash install.sh

Run it as the normal user, not with sudo. The installer should report that no verified prebuilt release is available yet, then fetch the pinned upstream source and build automatically. It should not ask the user to enter compiler flags or apply the patch manually.

## Expected behavior

- The running kernel and matching headers are detected.
- SDIO device 024c:f179 is found.
- The kernel 6.12 patch applies cleanly.
- The build completes and creates output/8189fs.ko.
- Module vermagic matches the running kernel.
- cfg80211 is listed as a dependency.
- The installer asks for approval before installing.
- The existing module is backed up before replacement.
- The installer reports successful installation and boot-load configuration.

If any step fails, preserve the build log in the BUILD_DIR and do not force installation.

## After installation

The already-completed manual test established Wi-Fi scanning, connection, connectivity, and reboot persistence. For this first installer test, focus on confirming that the automated build/install path completed and that the installer-owned state is present. If the new module was installed while 8189fs was already loaded, the running in-memory module remains active until a safe reload or reboot.

## Capture the prebuilt binary

After the installer has produced and validated the module, the exact module can be copied from the installed location to the HDD for a release candidate:

    cp /lib/modules/$(uname -r)/updates/8189fs.ko /media/devmon/HardDisk/8189fs-6.12.114-ophub.ko
    sha256sum /media/devmon/HardDisk/8189fs-6.12.114-ophub.ko

Before publishing it, confirm the module still reports vermagic 6.12.114-ophub and cfg80211 dependency. Commit the binary at prebuilt/6.12.114-ophub/8189fs.ko, then push a version tag (for example v1.0.0). The release-prebuilt GitHub Actions workflow validates the module, generates 8189fs-6.12.114-ophub.ko.sha256, and publishes both release assets.
