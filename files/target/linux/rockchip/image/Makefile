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
endef

define Build/boot-script
	# Make an U-boot image and copy it to the boot partition
	mkimage -A arm -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# 彻底注释pine64-img全盘镜像流水线，25.12不用
#define Build/pine64-img
#	PADDING=1 $(SCRIPT_DIR)/gen_image_generic.sh \
#		$@ \
#		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
#		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
#		32768
#	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin of="$@" seek=64 conv=notrunc
#endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_LOADADDR :=
  BOOT_SCRIPT :=
  IMAGES := sysupgrade.img.gz
  # OpenWrt25.12原生分区流水线，无fit冲突、无u-boot依赖
  IMAGE/sysupgrade.img.gz = boot-common | boot-script | append-rootfs | pad-rootfs | check-size | gzip
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
  UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
  # 绑定设备字节大小，让check-size正确识别
  FILESYSTEM_SIZE := $$(ROOTFS_SIZE)
  KERNEL_IMAGE_SIZE := $$(KERNEL_SIZE)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
