# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
	# 1:1 复刻原厂boot分区文件结构
	rm -fR $@.boot
	mkdir -p $@.boot

	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/rockchip.dtb
endef

define Build/boot-script
	# 适配ARM64架构，生成原厂格式的boot.scr
	mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

define Build/pine64-img
	# Creates the final SD/eMMC images,
	# combining boot partition, root partition as well as the u-boot bootloader

	# Generate a new partition table in $@ with 32 MiB of
	# alignment padding for the u-boot-rockchip.bin (idbloader + u-boot) to fit:
	# http://opensource.rock-chips.com/wiki_Boot_option#Boot_flow
	#
	# U-Boot SPL expects the U-Boot ITB to be located at sector 0x4000 (8 MiB) on the MMC storage
	PADDING=1 $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		32768

	# Copy the u-boot-rockchip.bin to the image at sector 0x40
	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin of="$@" seek=64 conv=notrunc
endef

# ======================= 1:1 复刻原厂分区结构的h29k-img =======================
define Build/h29k-img
	# 1. 创建与原厂一致的EXT4 boot分区（关闭64bit特性，兼容老U-Boot）
	rm -f $(KDIR)/boot.img
	mkfs.ext4 -L kernel -d $@.boot -F -O ^64bit -O ^huge_file $(KDIR)/boot.img 32M

	# 2. 创建完整镜像，匹配原厂MBR分区表
	rm -f $@
	dd if=/dev/zero of=$@ bs=512 count=1237872 conv=sparse
	parted -s $@ mklabel msdos
	parted -s $@ mkpart primary ext4 1MiB 33MiB
	parted -s $@ mkpart primary ext4 33MiB 100%

	# 3. 写入分区数据
	dd if=$(KDIR)/boot.img of=$@ bs=1M seek=1 conv=notrunc
	dd if=$(IMAGE_ROOTFS) of=$@ bs=1M seek=33 conv=notrunc
endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_LOADADDR :=
  BOOT_SCRIPT :=
  IMAGES := sysupgrade.img.gz
  IMAGE/sysupgrade.img.gz = boot-common | boot-script $$(BOOT_SCRIPT) | pine64-img | gzip | append-metadata
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
  UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
