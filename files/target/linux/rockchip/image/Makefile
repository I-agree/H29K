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

# --- ✅ 厂家同款格式：单个 img 包，FAT32 版本 ---
define Build/pine64-img
	# ==============================
	# RKAF 12字节 标准头（官方）
	# 00-03: RKAF
	# 04-07: 扇区数(LE, 512字节/扇区)
	# 08-11: 00 00 00 00
	# ==============================

	# ==============================================
	# Step 1: 制作 0.img（纯FAT32 CHS，严格32MiB，不带RKAF）
	# ==============================================
	rm -f $(KDIR)/0.img $(KDIR)/0.img.raw
	dd if=/dev/zero of=$(KDIR)/0.img.raw bs=4K count=8192 status=none
	mkfs.vfat -F32 -s 64 -h 63 -n BOOT --invariant $(KDIR)/0.img.raw
	mkdir -p $(KDIR)/bootfiles
	$(CP) $@.boot/* $(KDIR)/bootfiles/
	mcopy -i $(KDIR)/0.img.raw $(KDIR)/bootfiles/* ::/
	cp $(KDIR)/0.img.raw $(KDIR)/0.img

	# ==============================================
	# Step 2: 制作 1.img (RKAF头 + squashfs，官方格式)
	# ==============================================
	rm -f $(KDIR)/1.img
	SIZE=$$(wc -c < $(KDIR)/root.squashfs); \
	SECTORS=$$(( (SIZE + 511) / 512 )); \
	B0=$$(( SECTORS & 0xff )); \
	B1=$$(( (SECTORS >> 8) & 0xff )); \
	B2=$$(( (SECTORS >> 16) & 0xff )); \
	B3=$$(( (SECTORS >> 24) & 0xff )); \
	\
	dd if=/dev/zero of=$(KDIR)/1.img bs=1 count=12 status=none; \
	printf "\x52\x4B\x41\x46" | dd of=$(KDIR)/1.img bs=1 seek=0 conv=notrunc status=none; \
	printf "\\x$$(printf "%02x" $$B0)\\x$$(printf "%02x" $$B1)\\x$$(printf "%02x" $$B2)\\x$$(printf "%02x" $$B3)" | dd of=$(KDIR)/1.img bs=1 seek=4 conv=notrunc status=none; \
	dd if=$(KDIR)/root.squashfs of=$(KDIR)/1.img bs=4K seek=1 conv=sync status=none

	# ==============================================
	# Step3: 制作整机镜像（官方分区布局）
	# ==============================================
	rm -f $@
	dd if=/dev/zero of=$@ bs=1M count=128 status=none
	parted -s $@ mklabel msdos

	# 分区1: boot (32M ~ 64M)
	parted -s $@ mkpart primary fat32 33554432B 67108864B
	parted -s $@ set 1 boot on
	dd if=$(KDIR)/0.img of=$@ bs=4K seek=8192 conv=notrunc status=none

	# 分区2: rootfs (96M起)
	parted -s $@ mkpart primary 100663296B 100%
	dd if=$(KDIR)/1.img of=$@ bs=4K seek=24576 conv=notrunc status=none

	# 清理
	rm -rf $(KDIR)/bootfiles $(KDIR)/*.raw
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
