# Allwinner A733 (sun60iw2) octa-core 4-16GB, WiFi6/BT (USB), NPU, GPU, eMMC
BOARD_NAME="Radxa Cubie A7S"
BOARD_VENDOR="radxa"
BOARDFAMILY="sun60iw2"
BOARD_MAINTAINER=""
INTRODUCED="2026"
KERNEL_TARGET="vendor"
KERNEL_TEST_TARGET="vendor"
IMAGE_PARTITION_TABLE="gpt"
# Separate 256M vfat boot partition (boot.scr/Image/dtb) + ext4 rootfs.
# GPT is used so the partition table is consistent with the Radxa stock
# layout; the gpt-shrink-entries extension keeps the GPT entry array below
# 8 KiB so the BROM-required boot0 slot at 8K survives.
BOOTFS_TYPE="fat"
BOOTSIZE=256
HAS_VIDEO_OUTPUT="no" # no desktop on this vendor kernel; board-level so the build-list inventory sees it

# --- Board-specific build configuration ---
BOOT_FDT_FILE="allwinner/sun60i-a733-cubie-a7s.dtb"

# WiFi/BT = AIC8800D80 over USB (same module as Cubie A7Z/A7A)
# Override MODULES with the bus-suffixed USB modules (aic8800-usb-dkms) so only those load.
MODULES="aic_load_fw_usb aic8800_fdrv_usb aic_btusb_usb"
PACKAGE_LIST_BOARD="rfkill bluetooth bluez bluez-tools"
AIC8800_TYPE="usb"
enable_extension "radxa-aic8800"
enable_extension "gpt-shrink-entries"
# GPU (PowerVR BXM-4-64): the kernel driver is IMG img-bxm-dkms (~470k lines,
# GPL but out-of-mainline scale); installed post-image via B1 install-gpu.sh
# (see B-安装后配置/gpu) instead of being baked into the image.

# In-tree boot blobs consumed by the family's uboot_custom_postprocess.
# Extracted from Radxa's official A7S OS image boot sector (A7A LPDDR5
# variant - the A7S uses the same LPDDR5 DRAM, and Radxa ships the A7S with
# the A7A boot0/boot_package).
SUNXI_BOOT0_SDCARD_FEX="${SRC}/packages/blobs/sunxi/sun60iw2/boot0_cubie-a7s.fex"
SUNXI_BOOT0_SPINOR_FEX="${SRC}/packages/blobs/sunxi/sun60iw2/boot0_cubie-a7s.fex"
SUNXI_SYS_CONFIG_FEX="${SRC}/packages/blobs/sunxi/sun60iw2/sys_config_cubie-a7s.fex"

# Invalidate U-Boot cache if any of the blobs change
UBOOT_HASH_EXTRA="$(cat "${SUNXI_BOOT0_SDCARD_FEX}" "${SUNXI_SYS_CONFIG_FEX}" | sha256sum | cut -d' ' -f1)"

# U-Boot: use the sun60iw2 family defaults (Orange Pi vendor U-Boot,
# boot0@8K + boot_package@16400K family layout), same flow as the Cubie A7Z.
# No board-level overrides needed.
