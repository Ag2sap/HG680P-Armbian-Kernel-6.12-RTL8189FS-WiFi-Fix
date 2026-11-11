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

## Current status

A build and runtime installation have been verified on HG680P with Armbian 26.11.0 Noble and kernel 6.12.114-ophub. The actual tested module binary remains on the test device and has not yet been uploaded as a GitHub Release asset.

The installer already supports a matching local module at:

    prebuilt/6.12.114-ophub/8189fs.ko

Once the binary is supplied and verified, it can be attached to a versioned GitHub Release. Users should download only the asset matching their exact kernel release.

Do not substitute the upstream 6.1.170-ophub module; its vermagic is not compatible with 6.12.114-ophub.
