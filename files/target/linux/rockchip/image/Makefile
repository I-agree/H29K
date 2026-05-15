# SPDX-License-Identifier: GPL-2.0-only
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

define Build/boot-common
	rm -fR $@.boot
	mkdir -p $@.boot
	# 生成boot分区内容：kernel镜像
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img
endef

define Build/boot-script
	# 启动脚本格式严格匹配瑞芯微原厂
	mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d default.bootscript $@.boot/boot.scr
endef

# 全盘打包，严格生成0.img(boot) +1.img(system)，分区大小匹配你定义的
define Build/pine64-img
	PADDING=1 $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(KERNEL_SIZE) $@.boot \
		$(ROOTFS_SIZE) $(IMAGE_ROOTFS) \
		32768
endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL = kernel-bin | lzma | fit lzma $$(KDIR)/image-$$(firstword $$(DEVICE_DTS)).dtb
  KERNEL_LOADADDR := 0x00280000
  BOOT_SCRIPT := default
  IMAGES := sysupgrade.img.gz
  # 原厂格式流水线，输出单个img内含0.img+1.img
  IMAGE/sysupgrade.img.gz = boot-common | boot-script | pine64-img | gzip
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
  UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
  # 25.12原生生效分区大小
  FILESYSTEM_SIZE := $$(ROOTFS_SIZE)
  KERNEL_IMAGE_SIZE := $$(KERNEL_SIZE)
endef

include $(SUBTARGET).mk
$(eval $(call BuildImage))
