# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
	rm -fR $@.boot
	mkdir -p $@.boot

	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img

	if [ ! -f "$(KDIR)/image-$(DEVICE_DTS).dtb" ]; then \
		echo "ERROR: DTB not found — expected: $(KDIR)/image-$(DEVICE_DTS).dtb" >&2; \
		exit 1; \
	fi
	$(CP) $(KDIR)/image-$(DEVICE_DTS).dtb $@.boot/$(DEVICE_DTS).dtb
endef

define Build/boot-script
	mkimage -A arm64 -O linux -T script -C none -a 0 -e 0 -d $(if $(1),$(1),default).bootscript $@.boot/boot.scr
endef

# --- 瑞芯微开发工具兼容的完整镜像 ---
define Build/pine64-img
	# 1. 制作boot分区（纯FAT32，32MiB）
	rm -f $(KDIR)/boot.img
	dd if=/dev/zero of=$(KDIR)/boot.img bs=1M count=32 status=none
	mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/boot.img
	mkdir -p $(KDIR)/bootfiles
	$(CP) $@.boot/* $(KDIR)/bootfiles/
	mcopy -i $(KDIR)/boot.img $(KDIR)/bootfiles/* ::/

	# 2. rootfs直接用纯squashfs，不带RKAF头
	rm -f $(KDIR)/root.img
	cp $(KDIR)/root.squashfs $(KDIR)/root.img

	# 3. 创建带MBR分区表的完整镜像
	rm -f $@
	# 总大小设为256MiB，足够容纳所有内容
	dd if=/dev/zero of=$@ bs=1M count=256 status=none
	parted -s $@ mklabel msdos
	# boot分区：32MiB，偏移0x00080000
	parted -s $@ mkpart primary fat32 4096s 65536s
	parted -s $@ set 1 boot on
	# rootfs分区：从32MiB开始
	parted -s $@ mkpart primary ext4 65536s 100%

	# 写入boot.img到分区1
	dd if=$(KDIR)/boot.img of=$@ bs=512 seek=4096 conv=notrunc status=none
	# 写入root.img到分区2
	dd if=$(KDIR)/root.img of=$@ bs=512 seek=65536 conv=notrunc status=none

	rm -rf $(KDIR)/bootfiles
endef

### Devices ###
define Device/Default
	PROFILES := Default
	KERNEL = kernel-bin | gzip
	KERNEL_LOADADDR := 0x00280000
	BOOT_SCRIPT := default
	DEVICE_DTS_DIR := $$(DTS_DIR)/rockchip
	DEVICE_DTS := $$(SOC)-$(lastword $(subst _, ,$(1)))
	UBOOT_DEVICE_NAME := $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
