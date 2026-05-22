# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
	# This creates a new folder copies the dtb (as rockchip.dtb)
	# and the kernel image (as kernel.img)
	rm -fR $@.boot
	mkdir -p $@.boot

	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/$(DEVICE_DTS).dtb
endef

define Build/boot-script
	# Make an U-boot image and copy it to the boot partition
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

# ====================== 你自定义的函数 ======================
define Build/h29k-img
	# 1. 创建 boot 分区（ext4 格式，和原厂一致）
	rm -rf $(KDIR)/boot
	mkdir -p $(KDIR)/boot
	cp -r $@.boot/* $(KDIR)/boot/
	mkfs.ext4 -L "boot" -d $(KDIR)/boot $(KDIR)/boot.img 32M

	# 2. 创建根文件系统分区
	rm -rf $(KDIR)/root
	mkdir -p $(KDIR)/root
	mkfs.ext4 -L "root" -d $(KDIR)/root $(KDIR)/root.img 96M
	dd if=$(IMAGE_ROOTFS) of=$(KDIR)/root.img conv=notrunc

	# 3. 构建完整镜像
	rm -f $@
	dd if=/dev/zero of=$@ bs=1M count=128
	parted -s $@ mklabel msdos
	parted -s $@ mkpart primary ext4 1MiB 33MiB
	parted -s $@ mkpart primary ext4 33MiB 100%

	# 4. 写入分区内容
	dd if=$(KDIR)/boot.img of=$@ bs=1M seek=1 conv=notrunc
	dd if=$(KDIR)/root.img of=$@ bs=1M seek=33 conv=notrunc
endef
# ===========================================================

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
