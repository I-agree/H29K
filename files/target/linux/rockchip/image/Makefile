# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

# ==============================================================================
# 🛠️ 核心修复：重写 DTB 编译基础设施，彻底打通 C 预处理器（CPP）的内核头文件通道
# ==============================================================================
define Image/BuildDTB
	$(TARGET_CROSS)cpp -nostdinc -x assembler-with-cpp \
		-I$(DTS_DIR) \
		-I$(DEVICE_DTS_DIR) \
		-I$(DTS_DIR)/include \
		-I$(LINUX_DIR)/include \
		-I$(LINUX_DIR)/arch/arm64/boot/dts/include \
		-undef -D__DTS__ $(1) $(2).tmp
	$(LINUX_DIR)/scripts/dtc/dtc -O dtb -i$(DTS_DIR) -i$(DEVICE_DTS_DIR) \
		$(if $(CONFIG_OF_OVERLAY),-@) \
		-Wno-interrupt_provider \
		-Wno-unique_unit_address \
		-Wno-unit_address_vs_reg \
		-Wno-avoid_unnecessary_addr_size \
		-Wno-alias_paths \
		-Wno-graph_child_address \
		-Wno-simple_bus_reg \
		-o $(2) $(2).tmp
endef
# ==============================================================================

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
	# This creates a new folder copies the dtb (as rockchip.dtb) 
	# and the kernel image (as kernel.img)
	rm -fR $@.boot
	mkdir -p $@.boot

	$(CP) $(KDIR)/image-$(firstword $(notdir $(DEVICE_DTS))).dtb $@.boot/rockchip.dtb
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
endef

define Build/boot-script
	# Make an U-boot image and copy it to the boot partition
	mkimage -A arm -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),mmc).bootscript $@.boot/boot.scr
endef

define Build/pine64-img
	# Creates the final SD/eMMC images, 
	# combining boot partition, root partition as well as the u-boot bootloader

	# Generate a new partition table in $@ with 32 MiB of 
	# alignment padding for the idbloader and u-boot to fit:
	# http://opensource.rock-chips.com/wiki_Boot_option#Boot_flow
	#
	# U-Boot SPL expects the U-Boot ITB to be located at sector 0x4000 (8 MiB) on the MMC storage
	PADDING=1 $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		32768

	# 🛠️ 智能识别 Binman 合体固件或传统拆分固件
	if [ -f "$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin ]; then \
		echo "Found Binman combined image, flashing..."; \
		dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin of="$@" seek=64 conv=notrunc; \
	else \
		echo "Binman image not found, falling back to split legacy images..."; \
		dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-idbloader.img of="$@" seek=64 conv=notrunc; \
		dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot.itb of="$@" seek=16384 conv=notrunc; \
	fi
endef

define Build/pine64-bin
	# Typical Rockchip boot flow with Rockchip miniloader
	# Rockchp idbLoader which is combinded by Rockchip ddr init bin
	# and miniloader bin from Rockchip rkbin project

	# Generate a new partition table in $@ with 32 MiB of alignment
	# padding for the idbloader, uboot and trust image to fit:
	# http://opensource.rock-chips.com/wiki_Boot_option#Boot_flow
	PADDING=1 $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		32768

	# Copy the idbloader, uboot and trust image to the image at sector 0x40, 0x4000 and 0x6000
	dd if="$(STAGING_DIR_IMAGE)"/$(SOC)-idbloader.bin of="$@" seek=64 conv=notrunc
	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-uboot.img of="$@" seek=16384 conv=notrunc
	dd if="$(STAGING_DIR_IMAGE)"/$(SOC)-trust.bin of="$@" seek=24576 conv=notrunc
endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL := kernel-bin
  IMAGES := sysupgrade.img.gz
  GUID := 54444e4b-5341-4c41-4d41-4e44414e4749
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
