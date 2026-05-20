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

# --- ✅ 厂家同款格式：单个 img 包，0.img/1.img 直接拼接，不带 parted 分区表干扰 ---
define Build/pine64-img
	# ==============================================
	# Step 1: 制作 0.img（纯FAT32，严格32MiB，无任何额外头）
	# ==============================================
	rm -f $(KDIR)/0.img
	# 直接创建 32MiB 零填充文件（4K*8192=32MiB，天然4K对齐）
	dd if=/dev/zero of=$(KDIR)/0.img bs=4K count=8192 status=none
	# 格式化FAT32，参数和官方保持一致
	mkfs.vfat -F32 -s 64 -h 63 -n BOOT --invariant $(KDIR)/0.img
	# 拷贝文件到FAT分区
	mkdir -p $(KDIR)/bootfiles
	$(CP) $@.boot/* $(KDIR)/bootfiles/
	mcopy -i $(KDIR)/0.img $(KDIR)/bootfiles/* ::/

	# ==============================================
	# Step 2: 制作 1.img (保留原逻辑，不修改)
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
	# Step3: 直接拼接 0.img + 1.img，不使用 parted
	# ==============================================
	rm -f $@
	# 先写 0.img（32MiB）
	cat $(KDIR)/0.img > $@
	# 再写 1.img（从 32MiB 位置开始，4K 对齐）
	cat $(KDIR)/1.img >> $@

	# 清理临时文件
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
