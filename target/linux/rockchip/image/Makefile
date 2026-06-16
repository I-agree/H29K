# SPDX-License-Identifier: GPL-2.0-only
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux >/dev/null
endef

### Image scripts ###
define Build/boot-common
	# This creates a new folder copies the dtb (as rockchip.dtb) 
	# and the kernel image (as kernel.img)
	rm -fR $@.boot >/dev/null
	mkdir -p $@.boot >/dev/null
	$(CP) $(KDIR)/image-$(firstword $(notdir $(DEVICE_DTS))).dtb $@.boot/rockchip.dtb >/dev/null
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img >/dev/null
endef

define Build/boot-script
	# Make an U-boot image and copy it to the boot partition
	mkimage -A arm -O linux \
		-T script -C none -a 0 -e 0 -d $(if $(1),$(1),mmc).bootscript $@.boot/boot.scr >/dev/null
endef

define Build/pine64-img
	# Creates the final SD/eMMC images, 
	# combining boot partition, root partition as well as the u-boot bootloader
	GUID="54444e4b-5341-4c41-4d41-4e44414e4749" PADDING=1 PARTOFFSET=32m $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		>/dev/null

	@echo "=========================================================="
	@echo " 🔍 [H29K 引导打包层调试] 正在验证并注入 U-Boot 引导组件..."
	@echo " 🚀 目标前缀变量 UBOOT_DEVICE_NAME = $(UBOOT_DEVICE_NAME)"
	@echo "=========================================================="

	if [ -f "$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin ]; then \
		echo "🎯 [检测成功] 发现 Binman 一体化合体固件，正在注入到 32KB 头部..."; \
		dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin of="$@" seek=64 conv=notrunc; \
	else \
		echo "⚠️ [提示] 未发现 Binman 合体固件，正在尝试传统拆分式组件注入..."; \
		echo "👉 1/2: 正在强行注入第一级引导 (IDBLoader) 到 seek=64 (32KB)..."; \
		dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-idbloader.img of="$@" seek=64 conv=notrunc && \
		echo "👉 2/2: 正在强行注入第二级引导 (U-Boot ITB) 到 seek=16384 (8MB)..."; \
		dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot.itb of="$@" seek=16384 conv=notrunc; \
	fi

	@echo "=========================================================="
	@echo " ✅ [H29K 引导打包层调试] 引导程序成功砸入指定扇区！"
	@echo "=========================================================="
endef

define Build/pine64-bin
	# Typical Rockchip boot flow with Rockchip miniloader
	# Rockchp idbLoader which is combinded by Rockchip ddr init bin
	# and miniloader bin from Rockchip rkbin project
	# Generate a new partition table in $@ with 32 MiB of alignment
	# padding for the idbloader, uboot and trust image to fit:
	# http://opensource.rock-chips.com/wiki_Boot_option#Boot_flow
	GUID="54444e4b-5341-4c41-4d41-4e44414e4749" PADDING=1 PARTOFFSET=32m $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		>/dev/null
	# Copy the idbloader, uboot and trust image to the image at sector 0x40, 0x4000 and 0x6000
	dd if="$(STAGING_DIR_IMAGE)"/$(SOC)-idbloader.bin of="$@" seek=64 conv=notrunc status=none
	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-uboot.img of="$@" seek=16384 conv=notrunc status=none
	dd if="$(STAGING_DIR_IMAGE)"/$(SOC)-trust.bin of="$@" seek=24576 conv=notrunc status=none
endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL := kernel-bin
  IMAGES := factory.img.gz
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
endef

include $(SUBTARGET).mk
$(eval $(call BuildImage))
