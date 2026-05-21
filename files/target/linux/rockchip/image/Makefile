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

# --- 瑞芯微开发工具兼容的单分区镜像格式 ---
define Build/pine64-img
	# ==============================================
	# Step 1: 制作 0.img（纯FAT32，32MiB，无任何额外头）
	# ==============================================
	rm -f $(KDIR)/0.img
	dd if=/dev/zero of=$(KDIR)/0.img bs=4K count=8192 status=none
	mkfs.vfat -F32 -s 64 -h 63 -n BOOT -M 0xf8 --invariant $(KDIR)/0.img
	mkdir -p $(KDIR)/bootfiles
	$(CP) $@.boot/* $(KDIR)/bootfiles/
	mcopy -i $(KDIR)/0.img $(KDIR)/bootfiles/* ::/

	# ==============================================
	# Step 2: 制作 1.img（去掉RKAF头，纯squashfs，用于system分区）
	# ==============================================
	rm -f $(KDIR)/1.img
	# 直接复制root.squashfs，不添加RKAF头
	cp $(KDIR)/root.squashfs $(KDIR)/1.img

	# ==============================================
	# Step3: 拼接成开发工具兼容的完整镜像
	# 0.img(32MiB) + 填充到96MiB + 1.img
	# ==============================================
	rm -f $@
	# 先写0.img（32MiB）
	cat $(KDIR)/0.img > $@
	# 填充到96MiB（32MiB + 64MiB），对齐rootfs分区起始位置
	dd if=/dev/zero of=$@ bs=4K count=16384 seek=8192 status=none
	# 写入1.img（从96MiB位置开始）
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
