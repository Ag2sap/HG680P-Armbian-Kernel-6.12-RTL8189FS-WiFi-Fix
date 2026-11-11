# HG680P Armbian RTL8189FS Wi-Fi Fix

Unofficial build and installation notes for the RTL8189FS SDIO Wi-Fi adapter on an **HG680P** running a tested Armbian 26.11.0 Ubuntu Noble server image with the **6.12.114-ophub** kernel.

> **Project status:** The driver has been built, installed, loaded automatically after reboot, and tested successfully on the hardware/software combination documented below. This repository is being prepared to turn that verified procedure into a repeatable installer. Until the installer scripts are published, do not expect a one-command installation from this README.

## Tested configuration

| Item | Tested value |
|---|---|
| TV box | HG680P |
| SoC | Amlogic S905X |
| OS image | `Armbian_26.11.0_amlogic_s905x-b860h_noble_6.12.114_server_2026.11.02.img.gz` |
| Distribution | Ubuntu Noble 24.04 (ARM64) |
| Kernel | `6.12.114-ophub` |
| Device tree | `meson-gxl-s905x-p212.dtb` |
| Wi-Fi chipset/driver | Realtek RTL8189FS / `8189fs` |
| SDIO identification | Vendor `024c`, device `f179` |

**Compatibility is not universal.** The image filename identifies a B860H-targeted build, but the tested device was an HG680P configured with the P212 device tree. Other HG680P revisions, B860H devices, Armbian images, kernels, and device trees have not been verified by this project.

## Verified results

- The SDIO adapter was detected as `024c:f179`.
- The driver compiled against the running `6.12.114-ophub` kernel headers.
- The `8189fs.ko` module loaded with its `cfg80211` dependency.
- Wi-Fi scanning found nearby access points.
- The device connected to an access point through NetworkManager.
- Connectivity was tested through the Wi-Fi interface to the router, a public IP address, and a DNS hostname.
- The module was installed under `/lib/modules/6.12.114-ophub/updates/`, configured for module loading at boot, and verified working after reboot.

The driver exposed `wlan0` and `wlan1` in this test. They are virtual interfaces associated with the same SDIO radio, **not two separate physical Wi-Fi adapters**. Use `wlan0` as the primary interface unless you have a reason to configure the second interface.

## Important notes before installation

1. Make a backup of important data and keep a working Ethernet connection available.
2. Confirm that your board and Wi-Fi adapter match the tested hardware. Do not assume that every HG680P has the same Wi-Fi module.
3. Confirm the active device tree and kernel before changing anything:
   ```sh
   uname -r
   grep -E '^(FDT|FDTOVERLAYS)=' /boot/uEnv.txt
   ```
4. The tested setup used `meson-gxl-s905x-p212.dtb`. Do not change the DTB blindly on another board; an incorrect DTB can prevent the system from booting.
5. Matching kernel headers are required to build an external kernel module.
6. Build files and logs should be kept on a suitable writable data drive if eMMC space is limited. The tested setup used an external HDD for source and build output.
7. This project does not require replacing Armbian or modifying U-Boot.

## Manual build procedure (tested configuration)

The source used for the successful test was:

