# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

BOARD:=rockchip
BOARDNAME:=Rockchip
FEATURES:=ext4 audio usb usbgadget display gpio fpu pci pcie rootfs-part boot-part squashfs
SUBTARGETS:=armv8

# 👇【关键修复】强制 target/linux/install 等待 tools/squashfs4/install 完成
HOST_BUILD_DEPENDS += squashfs4/host

KERNEL_PATCHVER:=6.18

define Target/Description
	Build firmware image for Rockchip SoC devices.
endef

include $(INCLUDE_DIR)/target.mk

DEFAULT_PACKAGES += uboot-envtools partx-utils e2fsprogs mkf2fs kmod-input-gpio-keys input-event-daemon

KERNELNAME:=Image dtbs

$(eval $(call BuildTarget))
