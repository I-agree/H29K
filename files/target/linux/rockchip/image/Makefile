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

# --- ✅ 厂家同款格式：单个 img 包 ---
define Build/pine64-img
	# ==============================
	# RKAF 12字节 标准头（官方）
	# 00-03: RKAF
	# 04-07: 扇区数(LE, 512字节/扇区)
	# 08-11: 00 00 00 00
	# ==============================

	# ==============================================
	# Step 1: 制作 干净 0.img (32MB BOOT)
	# ==============================================
	rm -f $(KDIR)/0.img $(KDIR)/0.img.raw
	# 1.1 生成干净 32MB 空白镜像（无脏数据）
	dd if=/dev/zero of=$(KDIR)/0.img.raw bs=4K count=8192 status=none
	mkfs.vfat -F32 -s 64 -h 63 -n BOOT --invariant $(KDIR)/0.img.raw
	# 写入 boot 文件
	mkdir -p $(KDIR)/bootfiles
	$(CP) $@.boot/* $(KDIR)/bootfiles/
	mcopy -i $(KDIR)/0.img.raw $(KDIR)/bootfiles/* ::/

	# 1.2 生成 干净 12字节 RKAF 头（无脏数据）
	dd if=/dev/zero of=$(KDIR)/rkaf.hdr bs=1 count=12 status=none
	printf "\x52\x4B\x41\x46" | dd of=$(KDIR)/rkaf.hdr bs=1 seek=0 conv=notrunc status=none
	printf "\x00\x00\x01\x00" | dd of=$(KDIR)/rkaf.hdr bs=1 seek=4 conv=notrunc status=none # 32MB = 65536 扇区

	# 1.3 32MB、RKAF完整（✅ 修复 TOTAL_SIZE 计算）
	# 获取文件大小（加容错）
	RKAF_SIZE := $(shell stat -c "%s" $(KDIR)/rkaf.hdr 2>/dev/null || echo "0")
	IMG_RAW_SIZE := $(shell stat -c "%s" $(KDIR)/0.img.raw 2>/dev/null || echo "0")
	if [ "$$RKAF_SIZE" = "0" ] || [ "$$IMG_RAW_SIZE" = "0" ]; then \
        echo "ERROR: Failed to get size of rkaf.hdr or 0.img.raw" >&2; \
        exit 1; \
	fi
	TOTAL_SIZE := $(shell echo $$(($$RKAF_SIZE + $$IMG_RAW_SIZE)))
	cat $(KDIR)/rkaf.hdr $(KDIR)/0.img.raw | dd of=$(KDIR)/0.img bs=1 count=$$TOTAL_SIZE conv=notrunc status=none

	# ==============================================
	# Step 2: 制作 干净 1.img (RKAF + squashfs，seek=1 修正)
	# ==============================================
	rm -f $(KDIR)/1.img
	# 计算大小
	SIZE=$$(wc -c < $(KDIR)/root.squashfs); \
	SECTORS=$$(( (SIZE + 511) / 512 )); \
	B0=$$(( SECTORS & 0xff )); \
	B1=$$(( (SECTORS >> 8) & 0xff )); \
	B2=$$(( (SECTORS >> 16) & 0xff )); \
	B3=$$(( (SECTORS >> 24) & 0xff )); \
	\
	# 生成 干净 12字节 零初始头
	dd if=/dev/zero of=$(KDIR)/1.img bs=1 count=12 status=none; \
	printf "\x52\x4B\x41\x46" | dd of=$(KDIR)/1.img bs=1 seek=0 conv=notrunc status=none; \
	printf "\\x$$(printf "%02x" $$B0)\\x$$(printf "%02x" $$B1)\\x$$(printf "%02x" $$B2)\\x$$(printf "%02x" $$B3)" | dd of=$(KDIR)/1.img bs=1 seek=4 conv=notrunc status=none; \
	\
	# 【核心修正】4K 对齐追加 rootfs，seek=1
	dd if=$(KDIR)/root.squashfs of=$(KDIR)/1.img bs=4K conv=sync seek=1 status=none

	# ==============================================
	# Step3: 写入整机镜像（原厂偏移 100% 匹配）
	# ==============================================
	rm -f $@
	dd if=/dev/zero of=$@ bs=1M count=128 status=none
	parted -s $@ mklabel msdos
	# ✅ 0.img @ 32MiB → 33554432 bytes = LBA 65536 → seek=8192 (4K)
	parted -s $@ mkpart primary 33554432B 67108864B
	parted -s $@ set 1 boot on 
	dd if=$(KDIR)/0.img of=$@ bs=4K seek=8192 conv=notrunc status=none
	# ✅ 1.img @ 96MiB → 100663296 bytes = LBA 196608 → seek=24576 (4K)
	parted -s $@ mkpart primary 100663296B 100%
	dd if=$(KDIR)/1.img of=$@ bs=4K seek=24576 conv=notrunc status=none

	# 清理临时文件
	rm -rf $(KDIR)/*.raw $(KDIR)/*.hdr $(KDIR)/bootfiles
endef

### Devices ###
define Device/Default
	PROFILES := Default
	# ✅【终极修复】去掉 fit，无冲突，原生 kernel.img 匹配 boot.scr
	KERNEL = kernel-bin | gzip
	KERNEL_LOADADDR := 0x00280000
	BOOT_SCRIPT := default
	DEVICE_DTS_DIR := $$(DTS_DIR)/rockchip
	DEVICE_DTS := $$(SOC)-$(lastword $(subst _, ,$(1)))
	UBOOT_DEVICE_NAME := $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk

$(eval $(call BuildImage))
