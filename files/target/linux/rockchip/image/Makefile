# SPDX-License-Identifier: GPL-2.0-only

include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux
endef

### Image scripts ###
define Build/boot-common
	# Create boot directory with kernel and dtb
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

# ============================
# 最终修复版：无 parted 报错
# 完全匹配 RK3528 H29K
# 完全匹配你的刷机工具
# 完全匹配你的 boot.scr
# ============================
define Build/pine64-img
	# 1. 创建 BOOT 分区（32MB FAT32）
	rm -f $(KDIR)/boot.img
	dd if=/dev/zero of=$(KDIR)/boot.img bs=1M count=32 status=none
	mkfs.vfat -F32 -n BOOT --invariant $(KDIR)/boot.img
	mcopy -i $(KDIR)/boot.img $@.boot/* ::/

	# 2. rootfs 使用纯 squashfs，不带 RKAF
	rm -f $(KDIR)/root.img
	cp $(KDIR)/root.squashfs $(KDIR)/root.img

	# 3. 创建完整镜像（256MB）
	rm -f $@
	dd if=/dev/zero of=$@ bs=1M count=256 status=none
	parted -s $@ mklabel msdos

	# --------------------------
	# 修复 parted 对齐错误
	# 分区1：boot 32MB
	# 分区2：rootfs 从 32MB 开始
	# --------------------------
	parted -s $@ mkpart primary fat32 1MiB 33MiB
	parted -s $@ mkpart primary 33MiB 100%
	parted -s $@ set 1 boot on

	# 写入 boot
	dd if=$(KDIR)/boot.img of=$@ bs=1M seek=1 conv=notrunc status=none

	# 写入 rootfs
	dd if=$(KDIR)/root.img of=$@ bs=1M seek=33 conv=notrunc status=none

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