- Upstream source: [gustiarto/rtl8189fs-armbian](https://github.com/gustiarto/rtl8189fs-armbian)

Review the upstream project and its license before redistributing its source. This repository is intended to contain the project-specific build/install tooling and compatibility changes, with upstream source obtained separately.

### 1. Check the system and headers

Run these commands on the target device:

```sh
uname -m
uname -r
ls -ld /lib/modules/$(uname -r)/build
```

The tested output architecture was `aarch64` and the kernel was `6.12.114-ophub`.

### 2. Obtain the upstream source

Choose a writable build location with enough free space. For example:

```sh
git clone https://github.com/gustiarto/rtl8189fs-armbian.git
cd rtl8189fs-armbian
```

Do not run an upstream installation script without first reviewing what it changes.

### 3. Apply the kernel 6.12 callback compatibility adjustment

In the tested source revision, the kernel-version condition for `cfg80211_rtw_set_monitor_channel` in `os_dep/linux/ioctl_cfg80211.c` used a 6.13 threshold. The 6.12 headers on the tested system require the three-argument callback, so the condition was adjusted to 6.12.

The maintained patch is available at [`patches/kernel-6.12/0001-cfg80211-set-monitor-channel-signature.patch`](patches/kernel-6.12/0001-cfg80211-set-monitor-channel-signature.patch). It changes the version threshold from 6.13 to 6.12 for the three-argument callback used by the tested kernel. Apply it from the root of a clean upstream source checkout with `patch -p1 < /path/to/0001-cfg80211-set-monitor-channel-signature.patch`. Review the patch before applying it to a different upstream revision; the context may need adjustment.

### 4. Build

For the tested system, this build command completed successfully:

```sh
make -j2 ARCH=arm64 \
  KSRC=/lib/modules/$(uname -r)/build \
  CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT= \
  KCFLAGS=-Wno-error
```

The `CONFIG_CC_HAS_MIN_FUNCTION_ALIGNMENT=` override worked around a compiler-flag compatibility issue between the available host GCC and the kernel build configuration. `-Wno-error` allowed non-fatal warnings from the external driver source; it does not make build errors safe to ignore.

A message about skipping BTF generation because `vmlinux` is unavailable can be benign for this external module build. Confirm that the build actually produced `8189fs.ko` before proceeding.

### 5. Install and enable module loading

Only after verifying that the module was built for the currently running kernel:

```sh
sudo install -D -m 0644 8189fs.ko \
  /lib/modules/$(uname -r)/updates/8189fs.ko
sudo depmod -a
echo 8189fs | sudo tee /etc/modules-load.d/8189fs.conf
```

Load the module:

```sh
sudo modprobe 8189fs
```

Using `modprobe` allows the declared `cfg80211` dependency to be loaded automatically.

### 6. Verify

```sh
modinfo 8189fs
lsmod | grep -E '8189fs|cfg80211'
ip link
nmcli device status
```

Check that the module's `vermagic` matches `uname -r`, and that the Wi-Fi interface appears. Scan and connect using your network manager. For NetworkManager, an interactive connection can be made with:

```sh
nmcli --ask device wifi connect "YOUR_SSID" ifname wlan0
```

After reboot, repeat the module and interface checks to confirm persistence.

## Troubleshooting

### SDIO adapter is not detected

Check the SDIO device list and confirm the expected ID:

```sh
ls /sys/bus/sdio/devices/
```

The tested adapter reported vendor `0x024c` and device `0xf179`. If it is absent, investigate the board revision, device tree, SDIO initialization, and hardware before attempting to build the driver.

### Module reports unknown symbols

Load/check the dependency and inspect kernel messages:

```sh
sudo modprobe cfg80211
sudo modprobe 8189fs
dmesg | tail -n 80
```

If symbols remain unresolved, verify that the module was built against the exact running kernel headers. Do not force-load a module built for another kernel.

### Module does not load after a kernel update

An external module is specific to the kernel ABI/build it was compiled against. After changing kernels, rebuild and reinstall the module against the new kernel's matching headers, then run `depmod -a`.

### Wi-Fi interface exists but cannot connect

Check the driver log, radio block state, interface state, and NetworkManager status:

```sh
rfkill list
ip link
nmcli device status
dmesg | grep -iE '8189|wlan|firmware|sdio' | tail -n 100
```

## Uninstall

The following removes this manually installed module and its boot-time load configuration. Run it only if you intend to remove this driver:

```sh
sudo rm -f /etc/modules-load.d/8189fs.conf
sudo modprobe -r 8189fs
sudo rm -f /lib/modules/$(uname -r)/updates/8189fs.ko
sudo depmod -a
```

If the module is in use, disconnect Wi-Fi and stop services using the interface before unloading it. Keep Ethernet or another recovery path available.

## Roadmap

- [x] Verify RTL8189FS SDIO detection on the documented HG680P setup.
- [x] Build the driver for kernel `6.12.114-ophub`.
- [x] Verify Wi-Fi scanning, connection, and network connectivity.
- [x] Verify module autoload and Wi-Fi persistence after reboot.
- [ ] Add a maintained kernel 6.12 compatibility patch.
- [ ] Add preflight checks and a repeatable build/install script.
- [ ] Add safe uninstall, diagnostics, and rollback support.
- [ ] Test additional kernel and board combinations before declaring broader compatibility.

## Disclaimer

This is an unofficial community project. It is provided without warranty. The user is responsible for confirming hardware compatibility, reviewing scripts, backing up data, and approving system-level changes. Realtek driver source and other third-party components remain subject to their respective upstream licenses.
