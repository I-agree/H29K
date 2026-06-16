# SPDX-License-Identifier: GPL-2.0-only
include $(TOPDIR)/rules.mk
include $(INCLUDE_DIR)/image.mk

DEVICE_VARS += UBOOT_DEVICE_NAME

define Build/Compile
	$(CP) $(LINUX_DIR)/COPYING $(KDIR)/COPYING.linux >/dev/null
endef

### Image scripts ###
define Build/boot-common
	# This creates a new folder, copies the dtb into rockchip/ sub-folder with its original name,
	# and copies the kernel image (as kernel.img)
	rm -fR $@.boot >/dev/null
	mkdir -p $@.boot >/dev/null

	# 🎯 核心修改 1：在 FAT32 引导分区的临时根目录下创建 rockchip 子目录
	mkdir -p $@.boot/rockchip >/dev/null

	# 🎯 核心修改 2：拒绝改名！直接以原名复制到 rockchip/ 目录下
	# $(firstword $(notdir $(DEVICE_DTS))) 会被精准展开为 rk3528-hinlink-h29k
	$(CP) $(KDIR)/image-$(firstword $(notdir $(DEVICE_DTS))).dtb \
		$@.boot/rockchip/$(firstword $(notdir $(DEVICE_DTS))).dtb >/dev/null

	# 保持原样：复制内核镜像
	$(CP) $(IMAGE_KERNEL) $@.boot/kernel.img >/dev/null
endef

define Build/boot-script
	# Make an U-boot image and copy it to the boot partition
	mkimage -A arm -O linux \
		-T script -C none -a 0 -e 0 -d $(if $(1),$(1),mmc).bootscript $@.boot/boot.scr >/dev/null
endef

define Build/pine64-img
	# Creates the final SD/eMMC images, 
	# combining boot partition, root partition as well as the u-boot bootloader
	GUID="54444e4b-5341-4c41-4d41-4e44414e4749" PADDING=1 PARTOFFSET=32m $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		>/dev/null

	@echo "=========================================================="
	@echo " 🔍 [H29K 引导打包层调试] 正在验证并智能检索 U-Boot 引导组件..."
	@echo " 🚀 目标前缀变量 UBOOT_DEVICE_NAME = $(UBOOT_DEVICE_NAME)"
	@echo "=========================================================="

	u_boot_bin=""; \
	if [ -n "$(UBOOT_DEVICE_NAME)" ] && [ -f "$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin ]; then \
		u_boot_bin="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot-rockchip.bin; \
	elif [ -f "$(STAGING_DIR_IMAGE)"/hinlink-h29k-rk3528-u-boot-rockchip.bin ]; then \
		u_boot_bin="$(STAGING_DIR_IMAGE)"/hinlink-h29k-rk3528-u-boot-rockchip.bin; \
	elif [ -f "$(STAGING_DIR_IMAGE)"/h29k-rk3528-u-boot-rockchip.bin ]; then \
		u_boot_bin="$(STAGING_DIR_IMAGE)"/h29k-rk3528-u-boot-rockchip.bin; \
	fi; \
	if [ -n "$$u_boot_bin" ]; then \
		echo "🎯 [检测成功] 发现 Binman 一体化合体固件: $$u_boot_bin"; \
		echo "👉 正在向 32KB 头部 (seek=64) 砸入完整引导链..."; \
		dd if="$$u_boot_bin" of="$@" seek=64 conv=notrunc; \
	else \
		echo "⚠️ [提示] 未发现常规命名 Binman 固件，正在尝试传统拆分组件与多重名模糊匹配..."; \
		idb_img=""; uboot_itb=""; \
		if [ -n "$(UBOOT_DEVICE_NAME)" ] && [ -f "$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-idbloader.img ]; then \
			idb_img="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-idbloader.img; \
			uboot_itb="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-u-boot.itb; \
		elif [ -f "$(STAGING_DIR_IMAGE)"/hinlink-h29k-rk3528-idbloader.img ]; then \
			idb_img="$(STAGING_DIR_IMAGE)"/hinlink-h29k-rk3528-idbloader.img; \
			uboot_itb="$(STAGING_DIR_IMAGE)"/hinlink-h29k-rk3528-u-boot.itb; \
		fi; \
		if [ -n "$$idb_img" ]; then \
			echo "🎯 [检测成功] 发现有效拆分引导组件，执行分段注入..."; \
			echo "👉 1/2: 正在强行注入第一级引导 (IDBLoader) 到 seek=64 (32KB)..."; \
			dd if="$$idb_img" of="$@" seek=64 conv=notrunc; \
			if [ -f "$$uboot_itb" ]; then \
				echo "👉 2/2: 正在强行注入第二级引导 (U-Boot ITB) 到 seek=16384 (8MB)..."; \
				dd if="$$uboot_itb" of="$@" seek=16384 conv=notrunc; \
			fi; \
		else \
			echo "❌ [严重错误] 警告：在临时存储区找不到任何适用于 H29K 的引导固件！固件将无法开机！"; \
		fi; \
	fi

	@echo "=========================================================="
	@echo " ✅ [H29K 引导打包层调试] 引导程序处理流程结束！"
	@echo "=========================================================="
endef

define Build/pine64-bin
	# Typical Rockchip boot flow with Rockchip miniloader
	# Rockchp idbLoader which is combinded by Rockchip ddr init bin
	# and miniloader bin from Rockchip rkbin project
	# Generate a new partition table in $@ with 32 MiB of alignment
	# padding for the idbloader, uboot and trust image to fit:
	# http://opensource.rock-chips.com/wiki_Boot_option#Boot_flow
	GUID="54444e4b-5341-4c41-4d41-4e44414e4749" PADDING=1 PARTOFFSET=32m $(SCRIPT_DIR)/gen_image_generic.sh \
		$@ \
		$(CONFIG_TARGET_KERNEL_PARTSIZE) $@.boot \
		$(CONFIG_TARGET_ROOTFS_PARTSIZE) $(IMAGE_ROOTFS) \
		>/dev/null
	# Copy the idbloader, uboot and trust image to the image at sector 0x40, 0x4000 and 0x6000
	dd if="$(STAGING_DIR_IMAGE)"/$(SOC)-idbloader.bin of="$@" seek=64 conv=notrunc status=none
	dd if="$(STAGING_DIR_IMAGE)"/$(UBOOT_DEVICE_NAME)-uboot.img of="$@" seek=16384 conv=notrunc status=none
	dd if="$(STAGING_DIR_IMAGE)"/$(SOC)-trust.bin of="$@" seek=24576 conv=notrunc status=none
endef

### Devices ###
define Device/Default
  PROFILES := Default
  KERNEL := kernel-bin
  IMAGES := factory.img.gz
  DEVICE_DTS_DIR = $$(DTS_DIR)/rockchip
  DEVICE_DTS = $$(SOC)-$(lastword $(subst _, ,$(1)))
  # 🎯 核心修复：恢复原版被遗漏的设备名称基础计算公式，保障体系变量连贯性
  UBOOT_DEVICE_NAME = $(lastword $(subst _, ,$(1)))-$$(SOC)
endef

include $(SUBTARGET).mk
$(eval $(call BuildImage))