# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk

BOARD:=rockchip
BOARDNAME:=Rockchip
FEATURES:=ext4 audio usb usbgadget display gpio fpu pci pcie rootfs-part boot-part squashfs
SUBTARGETS:=armv8

# 👇【关键修复】强制 target/linux/install 等待 tools/squashfs4/install 完成
HOST_BUILD_DEPENDS += squashfs4/host

KERNEL_PATCHVER:=6.12

define Target/Description
	Build firmware image for Rockchip SoC devices.
endef

include $(INCLUDE_DIR)/target.mk

DEFAULT_PACKAGES += uboot-envtools partx-utils e2fsprogs mkf2fs kmod-input-gpio-keys input-event-daemon

KERNELNAME:=Image dtbs

# ==============================================================================
# 内核准备钩子：在内核解压、文件同步完成后，向DTS编译规则追加H29K设备树
# ==============================================================================
define Kernel/Prepare/extra
	if ! grep -q "rk3528-hinlink-h29k" $(LINUX_DIR)/arch/arm64/boot/dts/rockchip/Makefile; then \
		echo 'dtb-$$(CONFIG_ARCH_ROCKCHIP) += rk3528-hinlink-h29k.dtb' >> $(LINUX_DIR)/arch/arm64/boot/dts/rockchip/Makefile; \
	fi
endef

$(eval $(call BuildTarget))
